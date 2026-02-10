import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(CloudKitManager.self) private var cloudKit
    @Environment(NotificationManager.self) private var notifications
    @Environment(\.modelContext) private var modelContext
    
    @Query(sort: \Baby.createdAt) private var babies: [Baby]
    
    @State private var selectedTab: Tab = .dashboard
    @State private var showOnboarding = false
    @State private var activeBaby: Baby?
    
    enum Tab: String, CaseIterable {
        case dashboard
        case stats
        case growth
        case health
        case settings
        
        var title: String {
            switch self {
            case .dashboard: return String(localized: "tab_dashboard")
            case .stats: return String(localized: "tab_stats")
            case .growth: return String(localized: "tab_growth")
            case .health: return String(localized: "tab_health")
            case .settings: return String(localized: "tab_settings")
            }
        }
        
        var icon: String {
            switch self {
            case .dashboard: return "house.fill"
            case .stats: return "chart.bar.fill"
            case .growth: return "chart.line.uptrend.xyaxis"
            case .health: return "heart.text.clipboard.fill"
            case .settings: return "gearshape.fill"
            }
        }
    }
    
    var body: some View {
        Group {
            if !settings.hasCompletedOnboarding || babies.isEmpty {
                OnboardingView()
            } else {
                mainTabView
            }
        }
        .onAppear {
            setupApp()
        }
        .onChange(of: babies) { _, newBabies in
            updateActiveBaby(from: newBabies)
        }
        .preferredColorScheme(settings.colorScheme.colorScheme)
    }
    
    // MARK: - Main Tab View
    
    private var mainTabView: some View {
        TabView(selection: $selectedTab) {
            ForEach(Tab.allCases, id: \.rawValue) { tab in
                tabContent(for: tab)
                    .tabItem {
                        Label(tab.title, systemImage: tab.icon)
                    }
                    .tag(tab)
            }
        }
        .tint(.leonaPink)
    }
    
    @ViewBuilder
    private func tabContent(for tab: Tab) -> some View {
        if let baby = activeBaby {
            switch tab {
            case .dashboard:
                DashboardView(baby: baby)
            case .stats:
                StatsView(baby: baby)
            case .growth:
                GrowthView(baby: baby)
            case .health:
                HealthView(baby: baby)
            case .settings:
                SettingsView(baby: baby)
            }
        } else {
            ContentUnavailableView(
                String(localized: "no_baby_selected"),
                systemImage: "person.crop.circle.badge.plus",
                description: Text(String(localized: "add_baby_prompt"))
            )
        }
    }
    
    // MARK: - Setup
    
    private func setupApp() {
        // Check iCloud status
        Task {
            await cloudKit.checkiCloudStatus()
        }
        
        // Setup notifications
        Task {
            await notifications.checkAuthorization()
            notifications.setupNotificationCategories()
        }
        
        // Set active baby
        updateActiveBaby(from: babies)
    }
    
    private func updateActiveBaby(from babyList: [Baby]) {
        if let savedID = settings.activeBabyID,
           let uuid = UUID(uuidString: savedID),
           let baby = babyList.first(where: { $0.id == uuid }) {
            activeBaby = baby
        } else {
            activeBaby = babyList.first
            if let baby = activeBaby {
                settings.activeBabyID = baby.id.uuidString
            }
        }
    }
}
