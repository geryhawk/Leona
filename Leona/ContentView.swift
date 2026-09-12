import SwiftUI
import SwiftData

// MARK: - Navigation model shared by every screen

enum InsightsTab: String, Hashable {
    case trends, growth, health
}

enum Route: Hashable {
    case insights(InsightsTab)
    case profile
    case sharing
    case search
    case record(UUID)
}

enum LiveSession: String, Identifiable {
    case sleep, breastfeeding
    var id: String { rawValue }
}

/// One object drives the stack, the full-screen sessions and the toast.
@Observable
final class ThreadNavigator {
    var path: [Route] = []
    var session: LiveSession?
    var toast: String?
    var showWelcomeForNewBaby = false

    @ObservationIgnored private var toastTask: Task<Void, Never>?

    func go(_ route: Route) { path.append(route) }
    func backToThread() { path.removeAll() }
    func open(_ session: LiveSession) { self.session = session }

    func flash(_ message: String) {
        toastTask?.cancel()
        toast = message
        toastTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(2.3))
            guard !Task.isCancelled else { return }
            toast = nil
        }
    }
}

// MARK: - Root

struct ContentView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(CloudKitManager.self) private var cloudKit
    @Environment(NotificationManager.self) private var notifications
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase

    @Query(sort: \Baby.createdAt) private var babies: [Baby]

    @State private var navigator = ThreadNavigator()
    @State private var themeTick = 0

    /// Resolved active baby: settings is @Observable, so reading it here is enough to re-render.
    private var activeBaby: Baby? {
        if let id = settings.activeBabyID,
           let uuid = UUID(uuidString: id),
           let baby = babies.first(where: { $0.id == uuid }) {
            return baby
        }
        return babies.first
    }

    var body: some View {
        Group {
            if babies.isEmpty {
                WelcomeView(isAdditionalBaby: false)
            } else if let baby = activeBaby {
                NavigationStack(path: $navigator.path) {
                    ThreadView(baby: baby)
                        .navigationDestination(for: Route.self) { route in
                            destination(for: route, baby: baby)
                        }
                }
                .id(baby.id)
                .animation(.easeInOut(duration: 0.2), value: settings.activeBabyID)
                .fullScreenCover(item: $navigator.session) { session in
                    switch session {
                    case .sleep: SleepSessionView(baby: baby)
                    case .breastfeeding: BreastfeedSessionView(baby: baby)
                    }
                }
                .fullScreenCover(isPresented: $navigator.showWelcomeForNewBaby) {
                    WelcomeView(isAdditionalBaby: true)
                }
            } else {
                ContentUnavailableView(
                    String(localized: "no_baby_selected"),
                    systemImage: "person.crop.circle.badge.plus",
                    description: Text(String(localized: "add_baby_prompt"))
                )
            }
        }
        .environment(navigator)
        .leonaToast($navigator.toast)
        .tint(.vermilion)
        .preferredColorScheme(resolvedScheme)
        .onAppear {
            setupApp()
            #if DEBUG
            applyDemoRoute()
            #endif
        }
        .onChange(of: babies.count) { _, _ in syncActiveBabyID() }
        .onChange(of: settings.activeBabyID) { _, _ in navigator.backToThread() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { themeTick += 1 }
        }
    }

    private var resolvedScheme: ColorScheme? {
        _ = themeTick
        return settings.resolvedColorScheme
    }

    @ViewBuilder
    private func destination(for route: Route, baby: Baby) -> some View {
        switch route {
        case .insights(let tab):
            InsightsHubView(baby: baby, initialTab: tab)
        case .profile:
            ProfileView(baby: baby)
        case .sharing:
            SharingView(baby: baby)
        case .search:
            SearchView(baby: baby)
        case .record(let id):
            if let activity = fetchActivity(id) {
                RecordDetailView(activity: activity)
            } else {
                ContentUnavailableView(String(localized: "record_missing"), systemImage: "tray")
                    .leonaScreen()
            }
        }
    }

    /// One record by id, fetched on demand so the root view does not observe the whole Activity table.
    private func fetchActivity(_ id: UUID) -> Activity? {
        let descriptor = FetchDescriptor<Activity>(predicate: #Predicate { $0.id == id })
        return (try? modelContext.fetch(descriptor))?.first { !$0.isDeleted }
    }

    // MARK: - Demo / screenshot routing

    #if DEBUG
    private func applyDemoRoute() {
        guard DemoDataGenerator.isDemoMode, let screen = DemoDataGenerator.requestedScreen else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            switch screen {
            case .onboarding, .dashboard, .forecast:
                break
            case .sleep:
                navigator.open(.sleep)
            case .stats:
                navigator.go(.insights(.trends))
            case .growth:
                navigator.go(.insights(.growth))
            case .health:
                navigator.go(.insights(.health))
            case .sharing:
                navigator.go(.sharing)
            case .settings:
                navigator.go(.profile)
            }
        }
    }
    #endif

    // MARK: - Setup

    private func setupApp() {
        Task {
            await cloudKit.checkiCloudStatus()
            adoptCloudIdentity()
        }
        Task {
            await notifications.checkAuthorization()
            notifications.setupNotificationCategories()
        }
        syncActiveBabyID()
    }

    /// Repairs a stored active-baby id that no longer matches any baby.
    private func syncActiveBabyID() {
        if let id = settings.activeBabyID,
           let uuid = UUID(uuidString: id),
           babies.contains(where: { $0.id == uuid }) {
            return
        }
        settings.activeBabyID = babies.first?.id.uuidString
    }

    /// Once the iCloud user is known, re-stamp the entries this install authored with that
    /// identity so the same person's other devices attribute them correctly.
    private func adoptCloudIdentity() {
        guard let cloudID = settings.cloudUserID, cloudID != settings.adoptedCloudUserID else { return }
        let installID = settings.authorID
        let previous = settings.adoptedCloudUserID ?? installID
        let descriptor = FetchDescriptor<Activity>(
            predicate: #Predicate { $0.authorID == installID || $0.authorID == previous }
        )
        if let mine = try? modelContext.fetch(descriptor), !mine.isEmpty {
            for activity in mine { activity.authorID = cloudID }
            try? modelContext.save()
        }
        settings.adoptedCloudUserID = cloudID
    }
}
