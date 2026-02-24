import SwiftUI
import SwiftData
import CloudKit
import os.log

private let logger = Logger(subsystem: "com.leona.app", category: "App")

extension Notification.Name {
    static let didAcceptCloudKitShare = Notification.Name("didAcceptCloudKitShare")
    static let shouldPushLocalChanges = Notification.Name("shouldPushLocalChanges")
}

// MARK: - App Delegate for CloudKit Share Acceptance

class LeonaAppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        application.registerForRemoteNotifications()
        return true
    }

    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [String: Any]) async -> UIBackgroundFetchResult {
        let notification = CKNotification(fromRemoteNotificationDictionary: userInfo)
        if notification?.subscriptionID == SharingManager.sharedSubscriptionID {
            logger.info("Received shared data push notification")
            // Sync will be triggered via NSPersistentStoreRemoteChange or scenePhase
        }
        return .newData
    }

    func application(_ application: UIApplication, userDidAcceptCloudKitShareWith cloudKitShareMetadata: CKShare.Metadata) {
        logger.info("User accepted CloudKit share via delegate")
        // Store metadata immediately (no async dispatch — avoids race condition with processPendingShare)
        LeonaAppDelegate.pendingShareMetadata = cloudKitShareMetadata
        // Post notification so the app can process it right away
        NotificationCenter.default.post(name: .didAcceptCloudKitShare, object: cloudKitShareMetadata)
    }

    static var pendingShareMetadata: CKShare.Metadata?
}

// MARK: - Main App

@main
struct LeonaApp: App {
    @UIApplicationDelegateAdaptor(LeonaAppDelegate.self) var appDelegate

    @State private var settings = AppSettings.shared
    @State private var cloudKit = CloudKitManager.shared
    @State private var notifications = NotificationManager.shared
    @State private var sharing = SharingManager.shared
    @State private var shareAcceptError: String?

    @Environment(\.scenePhase) private var scenePhase

    var sharedModelContainer: ModelContainer = {
        logger.info("=== LEONA APP STARTING ===")
        do {
            let container = try ModelContainer.createLeonaContainer()
            logger.info("ModelContainer created successfully!")

            #if DEBUG
            // Populate demo data synchronously before UI renders (screenshot mode only)
            if DemoDataGenerator.isDemoMode {
                MainActor.assumeIsolated {
                    let context = ModelContext(container)
                    DemoDataGenerator.populate(context: context)
                    logger.info("Demo data populated")
                }
            }
            #endif

            return container
        } catch {
            logger.critical("ModelContainer FAILED: \(error.localizedDescription)")
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(settings)
                .environment(cloudKit)
                .environment(notifications)
                .environment(sharing)
                .tint(settings.accentColor.color)
                .onReceive(NotificationCenter.default.publisher(
                    for: .NSPersistentStoreRemoteChange
                )) { _ in
                    logger.info("iCloud sync: remote changes received")
                    cloudKit.markSynced()
                    // Auto-sync shared babies on remote change
                    triggerSharedSync()
                }
                .onOpenURL { url in
                    // Handle CloudKit share URLs
                    Task {
                        await handleShareURL(url)
                    }
                }
                .task {
                    // Set up sharing subscriptions
                    try? await sharing.setupSubscriptions()

                    // Schema init and cleanup are available via SharingManager
                    // but no longer run automatically at startup.
                }
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .active {
                        // Auto-sync when app becomes active
                        triggerSharedSync()
                        // Check for pending share acceptance
                        processPendingShare()
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: .didAcceptCloudKitShare)) { notification in
                    // Process share immediately when accepted via app delegate
                    if let metadata = notification.object as? CKShare.Metadata {
                        LeonaAppDelegate.pendingShareMetadata = nil
                        Task {
                            await acceptShareMetadata(metadata)
                        }
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: .shouldPushLocalChanges)) { _ in
                    // Push local changes immediately when critical updates happen
                    logger.info("Triggering immediate sync after local change")
                    triggerSharedSync()
                }
                .alert(
                    String(localized: "share_error_title"),
                    isPresented: Binding(
                        get: { shareAcceptError != nil },
                        set: { if !$0 { shareAcceptError = nil } }
                    )
                ) {
                    Button(String(localized: "ok")) { shareAcceptError = nil }
                } message: {
                    Text(shareAcceptError ?? "")
                }
        }
        .modelContainer(sharedModelContainer)
    }

    // MARK: - Sharing Helpers

    private func triggerSharedSync() {
        Task {
            let context = ModelContext(sharedModelContainer)
            await SyncEngine.shared.syncAllSharedBabies(context: context)
        }
    }

    private func handleShareURL(_ url: URL) async {
        do {
            logger.info("Handling share URL: \(url.absoluteString)")
            let metadata = try await CKContainer(identifier: "iCloud.com.leona.app")
                .shareMetadata(for: url)
            await acceptShareMetadata(metadata)
        } catch {
            logger.error("Failed to get share metadata from URL: \(error.localizedDescription)")
            await MainActor.run {
                shareAcceptError = error.localizedDescription
            }
        }
    }

    private func processPendingShare() {
        guard let metadata = LeonaAppDelegate.pendingShareMetadata else { return }
        LeonaAppDelegate.pendingShareMetadata = nil
        logger.info("Processing pending share from app delegate")

        Task {
            await acceptShareMetadata(metadata)
        }
    }

    /// Centralized share acceptance — used by URL handler, pending share processor, and delegate notification
    private func acceptShareMetadata(_ metadata: CKShare.Metadata) async {
        do {
            let context = ModelContext(sharedModelContainer)
            try await sharing.acceptShare(metadata: metadata, in: context)
            logger.info("Share accepted successfully")

            // Trigger a sync to ensure UI refreshes
            triggerSharedSync()
        } catch {
            logger.error("Failed to accept share: \(error.localizedDescription)")
            await MainActor.run {
                shareAcceptError = error.localizedDescription
            }
        }
    }
}
