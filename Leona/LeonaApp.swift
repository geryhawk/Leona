import SwiftUI
import SwiftData

@main
struct LeonaApp: App {
    @State private var settings = AppSettings.shared
    @State private var cloudKit = CloudKitManager.shared
    @State private var notifications = NotificationManager.shared
    
    var sharedModelContainer: ModelContainer = {
        do {
            return try ModelContainer.createLeonaContainer()
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(settings)
                .environment(cloudKit)
                .environment(notifications)
        }
        .modelContainer(sharedModelContainer)
    }
}
