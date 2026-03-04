import Foundation
import CloudKit
import SwiftData
import os.log

private let logger = Logger(subsystem: "com.leona.app", category: "SyncEngine")

/// Handles automatic bidirectional sync for shared baby data.
/// Uses @MainActor to ensure SwiftData context operations happen on the main thread,
/// preventing "Publishing changes from background threads" warnings.
@MainActor
final class SyncEngine {
    static let shared = SyncEngine()

    private var isSyncing = false
    private var lastSyncDate: Date?
    private var pendingSyncTask: Task<Void, Never>?
    private var syncDebounceCount = 0
    
    private let minSyncInterval: TimeInterval = 5.0 // Minimum 5 seconds between syncs (increased from 2)
    private let maxSyncDebounceCount = 3 // Stop syncing after 3 rapid-fire attempts

    /// Syncs all shared babies (both pull and push).
    func syncAllSharedBabies(context: ModelContext) async {
        guard !isSyncing else {
            logger.info("Sync already in progress, skipping")
            return
        }
        
        // Debouncing: Don't sync too frequently
        if let lastSync = lastSyncDate {
            let timeSinceLastSync = Date().timeIntervalSince(lastSync)
            if timeSinceLastSync < minSyncInterval {
                syncDebounceCount += 1
                if syncDebounceCount >= maxSyncDebounceCount {
                    logger.warning("Sync storm detected! Stopping sync for 30 seconds to prevent infinite loop")
                    // Wait 30 seconds before allowing syncs again
                    try? await Task.sleep(for: .seconds(30))
                    syncDebounceCount = 0
                    lastSyncDate = Date()
                    return
                }
                logger.info("Sync debounced (too soon after last sync: \(String(format: "%.1f", timeSinceLastSync))s ago)")
                return
            } else {
                // Reset counter if enough time has passed
                syncDebounceCount = 0
            }
        }

        isSyncing = true
        defer { isSyncing = false }

        let sharing = SharingManager.shared

        // Ensure CloudKit account is ready before any operations
        await sharing.ensureAccountStatusChecked()
        guard sharing.accountStatus == .available else {
            logger.info("iCloud account not available, skipping sync")
            lastSyncDate = Date()
            return
        }

        do {
            let descriptor = FetchDescriptor<Baby>(predicate: #Predicate { $0.isShared == true })
            let sharedBabies = try context.fetch(descriptor)
            
            guard !sharedBabies.isEmpty else {
                logger.info("No shared babies to sync")
                lastSyncDate = Date()
                return
            }

            for baby in sharedBabies {
                do {
                    // First pull remote changes
                    try await sharing.syncSharedRecords(for: baby, in: context)

                    // Then push local changes (both owner and participants can push)
                    try await sharing.pushLocalChanges(for: baby)
                } catch {
                    logger.error("Sync failed for baby \(baby.displayName): \(error.localizedDescription)")
                    // Don't throw - continue with other babies
                }
            }

            lastSyncDate = Date()
            logger.info("Automatic sync completed for \(sharedBabies.count) shared babies")
        } catch {
            logger.error("Failed to fetch shared babies: \(error.localizedDescription)")
            lastSyncDate = Date() // Still update to prevent rapid retries
        }
    }
    
    /// Triggers a debounced sync (waits 2 seconds before actually syncing to batch multiple changes)
    func triggerDebouncedSync(context: ModelContext) {
        // Cancel any pending sync
        pendingSyncTask?.cancel()
        
        // Schedule a new sync after a longer delay to batch changes
        pendingSyncTask = Task {
            try? await Task.sleep(for: .seconds(2)) // Increased from 1 second
            
            guard !Task.isCancelled else { return }
            await syncAllSharedBabies(context: context)
        }
    }
}
