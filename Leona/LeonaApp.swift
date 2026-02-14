import SwiftUI
import SwiftData
import CloudKit
import os.log

private let logger = Logger(subsystem: "com.leona.app", category: "App")

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
        Task { @MainActor in
            logger.info("User accepted CloudKit share")
            // Store metadata for processing once the container is ready
            LeonaAppDelegate.pendingShareMetadata = cloudKitShareMetadata
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
    @State private var containerError: String?

    @Environment(\.scenePhase) private var scenePhase

    var sharedModelContainer: ModelContainer = {
        logger.info("=== LEONA APP STARTING ===")
        do {
            let container = try ModelContainer.createLeonaContainer()
            logger.info("ModelContainer created successfully!")
            return container
        } catch {
            logger.critical("ModelContainer FAILED: \(error.localizedDescription)")
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            contentWithLocale
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
                }
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .active {
                        // Auto-sync when app becomes active
                        triggerSharedSync()
                        // Check for pending share acceptance
                        processPendingShare()
                    }
                }
        }
        .modelContainer(sharedModelContainer)
    }

    @ViewBuilder
    private var contentWithLocale: some View {
        let langID = "lang-\(settings.language.rawValue)"
        if let locale = settings.language.locale {
            ContentView()
                .environment(\.locale, locale)
                .id(langID)
        } else {
            ContentView()
                .id(langID)
        }
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
            let metadata = try await CKContainer(identifier: "iCloud.com.leona.app")
                .shareMetadata(for: url)
            let context = ModelContext(sharedModelContainer)
            try await sharing.acceptShare(metadata: metadata, in: context)
            logger.info("Share accepted via URL")
        } catch {
            logger.error("Failed to handle share URL: \(error.localizedDescription)")
        }
    }

    private func processPendingShare() {
        guard let metadata = LeonaAppDelegate.pendingShareMetadata else { return }
        LeonaAppDelegate.pendingShareMetadata = nil

        Task {
            let context = ModelContext(sharedModelContainer)
            try? await sharing.acceptShare(metadata: metadata, in: context)
        }
    }
}
