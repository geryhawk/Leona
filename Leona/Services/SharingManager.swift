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
    static let privateSubscriptionID = "private-baby-changes"
    static let sharedSubscriptionID = "shared-baby-changes"

    private struct SharedZoneBookmark: Codable {
        let zoneName: String
        let ownerName: String
    }

    private enum SharedDatabaseScope: String, Codable {
        case privateOwner
        case sharedParticipant
    }

    @ObservationIgnored
    let container = CKContainer(identifier: "iCloud.com.leona.app")

    var sharingStatus: SharingStatus = .none
    var sharedBabyIDs: Set<UUID> = []
    var activeShare: CKShare?
    var activeShareBabyID: UUID?
    var participants: [CKShare.Participant] = []
    var invitedEmails: [String: String] = [:]
    var accountStatus: CKAccountStatus = .couldNotDetermine
    private var participantFirstNames: [String: String] = [:]
    
    private var accountStatusChecked = false
    private var accountCheckTask: Task<Void, Never>?
    private var lastRecoveryScanDate: Date?
    private let recoveryScanCooldown: TimeInterval = 20.0
    private var remoteImportDepth = 0
    private var sharedZoneBookmarks: [String: SharedZoneBookmark] = [:]
    private var sharedDatabaseScopes: [String: SharedDatabaseScope] = [:]

    enum SharingStatus: Equatable {
        case none
        case preparing
        case active
        case error(String)
    }

    private init() {
        loadSharedBabyIDs()
        loadInvitedEmails()
        loadSharedZoneBookmarks()
        loadSharedDatabaseScopes()
        loadParticipantFirstNames()
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

    private func cacheSharedZoneID(_ zoneID: CKRecordZone.ID, for babyID: UUID) {
        sharedZoneBookmarks[babyID.uuidString] = SharedZoneBookmark(
            zoneName: zoneID.zoneName,
            ownerName: zoneID.ownerName
        )
        saveSharedZoneBookmarks()
    }

    private func cachedSharedZoneID(for babyID: UUID) -> CKRecordZone.ID? {
        guard let bookmark = sharedZoneBookmarks[babyID.uuidString] else { return nil }
        return CKRecordZone.ID(zoneName: bookmark.zoneName, ownerName: bookmark.ownerName)
    }

    private func clearSharedZoneID(for babyID: UUID) {
        sharedZoneBookmarks.removeValue(forKey: babyID.uuidString)
        saveSharedZoneBookmarks()
    }

    private func sharedZoneID(for baby: Baby) async throws -> CKRecordZone.ID? {
        if let cachedZoneID = cachedSharedZoneID(for: baby.id) {
            return cachedZoneID
        }

        let zones = try await container.sharedCloudDatabase.allRecordZones()
        let discoveredZoneID = matchingSharedZoneID(for: baby.id, in: zones)
        if let discoveredZoneID {
            cacheSharedZoneID(discoveredZoneID, for: baby.id)
        }
        return discoveredZoneID
    }

    private func setSharedDatabaseScope(_ scope: SharedDatabaseScope, for baby: Baby) {
        sharedDatabaseScopes[baby.id.uuidString] = scope
        saveSharedDatabaseScopes()

        if scope == .privateOwner, baby.ownerName != nil {
            baby.ownerName = nil
        }
    }

    private func cachedSharedDatabaseScope(for babyID: UUID) -> SharedDatabaseScope? {
        sharedDatabaseScopes[babyID.uuidString]
    }

    private func clearSharedDatabaseScope(for babyID: UUID) {
        sharedDatabaseScopes.removeValue(forKey: babyID.uuidString)
        saveSharedDatabaseScopes()
    }

    private func clearResolvedShareContext(for babyID: UUID) {
        clearSharedZoneID(for: babyID)
        clearSharedDatabaseScope(for: babyID)
    }

    private func ownerZoneContextIfAvailable(for baby: Baby) async throws -> (zoneID: CKRecordZone.ID, database: CKDatabase)? {
        let privateZoneID = zoneID(for: baby.id)
        let recordName = baby.ckRecordName ?? baby.id.uuidString
        let recordID = CKRecord.ID(recordName: recordName, zoneID: privateZoneID)

        do {
            _ = try await container.privateCloudDatabase.record(for: recordID)
            return (privateZoneID, container.privateCloudDatabase)
        } catch let error as CKError where error.code == .unknownItem || error.code == .zoneNotFound {
            return nil
        }
    }

    private func resolveZoneContext(for baby: Baby) async throws -> (zoneID: CKRecordZone.ID, database: CKDatabase) {
        if let cachedScope = cachedSharedDatabaseScope(for: baby.id) {
            switch cachedScope {
            case .privateOwner:
                setSharedDatabaseScope(.privateOwner, for: baby)
                return (zoneID(for: baby.id), container.privateCloudDatabase)
            case .sharedParticipant:
                if let sharedZoneID = try await sharedZoneID(for: baby) {
                    return (sharedZoneID, container.sharedCloudDatabase)
                }
                clearSharedDatabaseScope(for: baby.id)
            }
        }

        if let privateContext = try await ownerZoneContextIfAvailable(for: baby) {
            setSharedDatabaseScope(.privateOwner, for: baby)
            return privateContext
        }

        if let sharedZoneID = try await sharedZoneID(for: baby) {
            setSharedDatabaseScope(.sharedParticipant, for: baby)
            return (sharedZoneID, container.sharedCloudDatabase)
        }

        throw SharingError.sharedZoneUnavailable
    }

    func isShareOwner(for baby: Baby) -> Bool {
        if let scope = cachedSharedDatabaseScope(for: baby.id) {
            return scope == .privateOwner
        }

        if activeShareBabyID == baby.id,
           let currentUserRole = activeShare?.currentUserParticipant?.role {
            return currentUserRole == .owner
        }

        let ownerName = baby.ownerName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return ownerName.isEmpty
    }

    private func updateActiveShare(_ share: CKShare?, for baby: Baby) {
        activeShare = share
        activeShareBabyID = share == nil ? nil : baby.id
        participants = share?.participants.filter { $0.role != .owner } ?? []
        if let share {
            cacheParticipantFirstNames(from: share)
        }
    }

    private func clearActiveShareIfNeeded(for baby: Baby) {
        guard activeShareBabyID == baby.id else { return }
        activeShare = nil
        activeShareBabyID = nil
        participants = []
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
                setSharedDatabaseScope(.privateOwner, for: baby)
                updateActiveShare(existingShare, for: baby)
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
            _ = try await saveRecords(childRecords, to: database)
        }

        // 6. Update local state
        baby.ckRecordName = babyRecord.recordID.recordName
        baby.isShared = true
        try? context.save()

        sharedBabyIDs.insert(baby.id)
        saveSharedBabyIDs()
        setSharedDatabaseScope(.privateOwner, for: baby)
        updateActiveShare(savedShare, for: baby)
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
            // An owner identity can exist with no discoverable name; an empty string would leave
            // baby.ownerName nil and make the owner's legacy entries read as the participant's own.
            let formattedOwner = metadata.ownerIdentity.nameComponents?.formatted()
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let ownerName = formattedOwner.isEmpty ? "Partner" : formattedOwner
            let (baby, childCount) = try importSharedRecords(records, ownerName: ownerName, in: context)

            cacheSharedZoneID(zoneID, for: baby.id)
            setSharedDatabaseScope(.sharedParticipant, for: baby)
            if let fetchedShare = try? await fetchShareRecordWithRetry(for: baby) {
                updateActiveShare(fetchedShare, for: baby)
            } else {
                updateActiveShare(metadata.share, for: baby)
            }
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
                    let (baby, _) = try importSharedRecords(records, ownerName: "Partner", in: context)
                    cacheSharedZoneID(zone.zoneID, for: baby.id)
                    setSharedDatabaseScope(.sharedParticipant, for: baby)
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

    private func fetchShareRecord(for baby: Baby) async throws -> CKShare? {
        let resolved = try await resolveZoneContext(for: baby)
        let recordName = baby.ckRecordName ?? baby.id.uuidString
        let recordID = CKRecord.ID(recordName: recordName, zoneID: resolved.zoneID)
        let record = try await resolved.database.record(for: recordID)

        guard let shareRef = record.share else {
            return nil
        }

        return try await resolved.database.record(for: shareRef.recordID) as? CKShare
    }

    private func fetchShareRecordWithRetry(
        for baby: Baby,
        maxAttempts: Int = 3
    ) async throws -> CKShare? {
        var lastError: Error?

        for attempt in 1...maxAttempts {
            do {
                if let share = try await fetchShareRecord(for: baby) {
                    return share
                }
            } catch {
                lastError = error
            }

            guard attempt < maxAttempts else { break }
            try? await Task.sleep(for: .milliseconds(450 * attempt))
        }

        if let lastError {
            throw lastError
        }

        return nil
    }

    /// CloudKit can lag a short time between share acceptance and record visibility.
    /// Retry briefly to avoid false "no baby found" errors on real devices.
    private func fetchAllRecordsWithRetry(in zoneID: CKRecordZone.ID, from database: CKDatabase) async throws -> [CKRecord] {
        let maxAttempts = 5
        var bestRecords: [CKRecord] = []
        var previousVisibleCount: Int?
        var stableSnapshotCount = 0
        
        for attempt in 1...maxAttempts {
            do {
                let records = try await fetchAllRecords(in: zoneID, from: database)

                if records.count > bestRecords.count {
                    bestRecords = records
                }

                let hasBaby = records.contains(where: { $0.recordType == Baby.ckRecordType })
                if hasBaby {
                    if let previousVisibleCount, previousVisibleCount == records.count {
                        stableSnapshotCount += 1
                    } else {
                        stableSnapshotCount = 0
                    }

                    previousVisibleCount = records.count

                    if stableSnapshotCount >= 1 || attempt == maxAttempts {
                        return bestRecords
                    }

                    logger.info("Shared zone snapshot still growing (attempt \(attempt), \(records.count) record(s)); retrying")
                } else if attempt == maxAttempts, bestRecords.contains(where: { $0.recordType == Baby.ckRecordType }) {
                    return bestRecords
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
        var changedRecords: [CKRecord] = []
        var deletedRecordIDs: [CKRecord.ID] = []
        var serverChangeToken = previousToken
        var moreComing = true

        while moreComing {
            let result = try await database.recordZoneChanges(
                inZoneWith: zoneID,
                since: serverChangeToken
            )

            for (_, modificationResult) in result.modificationResultsByID {
                switch modificationResult {
                case .success(let modification):
                    changedRecords.append(modification.record)
                case .failure(let error):
                    throw error
                }
            }

            deletedRecordIDs.append(contentsOf: result.deletions.map(\.recordID))
            serverChangeToken = result.changeToken
            moreComing = result.moreComing
        }

        return ZoneChangesBatch(
            changedRecords: changedRecords,
            deletedRecordIDs: deletedRecordIDs,
            serverChangeToken: serverChangeToken
        )
    }

    // MARK: - Sync Shared Records

    /// Fetches changes from the shared zone and applies them to SwiftData.
    func syncSharedRecords(for baby: Baby, in context: ModelContext) async throws {
        guard baby.isShared else { return }

        let resolved = try await resolveZoneContext(for: baby)
        do {
            let records = try await fetchAllRecordsWithRetry(in: resolved.zoneID, from: resolved.database)

            remoteImportDepth += 1
            defer { remoteImportDepth -= 1 }

            guard let babyRecord = records.first(where: { $0.recordType == Baby.ckRecordType }) else {
                throw SharingError.noBabyFound
            }

            baby.applyCKRecord(babyRecord)

            var remoteActivityIDs: Set<UUID> = []
            var remoteGrowthIDs: Set<UUID> = []
            var remoteHealthIDs: Set<UUID> = []
            var insertedEntries: [SharedEntryNotificationEvent] = []

            for record in records where record.recordType != Baby.ckRecordType {
                switch record.recordType {
                case Activity.ckRecordType:
                    let activityID = UUID(uuidString: record.recordID.recordName)

                    if let id = activityID {
                        remoteActivityIDs.insert(id)
                    }

                    if let id = activityID, isRecordDeleted(id) {
                        logger.info("Skipping deleted activity: \(id)")
                        break
                    }

                    if let existing = (baby.activities ?? []).first(where: { $0.id == activityID }) {
                        existing.applyCKRecord(record)
                    } else {
                        let activity = Activity(type: .note, startTime: Date(), baby: nil)
                        if let id = activityID { activity.id = id }
                        activity.applyCKRecord(record)
                        context.insert(activity)
                        activity.baby = baby
                        let authorFirstName = await authorFirstName(for: record, baby: baby)
                        insertedEntries.append(
                            SharedEntryNotificationEvent(
                                kind: .activity(activity.type),
                                authorFirstName: authorFirstName
                            )
                        )
                    }

                case GrowthRecord.ckRecordType:
                    let recordID = UUID(uuidString: record.recordID.recordName)

                    if let id = recordID {
                        remoteGrowthIDs.insert(id)
                    }

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
                        let authorFirstName = await authorFirstName(for: record, baby: baby)
                        insertedEntries.append(
                            SharedEntryNotificationEvent(
                                kind: .growth,
                                authorFirstName: authorFirstName
                            )
                        )
                    }

                case HealthRecord.ckRecordType:
                    let recordID = UUID(uuidString: record.recordID.recordName)

                    if let id = recordID {
                        remoteHealthIDs.insert(id)
                    }

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
                        let authorFirstName = await authorFirstName(for: record, baby: baby)
                        insertedEntries.append(
                            SharedEntryNotificationEvent(
                                kind: .health,
                                authorFirstName: authorFirstName
                            )
                        )
                    }

                default:
                    break
                }
            }

            for activity in baby.activities ?? [] {
                guard (activity.ckRecordName != nil || activity.ckChangeTag != nil),
                      !remoteActivityIDs.contains(activity.id) else {
                    continue
                }
                context.delete(activity)
            }

            for growth in baby.growthRecords ?? [] {
                guard (growth.ckRecordName != nil || growth.ckChangeTag != nil),
                      !remoteGrowthIDs.contains(growth.id) else {
                    continue
                }
                context.delete(growth)
            }

            for health in baby.healthRecords ?? [] {
                guard (health.ckRecordName != nil || health.ckChangeTag != nil),
                      !remoteHealthIDs.contains(health.id) else {
                    continue
                }
                context.delete(health)
            }

            try? context.save()

            if !insertedEntries.isEmpty {
                await NotificationManager.shared.scheduleSharedEntryNotification(
                    babyName: baby.displayName,
                    entries: insertedEntries
                )
            }

            logger.info("Synced full shared snapshot with \(records.count) record(s) for baby \(baby.displayName)")
        } catch let error as CKError where error.code == .zoneNotFound {
            clearResolvedShareContext(for: baby.id)
            throw SharingError.sharedZoneUnavailable
        }
    }

    // MARK: - Push Local Changes

    /// Pushes local SwiftData changes to the shared CloudKit zone.
    func pushLocalChanges(for baby: Baby, in context: ModelContext) async throws {
        guard baby.isShared else { return }

        let resolved = try await resolveZoneContext(for: baby)
        var records: [CKRecord] = []

        records.append(try await prepareRecordForSave(baby, in: resolved.zoneID, from: resolved.database))

        // Only push non-deleted records
        for activity in baby.activities ?? [] where !activity.isDeleted {
            records.append(try await prepareRecordForSave(activity, in: resolved.zoneID, from: resolved.database))
        }
        for growth in baby.growthRecords ?? [] where !growth.isDeleted {
            records.append(try await prepareRecordForSave(growth, in: resolved.zoneID, from: resolved.database))
        }
        for health in baby.healthRecords ?? [] where !health.isDeleted {
            records.append(try await prepareRecordForSave(health, in: resolved.zoneID, from: resolved.database))
        }

        guard !records.isEmpty else {
            logger.info("No records to push for baby \(baby.displayName)")
            return
        }

        // Mark that we're pushing (to avoid triggering sync on our own notification)
        lastPushDate = Date()
        
        do {
            let savedRecords = try await saveRecords(records, to: resolved.database)
            applySavedRecords(savedRecords, to: baby, in: context)
        } catch let error as CKError where error.code == .zoneNotFound {
            clearResolvedShareContext(for: baby.id)
            throw SharingError.sharedZoneUnavailable
        }
        logger.info("Pushed \(records.count) records for baby \(baby.displayName)")
    }
    
    private var lastPushDate: Date?
    
    /// Returns true if a local push just happened very recently.
    /// This stays short so we don't mask another parent's updates for too long.
    var didRecentlyPush: Bool {
        guard let lastPush = lastPushDate else { return false }
        return Date().timeIntervalSince(lastPush) < 4.0
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
        } catch let error as CKError where error.code == .zoneNotFound {
            clearResolvedShareContext(for: baby.id)
            throw SharingError.sharedZoneUnavailable
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
        let share: CKShare
        if activeShareBabyID == baby.id, let currentActiveShare = activeShare {
            share = currentActiveShare
        } else if let fetchedShare = try await fetchShareRecordWithRetry(for: baby) {
            share = fetchedShare
        } else {
            throw SharingError.shareCreationFailed
        }

        share.removeParticipant(participant)

        let resolved = try await resolveZoneContext(for: baby)
        let (savedResults, _) = try await resolved.database.modifyRecords(
            saving: [share],
            deleting: [],
            savePolicy: .changedKeys
        )

        // Update with the returned share
        for (_, result) in savedResults {
            if case .success(let record) = result, let updatedShare = record as? CKShare {
                updateActiveShare(updatedShare, for: baby)
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
        clearResolvedShareContext(for: baby.id)
        saveChangeToken(nil, for: zone)
        clearActiveShareIfNeeded(for: baby)
        sharingStatus = .none

        logger.info("Stopped sharing baby: \(baby.displayName)")
    }

    // MARK: - Fetch Share Info

    func fetchShareInfo(for baby: Baby) async {
        guard baby.isShared else {
            clearActiveShareIfNeeded(for: baby)
            return
        }

        do {
            if let share = try await fetchShareRecordWithRetry(for: baby) {
                updateActiveShare(share, for: baby)
                
                // Try to preserve any email mappings we can find
                for participant in participants {
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
            } else {
                clearActiveShareIfNeeded(for: baby)
            }
        } catch let error as CKError where error.code == .zoneNotFound {
            clearResolvedShareContext(for: baby.id)
            clearActiveShareIfNeeded(for: baby)
            logger.error("Failed to fetch share info: \(error.localizedDescription)")
        } catch {
            clearActiveShareIfNeeded(for: baby)
            logger.error("Failed to fetch share info: \(error.localizedDescription)")
        }
    }

    // MARK: - Subscriptions

    func setupSubscriptions() async throws {
        await ensureAccountStatusChecked()
        guard accountStatus == .available else { return }

        let sharedSubscription = CKDatabaseSubscription(subscriptionID: Self.sharedSubscriptionID)
        let privateSubscription = CKDatabaseSubscription(subscriptionID: Self.privateSubscriptionID)
        let notificationInfo = CKSubscription.NotificationInfo()
        notificationInfo.shouldSendContentAvailable = true
        sharedSubscription.notificationInfo = notificationInfo
        privateSubscription.notificationInfo = notificationInfo

        try await ensureSubscription(
            privateSubscription,
            in: container.privateCloudDatabase,
            label: "Private database"
        )
        try await ensureSubscription(
            sharedSubscription,
            in: container.sharedCloudDatabase,
            label: "Shared database"
        )
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
        if let refreshedShare = try? await fetchShareRecordWithRetry(for: baby) {
            updateActiveShare(refreshedShare, for: baby)
        } else {
            updateActiveShare(savedShare, for: baby)
        }
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

    private func prepareRecordForSave<T: CKRecordConvertible>(
        _ item: T,
        in zoneID: CKRecordZone.ID,
        from database: CKDatabase
    ) async throws -> CKRecord {
        let recordID = CKRecord.ID(recordName: item.id.uuidString, zoneID: zoneID)

        do {
            let existingRecord = try await database.record(for: recordID)
            item.updateCKRecord(existingRecord, in: zoneID)
            return existingRecord
        } catch let error as CKError where error.code == .unknownItem || error.code == .zoneNotFound {
            return item.toCKRecord(in: zoneID)
        }
    }

    private func applySavedRecords(_ savedRecords: [CKRecord], to baby: Baby, in context: ModelContext) {
        remoteImportDepth += 1
        defer { remoteImportDepth -= 1 }

        for record in savedRecords {
            switch record.recordType {
            case Baby.ckRecordType:
                baby.applyCKRecord(record)

            case Activity.ckRecordType:
                let recordID = UUID(uuidString: record.recordID.recordName)
                if let existing = (baby.activities ?? []).first(where: { $0.id == recordID }) {
                    existing.applyCKRecord(record)
                }

            case GrowthRecord.ckRecordType:
                let recordID = UUID(uuidString: record.recordID.recordName)
                if let existing = (baby.growthRecords ?? []).first(where: { $0.id == recordID }) {
                    existing.applyCKRecord(record)
                }

            case HealthRecord.ckRecordType:
                let recordID = UUID(uuidString: record.recordID.recordName)
                if let existing = (baby.healthRecords ?? []).first(where: { $0.id == recordID }) {
                    existing.applyCKRecord(record)
                }

            default:
                break
            }
        }

        try? context.save()
    }

    private func saveRecords(_ records: [CKRecord], to database: CKDatabase) async throws -> [CKRecord] {
        // Save in batches of 400 (CloudKit limit)
        let batchSize = 400
        var savedRecords: [CKRecord] = []
        for start in stride(from: 0, to: records.count, by: batchSize) {
            let end = min(start + batchSize, records.count)
            let batch = Array(records[start..<end])
            let (saveResults, _) = try await database.modifyRecords(saving: batch, deleting: [], savePolicy: .changedKeys)
            for (_, result) in saveResults {
                switch result {
                case .success(let record):
                    savedRecords.append(record)
                case .failure(let error):
                    throw error
                }
            }
        }
        return savedRecords
    }

    private func authorFirstName(for record: CKRecord, baby: Baby) async -> String? {
        let userRecordID = record.creatorUserRecordID ?? record.lastModifiedUserRecordID
        guard let userRecordID else { return nil }

        if let cachedName = cachedParticipantFirstName(for: userRecordID) {
            return cachedName
        }

        if activeShareBabyID == baby.id, let activeShare {
            cacheParticipantFirstNames(from: activeShare)
            if let cachedName = cachedParticipantFirstName(for: userRecordID) {
                return cachedName
            }
        }

        if let fetchedShare = try? await fetchShareRecordWithRetry(for: baby) {
            updateActiveShare(fetchedShare, for: baby)
            return cachedParticipantFirstName(for: userRecordID)
        }

        return nil
    }

    private func cacheParticipantFirstNames(from share: CKShare) {
        var hasChanges = false

        for participant in share.participants {
            guard let userRecordID = participant.userIdentity.userRecordID,
                  let firstName = participantFirstName(from: participant.userIdentity.nameComponents) else {
                continue
            }

            if participantFirstNames[userRecordID.recordName] != firstName {
                participantFirstNames[userRecordID.recordName] = firstName
                hasChanges = true
            }
        }

        if hasChanges {
            saveParticipantFirstNames()
        }
    }

    private func participantFirstName(from components: PersonNameComponents?) -> String? {
        if let givenName = components?.givenName?.trimmingCharacters(in: .whitespacesAndNewlines),
           !givenName.isEmpty {
            return givenName
        }

        guard let formattedName = components?.formatted().trimmingCharacters(in: .whitespacesAndNewlines),
              !formattedName.isEmpty else {
            return nil
        }

        return formattedName
            .split(whereSeparator: \.isWhitespace)
            .first
            .map(String.init)
    }

    private func cachedParticipantFirstName(for userRecordID: CKRecord.ID) -> String? {
        let cachedName = participantFirstNames[userRecordID.recordName]?.trimmingCharacters(in: .whitespacesAndNewlines)
        return cachedName?.isEmpty == false ? cachedName : nil
    }

    private func ensureSubscription(
        _ subscription: CKDatabaseSubscription,
        in database: CKDatabase,
        label: String
    ) async throws {
        let subscriptionID = subscription.subscriptionID

        do {
            _ = try await database.subscription(for: subscriptionID)
            logger.info("\(label) subscription already set up")
            return
        } catch let error as CKError where error.code == .unknownItem {
            // Missing subscription: create it below.
        }

        let (saveResults, _) = try await database.modifySubscriptions(
            saving: [subscription],
            deleting: []
        )

        switch saveResults[subscriptionID] {
        case .success:
            logger.info("\(label) subscription set up")
        case .failure(let error):
            if isDuplicateSubscriptionError(error) {
                logger.info("\(label) subscription already set up")
                return
            }
            throw error
        case .none:
            throw SharingError.syncFailed
        }
    }

    private func isDuplicateSubscriptionError(_ error: Error) -> Bool {
        guard let ckError = error as? CKError,
              ckError.code == .serverRejectedRequest else {
            return false
        }

        let description = ckError.localizedDescription.lowercased()
        return description.contains("already")
            || description.contains("duplicate")
            || description.contains("exists")
    }

    /// Fetches ALL records in a zone without requiring queryable indexes or pre-existing record types.
    private func fetchAllRecords(in zoneID: CKRecordZone.ID, from database: CKDatabase) async throws -> [CKRecord] {
        try await fetchZoneChanges(in: zoneID, from: database, since: nil).changedRecords
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

    private func loadSharedZoneBookmarks() {
        guard let data = UserDefaults.standard.data(forKey: "sharedZoneBookmarks"),
              let bookmarks = try? JSONDecoder().decode([String: SharedZoneBookmark].self, from: data) else {
            return
        }

        sharedZoneBookmarks = bookmarks
    }

    private func saveSharedZoneBookmarks() {
        if let data = try? JSONEncoder().encode(sharedZoneBookmarks) {
            UserDefaults.standard.set(data, forKey: "sharedZoneBookmarks")
        }
    }

    private func loadSharedDatabaseScopes() {
        guard let data = UserDefaults.standard.data(forKey: "sharedDatabaseScopes"),
              let scopes = try? JSONDecoder().decode([String: SharedDatabaseScope].self, from: data) else {
            return
        }

        sharedDatabaseScopes = scopes
    }

    private func saveSharedDatabaseScopes() {
        if let data = try? JSONEncoder().encode(sharedDatabaseScopes) {
            UserDefaults.standard.set(data, forKey: "sharedDatabaseScopes")
        }
    }

    private func loadParticipantFirstNames() {
        guard let data = UserDefaults.standard.data(forKey: "participantFirstNames"),
              let names = try? JSONDecoder().decode([String: String].self, from: data) else {
            return
        }

        participantFirstNames = names
    }

    private func saveParticipantFirstNames() {
        if let data = try? JSONEncoder().encode(participantFirstNames) {
            UserDefaults.standard.set(data, forKey: "participantFirstNames")
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
    case sharedZoneUnavailable

    var errorDescription: String? {
        switch self {
        case .noBabyFound: return String(localized: "share_error_no_baby")
        case .shareCreationFailed: return String(localized: "share_error_creation_failed")
        case .shareURLMissing: return String(localized: "share_error_url_missing")
        case .syncFailed: return String(localized: "share_error_sync_failed")
        case .participantNotFound: return String(localized: "share_error_participant_not_found")
        case .invalidEmail: return String(localized: "share_error_invalid_email")
        case .accountUnavailable: return "iCloud account is not available. Please sign in to iCloud in Settings."
        case .sharedZoneUnavailable: return "The shared profile is not ready yet. Please try again in a moment."
        }
    }
}
