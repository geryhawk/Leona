import Foundation
import CloudKit
import SwiftData
import SwiftUI

/// Manages iCloud sync status between devices on the same iCloud account
@MainActor
@Observable
final class CloudKitManager {
    static let shared = CloudKitManager()

    /// Whether CloudKit is enabled (requires iCloud entitlements + Developer Program)
    static let isCloudKitEnabled = true

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
        #if DEBUG
        // Screenshot runs have no iCloud account in the simulator; present sharing as ready.
        if DemoDataGenerator.isDemoMode {
            self.iCloudAvailable = true
            self.iCloudStatus = .available
            self.syncStatus = .synced
            return
        }
        #endif
        guard let container = container else {
            self.iCloudAvailable = false
            self.syncStatus = .offline
            return
        }
        do {
            let status = try await container.accountStatus()
            self.iCloudStatus = status
            self.iCloudAvailable = status == .available
            self.syncStatus = status == .available ? .synced : .offline
            // The user record name is the same on every device of this iCloud account; the
            // thread uses it to attribute entries to a person rather than to an install.
            if status == .available, let userID = try? await container.userRecordID() {
                AppSettings.shared.cloudUserID = userID.recordName
            }
        } catch {
            self.iCloudAvailable = false
            self.syncStatus = .error
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
