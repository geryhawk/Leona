import Foundation
import CloudKit
import SwiftData
import os.log

private let logger = Logger(subsystem: "com.leona.app", category: "SyncEngine")

/// Handles automatic bidirectional sync for shared baby data.
/// Runs on app foreground, on push notifications, and periodically.
actor SyncEngine {
    static let shared = SyncEngine()

    private var isSyncing = false
    private var lastSyncDate: Date?

    // MARK: - Automatic Sync

    /// Called when the app becomes active — syncs all shared babies.
    func syncOnAppActive(context: ModelContext) async {
        await syncAllSharedBabies(context: context)
    }

    /// Called when a remote notification arrives for shared data.
    func syncOnRemoteNotification(context: ModelContext) async {
        await syncAllSharedBabies(context: context)
    }

    /// Syncs all shared babies (both pull and push).
    func syncAllSharedBabies(context: ModelContext) async {
        guard !isSyncing else {
            logger.info("Sync already in progress, skipping")
            return
        }

        isSyncing = true
        defer { isSyncing = false }

        let sharing = SharingManager.shared

        do {
            // Fetch all babies that are shared
            let descriptor = FetchDescriptor<Baby>(predicate: #Predicate { $0.isShared == true })
            let sharedBabies = try context.fetch(descriptor)

            for baby in sharedBabies {
                do {
                    // Pull remote changes
                    try await sharing.syncSharedRecords(for: baby, in: context)

                    // Push local changes (only if we're the owner)
                    if baby.ownerName == nil {
                        try await sharing.pushLocalChanges(for: baby)
                    }
                } catch {
                    logger.error("Sync failed for baby \(baby.displayName): \(error.localizedDescription)")
                }
            }

            lastSyncDate = Date()
            logger.info("Automatic sync completed for \(sharedBabies.count) shared babies")
        } catch {
            logger.error("Failed to fetch shared babies: \(error.localizedDescription)")
        }
    }

    /// Push changes for a specific baby after local modifications.
    func pushAfterLocalChange(baby: Baby, context: ModelContext) async {
        guard baby.isShared else { return }

        do {
            try await SharingManager.shared.pushLocalChanges(for: baby)
            logger.info("Auto-pushed changes for \(baby.displayName)")
        } catch {
            logger.error("Auto-push failed for \(baby.displayName): \(error.localizedDescription)")
        }
    }
}
