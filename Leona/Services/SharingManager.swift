import Foundation
import CloudKit
import SwiftData
import os.log

private let logger = Logger(subsystem: "com.leona.app", category: "Sharing")

/// Manages CloudKit sharing of baby profiles between different iCloud accounts.
/// Uses CKShare alongside the existing SwiftData stack.
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
        } catch let error as CKError {
            // Zone already exists — various error codes depending on CloudKit state
            if error.code == .serverRejectedRequest || error.code == .zoneNotFound {
                logger.info("Zone issue (may already exist): \(zoneID.zoneName) — \(error.code.rawValue)")
            } else {
                throw error
            }
        }
    }

    // MARK: - Get or Create Share

    /// Gets an existing share or creates a new one.
    /// Handles all edge cases: first time, app restart, partial failures.
    func getOrCreateShare(for baby: Baby, in context: ModelContext) async throws -> CKShare {
        sharingStatus = .preparing
        let database = container.privateCloudDatabase

        do {
            // Try to fetch existing share first
            if let existingShare = try await fetchExistingShare(for: baby) {
                logger.info("Found existing share for baby: \(baby.displayName)")
                await MainActor.run {
                    self.activeShare = existingShare
                    self.participants = existingShare.participants.filter { $0.role != .owner }
                    self.sharingStatus = .active
                }

                // Make sure local state is correct
                if !baby.isShared {
                    baby.isShared = true
                    try? context.save()
                }

                return existingShare
            }

            // No existing share — create fresh
            logger.info("No existing share found, creating new one for baby: \(baby.displayName)")
            return try await createFreshShare(for: baby, in: context)
        } catch {
            sharingStatus = .error(error.localizedDescription)
            logger.error("Failed to get/create share: \(error.localizedDescription)")
            throw error
        }
    }

    /// Fetches an existing CKShare from CloudKit for this baby.
    private func fetchExistingShare(for baby: Baby) async throws -> CKShare? {
        let zone = zoneID(for: baby.id)
        let database = container.privateCloudDatabase

        // Try to fetch the baby record from CloudKit
        let recordName = baby.ckRecordName ?? baby.id.uuidString
        let recordID = CKRecord.ID(recordName: recordName, zoneID: zone)

        do {
            let record = try await database.record(for: recordID)
            // Check if this record has a share reference
            if let shareRef = record.share {
                let shareRecord = try await database.record(for: shareRef.recordID)
                if let share = shareRecord as? CKShare {
                    return share
                }
            }
        } catch let error as CKError where error.code == .unknownItem || error.code == .zoneNotFound {
            // Record or zone doesn't exist yet — that's fine, we'll create fresh
            logger.info("No existing record/zone found for baby \(baby.id)")
        }

        return nil
    }

    /// Creates a brand new share from scratch (clean zone, records, share).
    private func createFreshShare(for baby: Baby, in context: ModelContext) async throws -> CKShare {
        let zone = zoneID(for: baby.id)
        let database = container.privateCloudDatabase

        // 1. Clean up any leftover zone from failed attempts
        do {
            try await database.deleteRecordZone(withID: zone)
            logger.info("Cleaned up leftover zone: \(zone.zoneName)")
        } catch {
            // Zone didn't exist — that's fine
            logger.info("No leftover zone to clean: \(zone.zoneName)")
        }

        // 2. Create fresh zone
        let newZone = CKRecordZone(zoneID: zone)
        _ = try await database.save(newZone)
        logger.info("Created fresh zone: \(zone.zoneName)")

        // 3. Convert baby to CKRecord + create share together
        let babyRecord = baby.toCKRecord(in: zone)
        let share = CKShare(rootRecord: babyRecord)
        share[CKShare.SystemFieldKey.title] = baby.displayName as CKRecordValue
        share.publicPermission = .readWrite

        // 4. Save baby + share in ONE operation
        let (shareResults, _) = try await database.modifyRecords(
            saving: [babyRecord, share],
            deleting: [],
            savePolicy: .allKeys
        )

        // Extract the saved CKShare (has .url populated)
        var savedShare = share
        for (_, result) in shareResults {
            if case .success(let record) = result, let returnedShare = record as? CKShare {
                savedShare = returnedShare
            }
        }

        // 5. Save child records
        var childRecords: [CKRecord] = []
        for activity in baby.activities ?? [] {
            childRecords.append(activity.toCKRecord(in: zone))
        }
        for growth in baby.growthRecords ?? [] {
            childRecords.append(growth.toCKRecord(in: zone))
        }
        for health in baby.healthRecords ?? [] {
            childRecords.append(health.toCKRecord(in: zone))
        }
        if !childRecords.isEmpty {
            try await saveRecords(childRecords, to: database)
        }

        // 6. Update local state
        baby.ckRecordName = babyRecord.recordID.recordName
        baby.isShared = true
        try? context.save()

        sharedBabyIDs.insert(baby.id)
        saveSharedBabyIDs()
        activeShare = savedShare
        participants = savedShare.participants.filter { $0.role != .owner }
        sharingStatus = .active

        logger.info("Fresh share created for baby: \(baby.displayName), URL: \(savedShare.url?.absoluteString ?? "nil")")
        return savedShare
    }

    /// Legacy alias — redirects to getOrCreateShare
    func createShare(for baby: Baby, in context: ModelContext) async throws -> CKShare {
        try await getOrCreateShare(for: baby, in: context)
    }

    // MARK: - Accept Share

    /// Accepts a CloudKit share and syncs the shared baby data into SwiftData.
    /// Handles re-acceptance gracefully by updating existing records instead of duplicating.
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

            // 4. Create or update Baby in SwiftData — avoid duplicates
            let babyID = UUID(uuidString: babyRecord.recordID.recordName) ?? UUID()
            let ownerName = metadata.ownerIdentity.nameComponents?.formatted() ?? "Partner"

            let baby: Baby
            let existingDescriptor = FetchDescriptor<Baby>(predicate: #Predicate { $0.id == babyID })
            if let existingBaby = try context.fetch(existingDescriptor).first {
                baby = existingBaby
                logger.info("Found existing baby \(baby.displayName), updating instead of duplicating")
            } else {
                baby = Baby(firstName: "", dateOfBirth: Date())
                baby.id = babyID
                context.insert(baby)
                logger.info("Created new baby record for shared baby")
            }

            baby.applyCKRecord(babyRecord)
            baby.isShared = true
            baby.ownerName = ownerName

            // 5. Create or update child records — avoid duplicates
            for record in childRecords {
                switch record.recordType {
                case Activity.ckRecordType:
                    let recordID = UUID(uuidString: record.recordID.recordName)
                    if let id = recordID, let existing = (baby.activities ?? []).first(where: { $0.id == id }) {
                        existing.applyCKRecord(record)
                    } else {
                        let activity = Activity(type: .note, baby: baby)
                        if let id = recordID { activity.id = id }
                        activity.applyCKRecord(record)
                        activity.baby = baby
                        context.insert(activity)
                    }

                case GrowthRecord.ckRecordType:
                    let recordID = UUID(uuidString: record.recordID.recordName)
                    if let id = recordID, let existing = (baby.growthRecords ?? []).first(where: { $0.id == id }) {
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
                    if let id = recordID, let existing = (baby.healthRecords ?? []).first(where: { $0.id == id }) {
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

            try context.save()

            sharedBabyIDs.insert(baby.id)
            saveSharedBabyIDs()
            activeShare = metadata.share
            sharingStatus = .active

            logger.info("Shared baby imported/updated: \(baby.displayName) with \(childRecords.count) child records")
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
            // We're the participant — fetch from shared database
            let zones = try await container.sharedCloudDatabase.allRecordZones()
            let expectedZoneName = "SharedBaby-\(baby.id.uuidString)"

            // Try exact match first, then fallback to contains
            if let zone = zones.first(where: { $0.zoneID.zoneName == expectedZoneName })
                ?? zones.first(where: { $0.zoneID.zoneName.contains(baby.id.uuidString) }) {
                zoneID = zone.zoneID
            } else {
                logger.warning("No shared zone found for baby \(baby.id) among \(zones.count) zones")
                return
            }
        } else {
            // We're the owner — shared zone is in our private database
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

    /// Pushes local SwiftData changes to the shared CloudKit zone.
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

        // Update with the returned share
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

        // Delete the zone (removes all records and the share)
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

    // MARK: - Add Participant by Email

    /// Looks up a CloudKit participant by their iCloud email address.
    private func lookupShareParticipant(email: String) async throws -> CKShare.Participant {
        let lookupInfo = CKUserIdentity.LookupInfo(emailAddress: email)

        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<CKShare.Participant, Error>) in
            let lock = NSLock()
            var hasResumed = false

            func resumeOnce(with result: Result<CKShare.Participant, Error>) {
                lock.lock()
                defer { lock.unlock() }
                guard !hasResumed else { return }
                hasResumed = true
                switch result {
                case .success(let value):
                    continuation.resume(returning: value)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }

            let operation = CKFetchShareParticipantsOperation(userIdentityLookupInfos: [lookupInfo])
            operation.qualityOfService = .userInitiated

            operation.perShareParticipantResultBlock = { _, result in
                resumeOnce(with: result)
            }

            operation.fetchShareParticipantsResultBlock = { result in
                switch result {
                case .failure(let error):
                    resumeOnce(with: .failure(error))
                case .success:
                    resumeOnce(with: .failure(SharingError.participantNotFound))
                }
            }

            self.container.add(operation)
        }
    }

    /// Adds a participant to the baby's CKShare by their iCloud email address.
    /// Creates the share if it doesn't exist yet.
    func addParticipantByEmail(_ email: String, for baby: Baby, in context: ModelContext) async throws {
        logger.info("Looking up participant for email: \(email)")

        // 1. Get or create the share
        let share = try await getOrCreateShare(for: baby, in: context)

        // 2. Look up the participant by email
        let participant: CKShare.Participant
        do {
            participant = try await lookupShareParticipant(email: email)
        } catch {
            logger.error("Participant lookup failed for \(email): \(error.localizedDescription)")
            throw SharingError.participantNotFound
        }

        // 3. Configure and add participant
        participant.permission = .readWrite
        share.addParticipant(participant)

        // 4. Save the updated share
        let database = container.privateCloudDatabase
        let (savedResults, _) = try await database.modifyRecords(
            saving: [share],
            deleting: [],
            savePolicy: .changedKeys
        )

        // 5. Update local state with the saved share
        for (_, result) in savedResults {
            if case .success(let record) = result, let updatedShare = record as? CKShare {
                await MainActor.run {
                    self.activeShare = updatedShare
                    self.participants = updatedShare.participants.filter { $0.role != .owner }
                    self.sharingStatus = .active
                }
            }
        }

        logger.info("Successfully invited \(email) for baby: \(baby.displayName)")
    }

    /// Returns the share URL for link sharing. Creates the share if needed.
    func getShareURL(for baby: Baby, in context: ModelContext) async throws -> URL {
        let share = try await getOrCreateShare(for: baby, in: context)
        guard let url = share.url else {
            logger.error("Share created but URL is nil for baby: \(baby.displayName)")
            throw SharingError.shareURLMissing
        }
        logger.info("Share URL ready: \(url.absoluteString)")
        return url
    }

    // MARK: - Helpers

    private func saveRecords(_ records: [CKRecord], to database: CKDatabase) async throws {
        // Save in batches of 400 (CloudKit limit)
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
    case shareURLMissing
    case syncFailed
    case participantNotFound
    case invalidEmail

    var errorDescription: String? {
        switch self {
        case .noBabyFound: return String(localized: "share_error_no_baby")
        case .shareCreationFailed: return String(localized: "share_error_creation_failed")
        case .shareURLMissing: return String(localized: "share_error_url_missing")
        case .syncFailed: return String(localized: "share_error_sync_failed")
        case .participantNotFound: return String(localized: "share_error_participant_not_found")
        case .invalidEmail: return String(localized: "share_error_invalid_email")
        }
    }
}
