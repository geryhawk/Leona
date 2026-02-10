import Foundation
import CloudKit
import SwiftData
import SwiftUI

/// Manages iCloud sync and sharing between parents
@Observable
final class CloudKitManager {
    static let shared = CloudKitManager()
    
    private let container = CKContainer(identifier: "iCloud.com.leona.app")
    
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
    
    // MARK: - Share Baby Profile
    
    func shareBabyProfile(baby: Baby) async throws -> CKShare {
        let privateDB = container.privateCloudDatabase
        
        let recordID = CKRecord.ID(recordName: baby.id.uuidString)
        let record = CKRecord(recordType: "Baby", recordID: recordID)
        record["firstName"] = baby.firstName as CKRecordValue
        record["lastName"] = baby.lastName as CKRecordValue
        record["dateOfBirth"] = baby.dateOfBirth as CKRecordValue
        record["gender"] = baby.gender.rawValue as CKRecordValue
        
        let share = CKShare(rootRecord: record)
        share[CKShare.SystemFieldKey.title] = "\(baby.displayName)'s Profile" as CKRecordValue
        share.publicPermission = .readWrite
        
        try await privateDB.modifyRecords(saving: [record, share], deleting: [])
        
        return share
    }
    
    // MARK: - Fetch Share URL
    
    func getShareURL(for share: CKShare) -> URL? {
        return share.url
    }
    
    // MARK: - Accept Share
    
    func acceptShare(metadata: CKShare.Metadata) async throws {
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
        
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            allowsSave: true,
            groupContainer: .automatic,
            cloudKitDatabase: .automatic
        )
        
        return try ModelContainer(
            for: schema,
            configurations: [modelConfiguration]
        )
    }
}
