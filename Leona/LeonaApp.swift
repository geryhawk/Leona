import SwiftUI
import SwiftData
import CloudKit
import os.log

private let logger = Logger(subsystem: "com.leona.app", category: "App")
private var lastAcceptedShareRecordName: String?
private var lastAcceptedShareDate: Date?

@MainActor
private func enqueueAcceptedShareMetadata(_ metadata: CKShare.Metadata, source: String) {
    let shareRecordName = metadata.share.recordID.recordName
    let now = Date()
    
    // Some iOS paths can report the same acceptance twice (app + scene delegate).
    // Deduplicate close duplicates to avoid double import/error noise.
    if lastAcceptedShareRecordName == shareRecordName,
       let lastDate = lastAcceptedShareDate,
       now.timeIntervalSince(lastDate) < 5.0 {
        logger.info("Ignoring duplicate share acceptance from \(source)")
        return
    }
    
    lastAcceptedShareRecordName = shareRecordName
    lastAcceptedShareDate = now
    LeonaAppDelegate.pendingShareMetadata = metadata
    logger.info("Queued accepted CloudKit share from \(source)")
    NotificationCenter.default.post(name: .didAcceptCloudKitShare, object: metadata)
}

extension Notification.Name {
    static let didAcceptCloudKitShare = Notification.Name("didAcceptCloudKitShare")
    static let shouldPushLocalChanges = Notification.Name("shouldPushLocalChanges")
}

// MARK: - App Delegate for CloudKit Share Acceptance

class LeonaSceneDelegate: NSObject, UIWindowSceneDelegate {
    func windowScene(_ windowScene: UIWindowScene, userDidAcceptCloudKitShareWith cloudKitShareMetadata: CKShare.Metadata) {
        Task { @MainActor in
            enqueueAcceptedShareMetadata(cloudKitShareMetadata, source: "scene delegate")
        }
    }
}

class LeonaAppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        application.registerForRemoteNotifications()
        // Allow scroll to pass through buttons without delay
        UIScrollView.appearance().delaysContentTouches = false
        return true
    }
    
    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
        configuration.delegateClass = LeonaSceneDelegate.self
        return configuration
    }

    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        let notification = CKNotification(fromRemoteNotificationDictionary: userInfo)
        if notification?.subscriptionID == SharingManager.sharedSubscriptionID {
            logger.info("Received shared data push notification")
        }
        completionHandler(.newData)
    }

    func application(_ application: UIApplication, userDidAcceptCloudKitShareWith cloudKitShareMetadata: CKShare.Metadata) {
        Task { @MainActor in
            enqueueAcceptedShareMetadata(cloudKitShareMetadata, source: "application delegate")
        }
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
    @State private var acceptingShareIDs: Set<String> = []

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
                ).receive(on: DispatchQueue.main)) { _ in
                    logger.info("iCloud sync: remote changes received")
                    cloudKit.markSynced()
                    
                    // Don't sync if we just pushed (avoid sync loop)
                    guard !sharing.didRecentlyPush else {
                        logger.info("Skipping sync (we just pushed changes)")
                        return
                    }
                    
                    // Auto-sync shared babies on remote change (debounced)
                    triggerSharedSync()
                }
                .onOpenURL { url in
                    // Handle CloudKit share URLs
                    Task {
                        await handleShareURL(url)
                    }
                }
                .task {
                    // IMPORTANT: Check account status FIRST to warm up CloudKit cache
                    // This prevents "Could not validate account info cache" warnings
                    await sharing.ensureAccountStatusChecked()
                    
                    // Set up sharing subscriptions
                    try? await sharing.setupSubscriptions()
                    
                    // Recovery path: import accepted shares that may have been missed by delegate callbacks.
                    let context = ModelContext(sharedModelContainer)
                    await sharing.recoverAcceptedSharesIfNeeded(in: context)

                    // Schema init and cleanup are available via SharingManager
                    // but no longer run automatically at startup.
                }
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .active {
                        // Auto-sync when app becomes active
                        triggerSharedSync()
                        // Check for pending share acceptance
                        processPendingShare()
                        // Recovery path for missed invitation callbacks
                        recoverAcceptedSharesIfNeeded()
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
        Task { @MainActor in
            let context = ModelContext(sharedModelContainer)
            SyncEngine.shared.triggerDebouncedSync(context: context)
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
    
    private func recoverAcceptedSharesIfNeeded() {
        Task { @MainActor in
            let context = ModelContext(sharedModelContainer)
            await sharing.recoverAcceptedSharesIfNeeded(in: context)
        }
    }

    /// Centralized share acceptance — used by URL handler, pending share processor, and delegate notification
    @MainActor
    private func acceptShareMetadata(_ metadata: CKShare.Metadata) async {
        let shareID = metadata.share.recordID.recordName
        guard !acceptingShareIDs.contains(shareID) else {
            logger.info("Share \(shareID) is already being accepted, skipping duplicate request")
            return
        }
        acceptingShareIDs.insert(shareID)
        defer { acceptingShareIDs.remove(shareID) }
        
        do {
            let context = ModelContext(sharedModelContainer)
            try await sharing.acceptShare(metadata: metadata, in: context)
            logger.info("Share accepted successfully")

            // Trigger a sync to ensure UI refreshes
            triggerSharedSync()
        } catch {
            logger.error("Failed to accept share: \(error.localizedDescription)")
            shareAcceptError = error.localizedDescription
        }
    }
}
