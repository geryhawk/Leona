import SwiftUI
import SwiftData
import CoreData
import os.log

private let logger = Logger(subsystem: "com.leona.app", category: "App")

@main
struct LeonaApp: App {
    @State private var settings = AppSettings.shared
    @State private var cloudKit = CloudKitManager.shared
    @State private var notifications = NotificationManager.shared
    @State private var containerError: String?
    
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
                .tint(settings.accentColor.color)
                .onReceive(NotificationCenter.default.publisher(
                    for: .NSPersistentStoreRemoteChange
                )) { _ in
                    logger.info("iCloud sync: remote changes received")
                    cloudKit.markSynced()
                }
        }
        .modelContainer(sharedModelContainer)
    }
    
    @ViewBuilder
    private var contentWithLocale: some View {
        // Only language forces a view rebuild (necessary for String(localized:) cache)
        // Theme and accent color changes propagate via @Observable without rebuild
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
}
