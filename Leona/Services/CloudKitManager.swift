import Foundation
import CloudKit
import SwiftData
import SwiftUI

/// Manages iCloud sync and sharing between parents
@Observable
final class CloudKitManager {
    static let shared = CloudKitManager()
    
    /// Whether CloudKit is enabled (requires iCloud entitlements + Developer Program)
    static let isCloudKitEnabled = true
    
    /// Dedicated zone for shareable baby records
    static let babyZoneName = "BabyZone"
    
    // CKContainer is thread-safe and lightweight; one shared instance
    @ObservationIgnored
    private let container: CKContainer? = {
        guard isCloudKitEnabled else { return nil }
        return CKContainer(identifier: "iCloud.com.leona.app")
    }()
    
    var iCloudAvailable = false
    var iCloudStatus: CKAccountStatus = .couldNotDetermine
    var syncStatus: SyncStatus = .idle
    var lastSyncDate: Date?
    
    enum SyncStatus: String {
        case idle
        case syncing
        case synced
        case error
        case offline
        
        var displayName: String {
            switch self {
            case .idle: return String(localized: "sync_idle")
            case .syncing: return String(localized: "sync_syncing")
            case .synced: return String(localized: "sync_synced")
            case .error: return String(localized: "sync_error")
            case .offline: return String(localized: "sync_offline")
            }
        }
        
        var icon: String {
            switch self {
            case .idle: return "icloud"
            case .syncing: return "arrow.triangle.2.circlepath.icloud"
            case .synced: return "checkmark.icloud"
            case .error: return "exclamationmark.icloud"
            case .offline: return "icloud.slash"
            }
        }
    }
    
    private init() {}
    
    // MARK: - Check iCloud Status
    
    func checkiCloudStatus() async {
        guard let container = container else {
            await MainActor.run {
                self.iCloudAvailable = false
                self.syncStatus = .offline
            }
            return
        }
        do {
            let status = try await container.accountStatus()
            await MainActor.run {
                self.iCloudStatus = status
                self.iCloudAvailable = status == .available
                if status != .available {
                    self.syncStatus = .offline
                }
            }
        } catch {
            await MainActor.run {
                self.iCloudAvailable = false
                self.syncStatus = .error
            }
        }
    }
    
    // MARK: - Generate Share Code
    
    func generateShareCode(for babyID: UUID) -> String {
        let code = String(babyID.uuidString.prefix(8)).uppercased()
        return code
    }
    
    // MARK: - Ensure Custom Zone Exists
    
    private func ensureZoneExists(in database: CKDatabase) async throws -> CKRecordZone.ID {
        let zoneID = CKRecordZone.ID(zoneName: Self.babyZoneName, ownerName: CKCurrentUserDefaultName)
        let zone = CKRecordZone(zoneID: zoneID)
        
        do {
            let results = try await database.modifyRecordZones(saving: [zone], deleting: [])
            if let result = results.saveResults[zoneID], case .failure(let error) = result {
                // Zone already exists is OK, other errors rethrow
                let ckError = error as? CKError
                if ckError?.code != .serverRejectedRequest {
                    throw error
                }
            }
        } catch {
            // If zone already exists, that's fine
            let ckError = error as? CKError
            if ckError?.code != .serverRejectedRequest {
                throw error
            }
        }
        
        return zoneID
    }
    
    // MARK: - Share Baby Profile
    
    func shareBabyProfile(baby: Baby) async throws -> CKShare {
        guard let container = container else {
            throw NSError(
                domain: "CloudKitManager",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: String(localized: "cloudkit_not_available")]
            )
        }
        
        let privateDB = container.privateCloudDatabase
        
        // Ensure the custom zone exists (CKShare requires a custom zone)
        let zoneID = try await ensureZoneExists(in: privateDB)
        
        // Create the baby record in the custom zone
        let recordID = CKRecord.ID(recordName: "baby-\(baby.id.uuidString)", zoneID: zoneID)
        let record = CKRecord(recordType: "Baby", recordID: recordID)
        record["firstName"] = baby.firstName as CKRecordValue
        record["lastName"] = baby.lastName as CKRecordValue
        record["dateOfBirth"] = baby.dateOfBirth as CKRecordValue
        record["gender"] = baby.gender.rawValue as CKRecordValue
        
        // Create share with public read/write
        let share = CKShare(rootRecord: record)
        share[CKShare.SystemFieldKey.title] = "\(baby.displayName)" as CKRecordValue
        share.publicPermission = .readWrite
        
        // Save and CAPTURE the returned share (it contains the server-generated URL)
        let results = try await privateDB.modifyRecords(
            saving: [record, share],
            deleting: [],
            savePolicy: .changedKeys
        )
        
        // Extract the saved share from results - this is the one with the URL
        if let shareResult = results.saveResults[share.recordID],
           case .success(let savedRecord) = shareResult,
           let savedShare = savedRecord as? CKShare,
           savedShare.url != nil {
            return savedShare
        }
        
        // If somehow the share didn't come back, try fetching it directly
        do {
            let fetchedRecord = try await privateDB.record(for: share.recordID)
            if let fetchedShare = fetchedRecord as? CKShare {
                return fetchedShare
            }
        } catch {
            // Fall through to return original share
        }
        
        return share
    }
    
    // MARK: - Fetch Share URL
    
    func getShareURL(for share: CKShare) -> URL? {
        return share.url
    }
    
    // MARK: - Accept Share
    
    func acceptShare(metadata: CKShare.Metadata) async throws {
        guard let container = container else { return }
        try await container.accept(metadata)
        await MainActor.run {
            self.syncStatus = .synced
        }
    }
    
    // MARK: - Sync Status Update
    
    func markSyncing() {
        syncStatus = .syncing
    }
    
    func markSynced() {
        syncStatus = .synced
        lastSyncDate = Date()
    }
    
    func markError() {
        syncStatus = .error
    }
}

// MARK: - SwiftData + CloudKit Configuration

extension ModelContainer {
    static func createLeonaContainer() throws -> ModelContainer {
        let schema = Schema([
            Baby.self,
            Activity.self,
            GrowthRecord.self,
            HealthRecord.self
        ])
        
        let useCloud = AppSettings.shared.iCloudSyncEnabled
        
        if useCloud {
            // Try CloudKit first, fall back to local-only
            do {
                let cloudConfig = ModelConfiguration(
                    schema: schema,
                    isStoredInMemoryOnly: false,
                    allowsSave: true,
                    groupContainer: .automatic,
                    cloudKitDatabase: .automatic
                )
                return try ModelContainer(for: schema, configurations: [cloudConfig])
            } catch {
                let localConfig = ModelConfiguration(
                    schema: schema,
                    isStoredInMemoryOnly: false,
                    allowsSave: true,
                    cloudKitDatabase: .none
                )
                return try ModelContainer(for: schema, configurations: [localConfig])
            }
        } else {
            let localConfig = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                allowsSave: true,
                cloudKitDatabase: .none
            )
            return try ModelContainer(for: schema, configurations: [localConfig])
        }
    }
}
