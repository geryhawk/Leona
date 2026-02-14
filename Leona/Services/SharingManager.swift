import Foundation
import CloudKit
import SwiftData
import os.log

private let logger = Logger(subsystem: "com.leona.app", category: "Sharing")

/// Manages CloudKit sharing of baby profiles between different iCloud accounts.
/// Uses CKShare + UICloudSharingController alongside the existing SwiftData stack.
@Observable
final class SharingManager {
    static let shared = SharingManager()
    static let sharedSubscriptionID = "shared-baby-changes"

    @ObservationIgnored
    let container = CKContainer(identifier: "iCloud.com.leona.app")

    var sharingStatus: SharingStatus = .none
    var sharedBabyIDs: Set<UUID> = []
    var activeShare: CKShare?
    var participants: [CKShare.Participant] = []

    enum SharingStatus: Equatable {
        case none
        case preparing
        case active
        case error(String)
    }

    private init() {
        loadSharedBabyIDs()
    }

    // MARK: - Zone Management

    func zoneID(for babyID: UUID) -> CKRecordZone.ID {
        CKRecordZone.ID(zoneName: "SharedBaby-\(babyID.uuidString)", ownerName: CKCurrentUserDefaultName)
    }

    private func ensureZoneExists(_ zoneID: CKRecordZone.ID) async throws {
        let zone = CKRecordZone(zoneID: zoneID)
        let database = container.privateCloudDatabase
        do {
            _ = try await database.save(zone)
            logger.info("Created shared zone: \(zoneID.zoneName)")
        } catch let error as CKError where error.code == .serverRejectedRequest {
            // Zone already exists, that's fine
            logger.info("Zone already exists: \(zoneID.zoneName)")
        }
    }

    // MARK: - Create Share

    /// Creates a CKShare for a baby profile and all its child records.
    /// Returns the CKShare for use with UICloudSharingController.
    func createShare(for baby: Baby, in context: ModelContext) async throws -> CKShare {
        sharingStatus = .preparing
        let zone = zoneID(for: baby.id)

        do {
            // 1. Create the custom zone
            try await ensureZoneExists(zone)

            // 2. Convert baby + all children to CKRecords
            var records: [CKRecord] = []

            let babyRecord = baby.toCKRecord(in: zone)
            records.append(babyRecord)

            for activity in baby.activities ?? [] {
                records.append(activity.toCKRecord(in: zone))
            }
            for growth in baby.growthRecords ?? [] {
                records.append(growth.toCKRecord(in: zone))
            }
            for health in baby.healthRecords ?? [] {
                records.append(health.toCKRecord(in: zone))
            }

            // 3. Save records to CloudKit
            try await saveRecords(records, to: container.privateCloudDatabase)

            // 4. Create CKShare rooted at the baby record
            let share = CKShare(rootRecord: babyRecord)
            share[CKShare.SystemFieldKey.title] = baby.displayName as CKRecordValue
            share.publicPermission = .readWrite

            // Save the share
            try await saveRecords([babyRecord, share], to: container.privateCloudDatabase)

            // 5. Update local state
            baby.ckRecordName = babyRecord.recordID.recordName
            baby.isShared = true
            try? context.save()

            sharedBabyIDs.insert(baby.id)
            saveSharedBabyIDs()
            activeShare = share
            participants = share.participants.filter { $0.role != .owner }
            sharingStatus = .active

            logger.info("Share created for baby: \(baby.displayName)")
            return share
        } catch {
            sharingStatus = .error(error.localizedDescription)
            logger.error("Failed to create share: \(error.localizedDescription)")
            throw error
        }
    }

    // MARK: - Accept Share

    /// Accepts a CloudKit share and syncs the shared baby data into SwiftData.
    func acceptShare(metadata: CKShare.Metadata, in context: ModelContext) async throws {
        sharingStatus = .preparing

        do {
            // 1. Accept the share
            try await container.accept(metadata)
            logger.info("Share accepted")

            // 2. Fetch all records from the shared zone
            let sharedDB = container.sharedCloudDatabase
            let zoneID = metadata.share.recordID.zoneID

            let records = try await fetchAllRecords(in: zoneID, from: sharedDB)

            // 3. Process records — find the baby first
            var babyRecord: CKRecord?
            var childRecords: [CKRecord] = []

            for record in records {
                if record.recordType == Baby.ckRecordType {
                    babyRecord = record
                } else {
                    childRecords.append(record)
                }
            }

            guard let babyRecord = babyRecord else {
                throw SharingError.noBabyFound
            }

            // 4. Create or update Baby in SwiftData
            let babyID = UUID(uuidString: babyRecord.recordID.recordName) ?? UUID()
            let baby = Baby(firstName: "", dateOfBirth: Date())
            baby.id = babyID
            baby.applyCKRecord(babyRecord)
            baby.isShared = true
            baby.ownerName = metadata.ownerIdentity.nameComponents?.formatted() ?? "Partner"

            context.insert(baby)

            // 5. Create child records
            for record in childRecords {
                switch record.recordType {
                case Activity.ckRecordType:
                    let activity = Activity(type: .note, baby: baby)
                    if let recordID = UUID(uuidString: record.recordID.recordName) {
                        activity.id = recordID
                    }
                    activity.applyCKRecord(record)
                    activity.baby = baby
                    context.insert(activity)

                case GrowthRecord.ckRecordType:
                    let growth = GrowthRecord(baby: baby)
                    if let recordID = UUID(uuidString: record.recordID.recordName) {
                        growth.id = recordID
                    }
                    growth.applyCKRecord(record)
                    growth.baby = baby
                    context.insert(growth)

                case HealthRecord.ckRecordType:
                    let health = HealthRecord(baby: baby)
                    if let recordID = UUID(uuidString: record.recordID.recordName) {
                        health.id = recordID
                    }
                    health.applyCKRecord(record)
                    health.baby = baby
                    context.insert(health)

                default:
                    break
                }
            }

            try? context.save()

            sharedBabyIDs.insert(baby.id)
            saveSharedBabyIDs()
            activeShare = metadata.share
            sharingStatus = .active

            logger.info("Shared baby imported: \(baby.displayName) with \(childRecords.count) child records")
        } catch {
            sharingStatus = .error(error.localizedDescription)
            logger.error("Failed to accept share: \(error.localizedDescription)")
            throw error
        }
    }

    // MARK: - Sync Shared Records

    /// Fetches changes from the shared zone and applies them to SwiftData.
    func syncSharedRecords(for baby: Baby, in context: ModelContext) async throws {
        guard baby.isShared else { return }

        let zoneID: CKRecordZone.ID
        if baby.ownerName != nil {
            let zones = try await container.sharedCloudDatabase.allRecordZones()
            guard let zone = zones.first(where: { $0.zoneID.zoneName.contains(baby.id.uuidString) }) else {
                logger.warning("No shared zone found for baby \(baby.id)")
                return
            }
            zoneID = zone.zoneID
        } else {
            zoneID = self.zoneID(for: baby.id)
        }

        let database = baby.ownerName != nil ? container.sharedCloudDatabase : container.privateCloudDatabase
        let records = try await fetchAllRecords(in: zoneID, from: database)

        for record in records {
            switch record.recordType {
            case Baby.ckRecordType:
                baby.applyCKRecord(record)

            case Activity.ckRecordType:
                let activityID = UUID(uuidString: record.recordID.recordName)
                if let existing = (baby.activities ?? []).first(where: { $0.id == activityID }) {
                    existing.applyCKRecord(record)
                } else {
                    let activity = Activity(type: .note, baby: baby)
                    if let id = activityID { activity.id = id }
                    activity.applyCKRecord(record)
                    activity.baby = baby
                    context.insert(activity)
                }

            case GrowthRecord.ckRecordType:
                let recordID = UUID(uuidString: record.recordID.recordName)
                if let existing = (baby.growthRecords ?? []).first(where: { $0.id == recordID }) {
                    existing.applyCKRecord(record)
                } else {
                    let growth = GrowthRecord(baby: baby)
                    if let id = recordID { growth.id = id }
                    growth.applyCKRecord(record)
                    growth.baby = baby
                    context.insert(growth)
                }

            case HealthRecord.ckRecordType:
                let recordID = UUID(uuidString: record.recordID.recordName)
                if let existing = (baby.healthRecords ?? []).first(where: { $0.id == recordID }) {
                    existing.applyCKRecord(record)
                } else {
                    let health = HealthRecord(baby: baby)
                    if let id = recordID { health.id = id }
                    health.applyCKRecord(record)
                    health.baby = baby
                    context.insert(health)
                }

            default:
                break
            }
        }

        try? context.save()
        logger.info("Synced \(records.count) records for baby \(baby.displayName)")
    }

    // MARK: - Push Local Changes

    func pushLocalChanges(for baby: Baby) async throws {
        guard baby.isShared else { return }

        let zone = zoneID(for: baby.id)
        var records: [CKRecord] = []

        records.append(baby.toCKRecord(in: zone))

        for activity in baby.activities ?? [] {
            records.append(activity.toCKRecord(in: zone))
        }
        for growth in baby.growthRecords ?? [] {
            records.append(growth.toCKRecord(in: zone))
        }
        for health in baby.healthRecords ?? [] {
            records.append(health.toCKRecord(in: zone))
        }

        let database = baby.ownerName != nil ? container.sharedCloudDatabase : container.privateCloudDatabase
        try await saveRecords(records, to: database)
        logger.info("Pushed \(records.count) records for baby \(baby.displayName)")
    }

    // MARK: - Remove Participant

    /// Removes a participant from the active CKShare.
    func removeParticipant(_ participant: CKShare.Participant, for baby: Baby) async throws {
        guard let share = activeShare else {
            throw SharingError.shareCreationFailed
        }

        share.removeParticipant(participant)

        let database = container.privateCloudDatabase
        let (savedResults, _) = try await database.modifyRecords(saving: [share], deleting: [], savePolicy: .changedKeys)

        for (_, result) in savedResults {
            if case .success(let record) = result, let updatedShare = record as? CKShare {
                await MainActor.run {
                    self.activeShare = updatedShare
                    self.participants = updatedShare.participants.filter { $0.role != .owner }
                }
            }
        }

        logger.info("Removed participant from share for baby: \(baby.displayName)")
    }

    // MARK: - Stop Sharing

    func stopSharing(for baby: Baby, in context: ModelContext) async throws {
        let zone = zoneID(for: baby.id)
        let database = container.privateCloudDatabase

        try await database.deleteRecordZone(withID: zone)

        baby.isShared = false
        baby.ckRecordName = nil
        baby.ckChangeTag = nil
        try? context.save()

        sharedBabyIDs.remove(baby.id)
        saveSharedBabyIDs()
        activeShare = nil
        participants = []
        sharingStatus = .none

        logger.info("Stopped sharing baby: \(baby.displayName)")
    }

    // MARK: - Fetch Share Info

    func fetchShareInfo(for baby: Baby) async {
        guard baby.isShared, let recordName = baby.ckRecordName else { return }

        let zone = zoneID(for: baby.id)
        let recordID = CKRecord.ID(recordName: recordName, zoneID: zone)
        let database = baby.ownerName != nil ? container.sharedCloudDatabase : container.privateCloudDatabase

        do {
            let record = try await database.record(for: recordID)
            if let shareRef = record.share {
                let share = try await database.record(for: shareRef.recordID) as! CKShare
                await MainActor.run {
                    self.activeShare = share
                    self.participants = share.participants.filter { $0.role != .owner }
                }
            }
        } catch {
            logger.error("Failed to fetch share info: \(error.localizedDescription)")
        }
    }

    // MARK: - Subscriptions

    func setupSubscriptions() async throws {
        let subscription = CKDatabaseSubscription(subscriptionID: Self.sharedSubscriptionID)
        let notificationInfo = CKSubscription.NotificationInfo()
        notificationInfo.shouldSendContentAvailable = true
        subscription.notificationInfo = notificationInfo

        try await container.sharedCloudDatabase.save(subscription)
        logger.info("Shared database subscription set up")
    }

    // MARK: - Helpers

    private func saveRecords(_ records: [CKRecord], to database: CKDatabase) async throws {
        let batchSize = 400
        for start in stride(from: 0, to: records.count, by: batchSize) {
            let end = min(start + batchSize, records.count)
            let batch = Array(records[start..<end])
            let (_, _) = try await database.modifyRecords(saving: batch, deleting: [], savePolicy: .changedKeys)
        }
    }

    private func fetchAllRecords(in zoneID: CKRecordZone.ID, from database: CKDatabase) async throws -> [CKRecord] {
        var allRecords: [CKRecord] = []

        for recordType in [Baby.ckRecordType, Activity.ckRecordType, GrowthRecord.ckRecordType, HealthRecord.ckRecordType] {
            let query = CKQuery(recordType: recordType, predicate: NSPredicate(value: true))
            let (results, _) = try await database.records(matching: query, inZoneWith: zoneID)
            for (_, result) in results {
                if case .success(let record) = result {
                    allRecords.append(record)
                }
            }
        }

        return allRecords
    }

    // MARK: - Persistence

    private func loadSharedBabyIDs() {
        if let data = UserDefaults.standard.data(forKey: "sharedBabyIDs"),
           let ids = try? JSONDecoder().decode(Set<UUID>.self, from: data) {
            sharedBabyIDs = ids
        }
    }

    private func saveSharedBabyIDs() {
        if let data = try? JSONEncoder().encode(sharedBabyIDs) {
            UserDefaults.standard.set(data, forKey: "sharedBabyIDs")
        }
    }
}

// MARK: - Errors

enum SharingError: LocalizedError {
    case noBabyFound
    case shareCreationFailed
    case syncFailed

    var errorDescription: String? {
        switch self {
        case .noBabyFound: return "No baby profile found in shared data"
        case .shareCreationFailed: return "Failed to create sharing link"
        case .syncFailed: return "Failed to sync shared data"
        }
    }
}
