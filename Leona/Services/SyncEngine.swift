import Foundation
import CloudKit
import SwiftData
import os.log

private let logger = Logger(subsystem: "com.leona.app", category: "SyncEngine")

/// Handles automatic bidirectional sync for shared baby data.
actor SyncEngine {
    static let shared = SyncEngine()

    private var isSyncing = false
    private var lastSyncDate: Date?

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
            let descriptor = FetchDescriptor<Baby>(predicate: #Predicate { $0.isShared == true })
            let sharedBabies = try context.fetch(descriptor)

            for baby in sharedBabies {
                do {
                    // First pull remote changes
                    try await sharing.syncSharedRecords(for: baby, in: context)

                    // Then push local changes (both owner and participants can push)
                    try await sharing.pushLocalChanges(for: baby)
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
}
