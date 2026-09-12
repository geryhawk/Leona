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
    /// True while a debounced full sync (with push) is queued and has not run yet.
    private var pushPending = false
    private var syncDebounceCount = 0
    private var cooldownUntil: Date?
    
    private let minSyncInterval: TimeInterval = 1.5
    private let debounceDelay: TimeInterval = 0.75
    private let maxSyncDebounceCount = 5
    private let syncStormCooldown: TimeInterval = 6.0

    /// Syncs all shared babies (both pull and push).
    func syncAllSharedBabies(context: ModelContext) async {
        await runSync(context: context, force: false, pushLocalChanges: true)
    }

    /// Forces an immediate refresh for shared babies: pull-only, unless a debounced push was
    /// queued, in which case the queued push rides along instead of being dropped.
    /// Used for remote push handling and pull-to-refresh gestures.
    func forcePullSharedBabies(context: ModelContext) async {
        let carryPush = pushPending
        pushPending = false
        pendingSyncTask?.cancel()
        pendingSyncTask = nil
        await waitForCurrentSyncIfNeeded()
        await runSync(context: context, force: true, pushLocalChanges: carryPush)
    }

    private func waitForCurrentSyncIfNeeded() async {
        while isSyncing {
            try? await Task.sleep(for: .milliseconds(150))
        }
    }

    private func runSync(
        context: ModelContext,
        force: Bool,
        pushLocalChanges: Bool
    ) async {
        if force {
            syncDebounceCount = 0
            cooldownUntil = nil
        } else {
            if let cooldownUntil, Date() < cooldownUntil {
                logger.info("Sync cooling down until \(cooldownUntil.formatted())")
                return
            }

            if let lastSync = lastSyncDate {
                let timeSinceLastSync = Date().timeIntervalSince(lastSync)
                if timeSinceLastSync < minSyncInterval {
                    syncDebounceCount += 1
                    if syncDebounceCount >= maxSyncDebounceCount {
                        logger.warning("Sync storm detected, cooling down briefly")
                        cooldownUntil = Date().addingTimeInterval(syncStormCooldown)
                        syncDebounceCount = 0
                    }
                    logger.info("Sync debounced (too soon after last sync: \(String(format: "%.1f", timeSinceLastSync))s ago)")
                    return
                }

                syncDebounceCount = 0
            }
        }

        guard !isSyncing else {
            logger.info("Sync already in progress, skipping")
            return
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
                    try await sharing.syncSharedRecords(for: baby, in: context)

                    if pushLocalChanges {
                        try await sharing.pushLocalChanges(for: baby, in: context)
                    }
                } catch {
                    logger.error("Sync failed for baby \(baby.displayName): \(error.localizedDescription)")
                    // Don't throw - continue with other babies
                }
            }

            lastSyncDate = Date()
            let syncMode = pushLocalChanges ? "full sync" : "pull refresh"
            logger.info("Shared \(syncMode) completed for \(sharedBabies.count) babies")
        } catch {
            logger.error("Failed to fetch shared babies: \(error.localizedDescription)")
            lastSyncDate = Date() // Still update to prevent rapid retries
        }
    }
    
    /// Triggers a debounced sync to batch nearby local changes.
    func triggerDebouncedSync(context: ModelContext) {
        pendingSyncTask?.cancel()
        pushPending = true

        pendingSyncTask = Task {
            try? await Task.sleep(for: .milliseconds(Int(debounceDelay * 1000)))
            guard !Task.isCancelled else { return }
            pushPending = false
            await syncAllSharedBabies(context: context)
        }
    }
}
