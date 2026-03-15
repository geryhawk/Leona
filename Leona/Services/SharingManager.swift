import Foundation
import CloudKit
import SwiftData
import os.log

private let logger = Logger(subsystem: "com.leona.app", category: "Sharing")

/// Manages CloudKit sharing of baby profiles between different iCloud accounts.
/// Uses CKShare alongside the existing SwiftData stack.
@MainActor
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
    var invitedEmails: [String: String] = [:]
    var accountStatus: CKAccountStatus = .couldNotDetermine
    
    private var accountStatusChecked = false
    private var accountCheckTask: Task<Void, Never>?
    private var lastRecoveryScanDate: Date?
    private let recoveryScanCooldown: TimeInterval = 20.0
    private var remoteImportDepth = 0

    enum SharingStatus: Equatable {
        case none
        case preparing
        case active
        case error(String)
    }

    private init() {
        loadSharedBabyIDs()
        loadInvitedEmails()
        // Don't start account check in init - will be done on-demand or in app startup
        // This prevents duplicate checks and race conditions
    }
    
    // MARK: - Account Status
    
    /// Checks CloudKit account status and caches the result.
    /// Call this early in app lifecycle to avoid "could not validate account info cache" warnings.
    private func checkAccountStatus() async {
        guard !accountStatusChecked else { return }

        do {
            let status = try await container.accountStatus()
            self.accountStatus = status
            self.accountStatusChecked = true

            switch status {
            case .available:
                logger.info("iCloud account is available")
            case .noAccount:
                logger.warning("No iCloud account configured")
            case .restricted:
                logger.warning("iCloud account is restricted")
            case .couldNotDetermine:
                logger.warning("Could not determine iCloud account status")
            case .temporarilyUnavailable:
                logger.warning("iCloud account temporarily unavailable")
            @unknown default:
                logger.warning("Unknown iCloud account status")
            }
        } catch {
            logger.error("Failed to check account status: \(error.localizedDescription)")
            self.accountStatusChecked = true
        }
    }
    
    /// Ensures account status is checked and ready.
    /// Call this before any CloudKit operations to warm up the account cache.
    func ensureAccountStatusChecked() async {
        if !accountStatusChecked {
            await checkAccountStatus()
        }
    }
    
    /// Requests permission to access the user's CloudKit account.
    /// This helps warm up the account cache and prevents validation warnings.
    func requestAccountAccess() async throws {
        // First ensure status is checked
        await ensureAccountStatusChecked()
        
        // For CloudKit, we don't need explicit permission requests like Photos/Contacts
        // But we can trigger a status check which warms up the cache
        guard self.accountStatus == .available else {
            logger.warning("CloudKit account not available: \(String(describing: self.accountStatus))")
            throw SharingError.accountUnavailable
        }
        
        logger.info("CloudKit account access confirmed")
    }

    var isApplyingRemoteChanges: Bool {
        remoteImportDepth > 0
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

    private func matchingSharedZoneID(for babyID: UUID, in zones: [CKRecordZone]) -> CKRecordZone.ID? {
        let expectedZoneName = "SharedBaby-\(babyID.uuidString)"

        return zones.first(where: { $0.zoneID.zoneName == expectedZoneName })?.zoneID
            ?? zones.first(where: { $0.zoneID.zoneName.contains(babyID.uuidString) })?.zoneID
    }

    private func sharedZoneID(for baby: Baby) async throws -> CKRecordZone.ID? {
        let zones = try await container.sharedCloudDatabase.allRecordZones()
        return matchingSharedZoneID(for: baby.id, in: zones)
    }

    private func resolveZoneContext(for baby: Baby) async throws -> (zoneID: CKRecordZone.ID, database: CKDatabase) {
        if let sharedZoneID = try await sharedZoneID(for: baby) {
            return (sharedZoneID, container.sharedCloudDatabase)
        }

        return (zoneID(for: baby.id), container.privateCloudDatabase)
    }

    // MARK: - Get or Create Share

    /// Gets an existing share or creates a new one.
    /// Handles all edge cases: first time, app restart, partial failures.
    func getOrCreateShare(for baby: Baby, in context: ModelContext) async throws -> CKShare {
        // Ensure account status is checked first (warms up CloudKit cache)
        await ensureAccountStatusChecked()
        
        // Check account status
        guard accountStatus == .available else {
            throw SharingError.accountUnavailable
        }
        
        sharingStatus = .preparing

        do {
            // Try to fetch existing share first
            if let existingShare = try await fetchExistingShare(for: baby) {
                logger.info("Found existing share for baby: \(baby.displayName)")
                self.activeShare = existingShare
                self.participants = existingShare.participants.filter { $0.role != .owner }
                self.sharingStatus = .active

                if !baby.isShared {
                    baby.isShared = true
                    try? context.save()
                }

                return existingShare
            }

            // No existing share found on CloudKit — reset stale local state
            if baby.isShared {
                logger.info("Baby marked as shared locally but no share on CloudKit — resetting state")
                baby.isShared = false
                baby.ckRecordName = nil
                baby.ckChangeTag = nil
                try? context.save()
            }

            // Create fresh share
            logger.info("Creating new share for baby: \(baby.displayName)")
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
    /// IMPORTANT: The rootRecord (baby) and CKShare MUST be saved in the same
    /// modifyRecords operation — CloudKit rejects orphaned shares.
    private func createFreshShare(for baby: Baby, in context: ModelContext) async throws -> CKShare {
        let zone = zoneID(for: baby.id)
        let database = container.privateCloudDatabase
        saveChangeToken(nil, for: zone)

        // 1. Clean up any leftover zone from failed attempts
        do {
            try await database.deleteRecordZone(withID: zone)
            logger.info("Cleaned up leftover zone: \(zone.zoneName)")
        } catch {
            logger.info("No leftover zone to clean: \(zone.zoneName)")
        }

        // 2. Create fresh zone
        let newZone = CKRecordZone(zoneID: zone)
        _ = try await database.save(newZone)
        logger.info("Created fresh zone: \(zone.zoneName)")

        // 3. Build rootRecord + share
        let babyRecord = baby.toCKRecord(in: zone)
        let share = CKShare(rootRecord: babyRecord)
        share[CKShare.SystemFieldKey.title] = baby.displayName as CKRecordValue
        share.publicPermission = .readWrite

        // 4. Save rootRecord + share in ONE atomic operation (mandatory)
        let saveOp = CKModifyRecordsOperation(recordsToSave: [babyRecord, share], recordIDsToDelete: nil)
        saveOp.savePolicy = .allKeys
        saveOp.isAtomic = true
        saveOp.qualityOfService = .userInitiated

        let savedShare: CKShare = try await withCheckedThrowingContinuation { continuation in
            var resultShare: CKShare?
            var recordErrors: [CKRecord.ID: Error] = [:]

            saveOp.perRecordSaveBlock = { recordID, result in
                switch result {
                case .success(let record):
                    if let s = record as? CKShare {
                        resultShare = s
                    }
                    logger.info("Saved record: \(recordID.recordName) (type: \(record.recordType))")
                case .failure(let error):
                    recordErrors[recordID] = error
                    logger.error("Failed to save record \(recordID.recordName): \(error.localizedDescription)")
                }
            }

            saveOp.modifyRecordsResultBlock = { result in
                switch result {
                case .success:
                    if let savedShare = resultShare {
                        logger.info("Atomic save succeeded — share has changeTag: \(savedShare.recordChangeTag ?? "nil")")
                        continuation.resume(returning: savedShare)
                    } else {
                        logger.error("Atomic save succeeded but CKShare not found in results")
                        continuation.resume(throwing: SharingError.shareCreationFailed)
                    }
                case .failure(let error):
                    logger.error("Atomic save FAILED: \(error.localizedDescription)")
                    for (id, err) in recordErrors {
                        logger.error("  Record \(id.recordName): \(err.localizedDescription)")
                    }
                    continuation.resume(throwing: error)
                }
            }

            database.add(saveOp)
        }

        logger.info("Root record + share saved atomically, changeTag: \(savedShare.recordChangeTag ?? "nil")")

        // 5. Save child records (separate operation — these don't need atomic with share)
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

        logger.info("Fresh share created for baby: \(baby.displayName), ready for sharing")
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
            saveChangeToken(nil, for: zoneID)
            let records = try await fetchAllRecordsWithRetry(in: zoneID, from: sharedDB)
            let ownerName = metadata.ownerIdentity.nameComponents?.formatted() ?? "Partner"
            let (baby, childCount) = try importSharedRecords(records, ownerName: ownerName, in: context)

            activeShare = metadata.share
            sharingStatus = .active
            logger.info("Shared baby imported/updated: \(baby.displayName) with \(childCount) child records")
        } catch {
            sharingStatus = .error(error.localizedDescription)
            logger.error("Failed to accept share: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// Fallback recovery path for scene-based apps:
    /// scans already-accepted shared zones and imports missing babies.
    /// This prevents "invitation accepted but baby not visible" if delegate callbacks were missed.
    func recoverAcceptedSharesIfNeeded(in context: ModelContext) async {
        let now = Date()
        if let lastScan = lastRecoveryScanDate,
           now.timeIntervalSince(lastScan) < recoveryScanCooldown {
            return
        }
        lastRecoveryScanDate = now
        
        await ensureAccountStatusChecked()
        guard accountStatus == .available else { return }
        
        do {
            let sharedDB = container.sharedCloudDatabase
            let zones = try await sharedDB.allRecordZones()
            guard !zones.isEmpty else { return }
            
            var recoveredCount = 0
            for zone in zones {
                do {
                    let records = try await fetchAllRecords(in: zone.zoneID, from: sharedDB)
                    guard let babyRecord = records.first(where: { $0.recordType == Baby.ckRecordType }),
                          let babyID = UUID(uuidString: babyRecord.recordID.recordName) else {
                        continue
                    }
                    
                    let descriptor = FetchDescriptor<Baby>(predicate: #Predicate { $0.id == babyID })
                    if try context.fetch(descriptor).first != nil {
                        continue
                    }
                    
                    saveChangeToken(nil, for: zone.zoneID)
                    _ = try importSharedRecords(records, ownerName: "Partner", in: context)
                    recoveredCount += 1
                    logger.info("Recovered missing shared baby from zone \(zone.zoneID.zoneName)")
                } catch {
                    logger.error("Failed to recover shared zone \(zone.zoneID.zoneName): \(error.localizedDescription)")
                }
            }
            
            if recoveredCount > 0 {
                sharingStatus = .active
                logger.info("Recovered \(recoveredCount) previously accepted share(s)")
            }
        } catch {
            logger.error("Failed scanning shared zones for recovery: \(error.localizedDescription)")
        }
    }

    /// Imports a full shared zone payload into SwiftData (upsert).
    private func importSharedRecords(
        _ records: [CKRecord],
        ownerName: String,
        in context: ModelContext
    ) throws -> (baby: Baby, childCount: Int) {
        remoteImportDepth += 1
        defer { remoteImportDepth -= 1 }

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

        let babyID = UUID(uuidString: babyRecord.recordID.recordName) ?? UUID()
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
        
        // Never overwrite a known owner name with the generic fallback.
        let trimmedOwnerName = ownerName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedOwnerName.isEmpty {
            if trimmedOwnerName != "Partner" || baby.ownerName == nil || baby.ownerName?.isEmpty == true {
                baby.ownerName = trimmedOwnerName
            }
        }

        for record in childRecords {
            switch record.recordType {
            case Activity.ckRecordType:
                let recordID = UUID(uuidString: record.recordID.recordName)
                
                // Skip if this record was deleted locally
                if let id = recordID, isRecordDeleted(id) {
                    logger.info("Skipping deleted activity during share import: \(id)")
                    continue
                }
                
                if let id = recordID, let existing = (baby.activities ?? []).first(where: { $0.id == id }) {
                    existing.applyCKRecord(record)
                } else {
                    // Create without baby to avoid ghost card via inverse relationship
                    let activity = Activity(type: .note, startTime: Date(), baby: nil)
                    if let id = recordID { activity.id = id }
                    activity.applyCKRecord(record)
                    context.insert(activity)
                    activity.baby = baby
                }

            case GrowthRecord.ckRecordType:
                let recordID = UUID(uuidString: record.recordID.recordName)
                
                // Skip if this record was deleted locally
                if let id = recordID, isRecordDeleted(id) {
                    logger.info("Skipping deleted growth record during share import: \(id)")
                    continue
                }
                
                if let id = recordID, let existing = (baby.growthRecords ?? []).first(where: { $0.id == id }) {
                    existing.applyCKRecord(record)
                } else {
                    let growth = GrowthRecord(baby: nil)
                    if let id = recordID { growth.id = id }
                    growth.applyCKRecord(record)
                    context.insert(growth)
                    growth.baby = baby
                }

            case HealthRecord.ckRecordType:
                let recordID = UUID(uuidString: record.recordID.recordName)
                
                // Skip if this record was deleted locally
                if let id = recordID, isRecordDeleted(id) {
                    logger.info("Skipping deleted health record during share import: \(id)")
                    continue
                }
                
                if let id = recordID, let existing = (baby.healthRecords ?? []).first(where: { $0.id == id }) {
                    existing.applyCKRecord(record)
                } else {
                    let health = HealthRecord(baby: nil)
                    if let id = recordID { health.id = id }
                    health.applyCKRecord(record)
                    context.insert(health)
                    health.baby = baby
                }

            default:
                break
            }
        }

        try context.save()
        sharedBabyIDs.insert(baby.id)
        saveSharedBabyIDs()
        return (baby, childRecords.count)
    }

    /// CloudKit can lag a short time between share acceptance and record visibility.
    /// Retry briefly to avoid false "no baby found" errors on real devices.
    private func fetchAllRecordsWithRetry(in zoneID: CKRecordZone.ID, from database: CKDatabase) async throws -> [CKRecord] {
        let maxAttempts = 4
        
        for attempt in 1...maxAttempts {
            do {
                let records = try await fetchAllRecords(in: zoneID, from: database)
                if records.contains(where: { $0.recordType == Baby.ckRecordType }) {
                    return records
                }
                
                if attempt == maxAttempts {
                    throw SharingError.noBabyFound
                }
                
                logger.warning("Shared zone has no baby record yet (attempt \(attempt)); retrying")
            } catch {
                if attempt == maxAttempts || !isTransientCloudKitError(error) {
                    throw error
                }
                logger.warning("Transient CloudKit fetch error while importing share (attempt \(attempt)): \(error.localizedDescription)")
            }
            
            let delay = UInt64(Double(attempt) * 700_000_000) // 0.7s, 1.4s, 2.1s
            try? await Task.sleep(nanoseconds: delay)
        }
        
        throw SharingError.noBabyFound
    }

    private func isTransientCloudKitError(_ error: Error) -> Bool {
        guard let ckError = error as? CKError else { return false }
        switch ckError.code {
        case .networkUnavailable, .networkFailure, .serviceUnavailable, .requestRateLimited,
             .zoneBusy, .serverResponseLost, .partialFailure, .changeTokenExpired:
            return true
        default:
            return false
        }
    }

    private struct ZoneChangesBatch {
        let changedRecords: [CKRecord]
        let deletedRecordIDs: [CKRecord.ID]
        let serverChangeToken: CKServerChangeToken?
    }

    private func changeTokenKey(for zoneID: CKRecordZone.ID) -> String {
        "changeToken.\(zoneID.ownerName).\(zoneID.zoneName)"
    }

    private func loadChangeToken(for zoneID: CKRecordZone.ID) -> CKServerChangeToken? {
        let key = changeTokenKey(for: zoneID)
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }

        return try? NSKeyedUnarchiver.unarchivedObject(
            ofClass: CKServerChangeToken.self,
            from: data
        )
    }

    private func saveChangeToken(_ token: CKServerChangeToken?, for zoneID: CKRecordZone.ID) {
        let key = changeTokenKey(for: zoneID)

        guard let token else {
            UserDefaults.standard.removeObject(forKey: key)
            return
        }

        if let data = try? NSKeyedArchiver.archivedData(withRootObject: token, requiringSecureCoding: true) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    private func fetchZoneChanges(
        in zoneID: CKRecordZone.ID,
        from database: CKDatabase,
        since previousToken: CKServerChangeToken?
    ) async throws -> ZoneChangesBatch {
        try await withCheckedThrowingContinuation { continuation in
            var changedRecords: [CKRecord] = []
            var deletedRecordIDs: [CKRecord.ID] = []
            var serverChangeToken = previousToken

            let config = CKFetchRecordZoneChangesOperation.ZoneConfiguration()
            config.previousServerChangeToken = previousToken

            let operation = CKFetchRecordZoneChangesOperation(
                recordZoneIDs: [zoneID],
                configurationsByRecordZoneID: [zoneID: config]
            )
            operation.qualityOfService = .userInitiated

            operation.recordWasChangedBlock = { _, result in
                if case .success(let record) = result {
                    changedRecords.append(record)
                }
            }

            operation.recordWithIDWasDeletedBlock = { recordID, _ in
                deletedRecordIDs.append(recordID)
            }

            operation.recordZoneFetchResultBlock = { _, result in
                if case .success(let zoneResult) = result {
                    serverChangeToken = zoneResult.serverChangeToken
                }
            }

            operation.fetchRecordZoneChangesResultBlock = { result in
                switch result {
                case .success:
                    continuation.resume(returning: ZoneChangesBatch(
                        changedRecords: changedRecords,
                        deletedRecordIDs: deletedRecordIDs,
                        serverChangeToken: serverChangeToken
                    ))
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }

            database.add(operation)
        }
    }

    // MARK: - Sync Shared Records

    /// Fetches changes from the shared zone and applies them to SwiftData.
    func syncSharedRecords(for baby: Baby, in context: ModelContext) async throws {
        guard baby.isShared else { return }

        let resolved = try await resolveZoneContext(for: baby)
        let previousToken = loadChangeToken(for: resolved.zoneID)
        let batch: ZoneChangesBatch

        do {
            batch = try await fetchZoneChanges(
                in: resolved.zoneID,
                from: resolved.database,
                since: previousToken
            )
        } catch let error as CKError where error.code == .changeTokenExpired {
            logger.warning("Change token expired for zone \(resolved.zoneID.zoneName), refetching full state")
            saveChangeToken(nil, for: resolved.zoneID)
            batch = try await fetchZoneChanges(
                in: resolved.zoneID,
                from: resolved.database,
                since: nil
            )
        }

        remoteImportDepth += 1
        defer { remoteImportDepth -= 1 }

        for record in batch.changedRecords {
            switch record.recordType {
            case Baby.ckRecordType:
                baby.applyCKRecord(record)

            case Activity.ckRecordType:
                let activityID = UUID(uuidString: record.recordID.recordName)
                
                // Skip if this record was deleted locally
                if let id = activityID, isRecordDeleted(id) {
                    logger.info("Skipping deleted activity: \(id)")
                    break
                }
                
                if let existing = (baby.activities ?? []).first(where: { $0.id == activityID }) {
                    existing.applyCKRecord(record)
                } else {
                    // Create without baby to avoid ghost card via inverse relationship
                    let activity = Activity(type: .note, startTime: Date(), baby: nil)
                    if let id = activityID { activity.id = id }
                    activity.applyCKRecord(record)
                    context.insert(activity)
                    activity.baby = baby
                }

            case GrowthRecord.ckRecordType:
                let recordID = UUID(uuidString: record.recordID.recordName)
                
                // Skip if this record was deleted locally
                if let id = recordID, isRecordDeleted(id) {
                    logger.info("Skipping deleted growth record: \(id)")
                    break
                }
                
                if let existing = (baby.growthRecords ?? []).first(where: { $0.id == recordID }) {
                    existing.applyCKRecord(record)
                } else {
                    let growth = GrowthRecord(baby: nil)
                    if let id = recordID { growth.id = id }
                    growth.applyCKRecord(record)
                    context.insert(growth)
                    growth.baby = baby
                }

            case HealthRecord.ckRecordType:
                let recordID = UUID(uuidString: record.recordID.recordName)
                
                // Skip if this record was deleted locally
                if let id = recordID, isRecordDeleted(id) {
                    logger.info("Skipping deleted health record: \(id)")
                    break
                }
                
                if let existing = (baby.healthRecords ?? []).first(where: { $0.id == recordID }) {
                    existing.applyCKRecord(record)
                } else {
                    let health = HealthRecord(baby: nil)
                    if let id = recordID { health.id = id }
                    health.applyCKRecord(record)
                    context.insert(health)
                    health.baby = baby
                }

            default:
                break
            }
        }

        for deletedRecordID in batch.deletedRecordIDs {
            if deletedRecordID.recordName == baby.id.uuidString {
                continue
            }

            if let activity = (baby.activities ?? []).first(where: { $0.id.uuidString == deletedRecordID.recordName }) {
                context.delete(activity)
                continue
            }

            if let growth = (baby.growthRecords ?? []).first(where: { $0.id.uuidString == deletedRecordID.recordName }) {
                context.delete(growth)
                continue
            }

            if let health = (baby.healthRecords ?? []).first(where: { $0.id.uuidString == deletedRecordID.recordName }) {
                context.delete(health)
            }
        }

        try? context.save()
        saveChangeToken(batch.serverChangeToken, for: resolved.zoneID)
        logger.info(
            "Synced \(batch.changedRecords.count) changed record(s) and \(batch.deletedRecordIDs.count) deletion(s) for baby \(baby.displayName)"
        )
    }

    // MARK: - Push Local Changes

    /// Pushes local SwiftData changes to the shared CloudKit zone.
    func pushLocalChanges(for baby: Baby) async throws {
        guard baby.isShared else { return }

        let resolved = try await resolveZoneContext(for: baby)
        var records: [CKRecord] = []

        records.append(baby.toCKRecord(in: resolved.zoneID))

        // Only push non-deleted records
        for activity in baby.activities ?? [] where !activity.isDeleted {
            records.append(activity.toCKRecord(in: resolved.zoneID))
        }
        for growth in baby.growthRecords ?? [] where !growth.isDeleted {
            records.append(growth.toCKRecord(in: resolved.zoneID))
        }
        for health in baby.healthRecords ?? [] where !health.isDeleted {
            records.append(health.toCKRecord(in: resolved.zoneID))
        }

        guard !records.isEmpty else {
            logger.info("No records to push for baby \(baby.displayName)")
            return
        }

        // Mark that we're pushing (to avoid triggering sync on our own notification)
        lastPushDate = Date()
        
        try await saveRecords(records, to: resolved.database)
        logger.info("Pushed \(records.count) records for baby \(baby.displayName)")
    }
    
    private var lastPushDate: Date?
    
    /// Returns true if a recent push just happened (within last 10 seconds)
    /// Increased from 3 to 10 seconds to better prevent sync loops
    var didRecentlyPush: Bool {
        guard let lastPush = lastPushDate else { return false }
        return Date().timeIntervalSince(lastPush) < 10.0
    }

    /// Deletes a record from CloudKit when deleted locally.
    func deleteRecord(recordID: UUID, recordType: String, for baby: Baby) async throws {
        guard baby.isShared else { return }
        
        // Track this deletion to prevent re-creation during sync
        trackDeletedRecord(recordID)
        
        let resolved = try await resolveZoneContext(for: baby)
        let ckRecordID = CKRecord.ID(recordName: recordID.uuidString, zoneID: resolved.zoneID)
        
        do {
            let (_, deletedIDs) = try await resolved.database.modifyRecords(saving: [], deleting: [ckRecordID])
            logger.info("Deleted \(recordType) record from CloudKit: \(recordID.uuidString)")
            
            if !deletedIDs.isEmpty {
                logger.info("Successfully deleted \(deletedIDs.count) record(s) from CloudKit")
            }
        } catch let error as CKError where error.code == .unknownItem {
            // Record doesn't exist on CloudKit - that's fine
            logger.info("Record already deleted from CloudKit: \(recordID.uuidString)")
        }
    }
    
    // MARK: - Deletion Tracking
    
    private var deletedRecordIDs: Set<UUID> {
        get {
            if let data = UserDefaults.standard.data(forKey: "deletedRecordIDs"),
               let ids = try? JSONDecoder().decode(Set<UUID>.self, from: data) {
                return ids
            }
            return []
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                UserDefaults.standard.set(data, forKey: "deletedRecordIDs")
            }
        }
    }
    
    private func trackDeletedRecord(_ recordID: UUID) {
        var ids = deletedRecordIDs
        ids.insert(recordID)
        deletedRecordIDs = ids
    }
    
    private func isRecordDeleted(_ recordID: UUID) -> Bool {
        deletedRecordIDs.contains(recordID)
    }
    
    /// Clears deletion tracking for records older than 30 days
    func cleanupDeletionTracking() {
        // This can be called periodically - for now, we keep all deleted IDs
        // In a production app, you might want to expire these after some time
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
                self.activeShare = updatedShare
                self.participants = updatedShare.participants.filter { $0.role != .owner }
            }
        }

        logger.info("Removed participant from share for baby: \(baby.displayName)")
    }

    // MARK: - Stop Sharing

    func stopSharing(for baby: Baby, in context: ModelContext) async throws {
        let zone = zoneID(for: baby.id)
        let database = container.privateCloudDatabase

        // Delete the zone (removes all records and the share)
        do {
            try await database.deleteRecordZone(withID: zone)
            logger.info("Deleted shared zone: \(zone.zoneName)")
        } catch let error as CKError where error.code == .zoneNotFound {
            logger.info("Zone already gone: \(zone.zoneName)")
        }

        // Always clean up local state regardless of CloudKit result
        baby.isShared = false
        baby.ckRecordName = nil
        baby.ckChangeTag = nil
        try? context.save()

        sharedBabyIDs.remove(baby.id)
        saveSharedBabyIDs()
        saveChangeToken(nil, for: zone)
        activeShare = nil
        participants = []
        sharingStatus = .none

        logger.info("Stopped sharing baby: \(baby.displayName)")
    }

    // MARK: - Fetch Share Info

    func fetchShareInfo(for baby: Baby) async {
        guard baby.isShared, let recordName = baby.ckRecordName else { return }

        do {
            let resolved = try await resolveZoneContext(for: baby)
            let recordID = CKRecord.ID(recordName: recordName, zoneID: resolved.zoneID)
            let record = try await resolved.database.record(for: recordID)
            if let shareRef = record.share {
                let share = try await resolved.database.record(for: shareRef.recordID) as! CKShare
                self.activeShare = share
                self.participants = share.participants.filter { $0.role != .owner }
                
                // Try to preserve any email mappings we can find
                for participant in self.participants {
                    // Check if we already have this email stored
                    if let recordID = participant.userIdentity.userRecordID,
                       invitedEmails[recordID.recordName] != nil {
                        continue // Already have it
                    }
                    
                    // Try to extract from lookup info
                    if let email = participant.userIdentity.lookupInfo?.emailAddress,
                       let recordID = participant.userIdentity.userRecordID {
                        invitedEmails[recordID.recordName] = email
                    }
                }
                saveInvitedEmails()
            }
        } catch {
            logger.error("Failed to fetch share info: \(error.localizedDescription)")
        }
    }

    // MARK: - Subscriptions

    func setupSubscriptions() async throws {
        await ensureAccountStatusChecked()
        guard accountStatus == .available else { return }

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

        // 1. Get or create the share (this ensures rootRecord + share exist on CloudKit)
        let share = try await getOrCreateShare(for: baby, in: context)
        logger.info("Share ready, recordChangeTag: \(share.recordChangeTag ?? "nil")")

        // 2. Look up the participant by email
        let participant: CKShare.Participant
        do {
            participant = try await lookupShareParticipant(email: email)
            logger.info("Participant found: \(participant.userIdentity.nameComponents?.formatted() ?? email)")
        } catch {
            logger.error("Participant lookup failed for \(email): \(error.localizedDescription)")
            throw SharingError.participantNotFound
        }

        // 3. Store the email EARLY (before we lose access to it)
        //    Use the email address as the key since userRecordID might not be available yet
        if let lookupEmail = participant.userIdentity.lookupInfo?.emailAddress {
            invitedEmails[lookupEmail] = email
        }
        // Also try storing by user record ID if available
        if let recordID = participant.userIdentity.userRecordID {
            invitedEmails[recordID.recordName] = email
        }
        saveInvitedEmails()

        // 4. Configure and add participant
        participant.permission = .readWrite
        share.addParticipant(participant)

        // 5. Save ONLY the share — the rootRecord already exists on CloudKit
        //    (it was saved atomically during createFreshShare or was already there)
        //    Re-saving a new CKRecord without server metadata causes serverRecordChanged errors.
        let database = container.privateCloudDatabase
        let (savedResults, _) = try await database.modifyRecords(
            saving: [share],
            deleting: [],
            savePolicy: .changedKeys
        )

        // Extract the server-returned share
        var savedShare = share
        for (_, result) in savedResults {
            if case .success(let record) = result, let s = record as? CKShare {
                savedShare = s
            }
        }

        // 6. Update local state
        self.activeShare = savedShare
        self.participants = savedShare.participants.filter { $0.role != .owner }
        self.sharingStatus = .active

        // 7. Store email mapping again with the FINAL participant info from saved share
        for participant in savedShare.participants {
            if let recordID = participant.userIdentity.userRecordID {
                if invitedEmails[recordID.recordName] == nil {
                    invitedEmails[recordID.recordName] = email
                }
            }
            if let lookupEmail = participant.userIdentity.lookupInfo?.emailAddress {
                if invitedEmails[lookupEmail] == nil {
                    invitedEmails[lookupEmail] = email
                }
            }
        }
        saveInvitedEmails()

        logger.info("Successfully invited \(email) for baby: \(baby.displayName)")
    }

    /// Returns the share URL for link sharing. Creates the share if needed.
    func getShareURL(for baby: Baby, in context: ModelContext) async throws -> URL {
        let share = try await getOrCreateShare(for: baby, in: context)
        guard let url = share.url else {
            logger.error("Share created but URL is nil for baby: \(baby.displayName)")
            throw SharingError.shareURLMissing
        }
        // Log only the URL string to avoid sandbox extension warnings
        logger.info("Share URL ready (length: \(url.absoluteString.count) chars)")
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

    /// Fetches ALL records in a zone using CKFetchRecordZoneChangesOperation.
    /// This does NOT require queryable indexes or pre-existing record types.
    private func fetchAllRecords(in zoneID: CKRecordZone.ID, from database: CKDatabase) async throws -> [CKRecord] {
        try await withCheckedThrowingContinuation { continuation in
            var allRecords: [CKRecord] = []

            let config = CKFetchRecordZoneChangesOperation.ZoneConfiguration()
            // Always start fresh - don't use server change tokens
            // This prevents "Change Token Expired" errors
            config.previousServerChangeToken = nil

            let operation = CKFetchRecordZoneChangesOperation(
                recordZoneIDs: [zoneID],
                configurationsByRecordZoneID: [zoneID: config]
            )
            operation.qualityOfService = .userInitiated

            operation.recordWasChangedBlock = { _, result in
                if case .success(let record) = result {
                    allRecords.append(record)
                }
            }

            operation.fetchRecordZoneChangesResultBlock = { result in
                switch result {
                case .success:
                    continuation.resume(returning: allRecords)
                case .failure(let error):
                    // Handle token expiration gracefully
                    if let ckError = error as? CKError, ckError.code == .changeTokenExpired {
                        logger.warning("Change token expired, retrying with nil token")
                        // The next fetch will use nil token automatically
                    }
                    continuation.resume(throwing: error)
                }
            }

            database.add(operation)
        }
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
    
    private func loadInvitedEmails() {
        if let data = UserDefaults.standard.data(forKey: "invitedEmails"),
           let emails = try? JSONDecoder().decode([String: String].self, from: data) {
            invitedEmails = emails
        }
    }
    
    private func saveInvitedEmails() {
        if let data = try? JSONEncoder().encode(invitedEmails) {
            UserDefaults.standard.set(data, forKey: "invitedEmails")
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
    case accountUnavailable

    var errorDescription: String? {
        switch self {
        case .noBabyFound: return String(localized: "share_error_no_baby")
        case .shareCreationFailed: return String(localized: "share_error_creation_failed")
        case .shareURLMissing: return String(localized: "share_error_url_missing")
        case .syncFailed: return String(localized: "share_error_sync_failed")
        case .participantNotFound: return String(localized: "share_error_participant_not_found")
        case .invalidEmail: return String(localized: "share_error_invalid_email")
        case .accountUnavailable: return "iCloud account is not available. Please sign in to iCloud in Settings."
        }
    }
}
