import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(CloudKitManager.self) private var cloudKit
    @Environment(NotificationManager.self) private var notifications
    @Environment(\.modelContext) private var modelContext
    
    @Query(sort: \Baby.createdAt) private var babies: [Baby]
    
    @State private var selectedTab: Tab = .dashboard
    @State private var activeBabyID: String?
    @State private var showSplash = true
    @State private var isNightMode = false
    
    /// Resolved active baby from the current query
    private var activeBaby: Baby? {
        if let id = activeBabyID,
           let uuid = UUID(uuidString: id),
           let baby = babies.first(where: { $0.id == uuid }) {
            return baby
        }
        return babies.first
    }
    
    /// Check if any baby is currently sleeping
    @Query private var allActivities: [Activity]
    private var hasOngoingSleep: Bool {
        guard let baby = activeBaby else { return false }
        return allActivities.contains { $0.baby?.id == baby.id && $0.type == .sleep && $0.isOngoing }
    }
    
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
        ZStack {
            // Night mode background layer
            if isNightMode {
                NightSkyView()
                    .ignoresSafeArea()
                    .transition(.opacity)
            }
            
            Group {
                if !settings.hasCompletedOnboarding && babies.isEmpty {
                    OnboardingView()
                } else {
                    mainTabView
                }
            }
            .onAppear {
                setupApp()
            }
            .onChange(of: babies.count) { _, newCount in
                // Auto-complete onboarding if babies arrived via iCloud sync
                if newCount > 0 && !settings.hasCompletedOnboarding {
                    settings.hasCompletedOnboarding = true
                }
                syncActiveBabyID()
            }
            .onChange(of: settings.activeBabyID) { _, newValue in
                withAnimation(.easeInOut(duration: 0.2)) {
                    activeBabyID = newValue
                }
            }
            
            if showSplash {
                SplashScreenView {
                    showSplash = false
                }
                .transition(.opacity)
                .zIndex(1)
            }
        }
        .preferredColorScheme(isNightMode ? .dark : settings.colorScheme.colorScheme)
        .onChange(of: hasOngoingSleep) { _, sleeping in
            withAnimation(.easeInOut(duration: 0.8)) {
                isNightMode = sleeping
            }
        }
        .onAppear {
            isNightMode = hasOngoingSleep
        }
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
        .id(activeBabyID ?? "none")
        .tint(isNightMode ? .indigo : settings.accentColor.color)
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
        Task {
            await cloudKit.checkiCloudStatus()
        }
        
        Task {
            await notifications.checkAuthorization()
            notifications.setupNotificationCategories()
        }
        
        syncActiveBabyID()
    }
    
    private func syncActiveBabyID() {
        activeBabyID = settings.activeBabyID
        
        if let id = activeBabyID,
           let uuid = UUID(uuidString: id),
           babies.contains(where: { $0.id == uuid }) {
            // Valid
        } else if let first = babies.first {
            let newID = first.id.uuidString
            activeBabyID = newID
            settings.activeBabyID = newID
        } else {
            activeBabyID = nil
        }
    }
}

// MARK: - Night Sky View (shown when baby is sleeping)

struct NightSkyView: View {
    @State private var stars: [(x: CGFloat, y: CGFloat, size: CGFloat, opacity: Double, delay: Double)] = []
    @State private var twinkle = false
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Deep night gradient
                LinearGradient(
                    colors: [
                        Color(red: 0.05, green: 0.05, blue: 0.15),
                        Color(red: 0.08, green: 0.08, blue: 0.22),
                        Color(red: 0.12, green: 0.1, blue: 0.28)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                
                // Stars
                ForEach(Array(stars.enumerated()), id: \.offset) { index, star in
                    Circle()
                        .fill(.white)
                        .frame(width: star.size, height: star.size)
                        .opacity(twinkle ? star.opacity : star.opacity * 0.3)
                        .blur(radius: star.size > 2.5 ? 0.5 : 0)
                        .position(x: star.x, y: star.y)
                        .animation(
                            .easeInOut(duration: Double.random(in: 1.5...3.0))
                            .repeatForever(autoreverses: true)
                            .delay(star.delay),
                            value: twinkle
                        )
                }
                
                // Subtle moon glow in top right
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.white.opacity(0.08),
                                Color.white.opacity(0.03),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 20,
                            endRadius: 120
                        )
                    )
                    .frame(width: 240, height: 240)
                    .position(x: geo.size.width - 60, y: 80)
            }
            .onAppear {
                generateStars(in: geo.size)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    twinkle = true
                }
            }
        }
    }
    
    private func generateStars(in size: CGSize) {
        stars = (0..<60).map { _ in
            (
                x: CGFloat.random(in: 0...size.width),
                y: CGFloat.random(in: 0...size.height),
                size: CGFloat.random(in: 1.0...3.5),
                opacity: Double.random(in: 0.3...0.9),
                delay: Double.random(in: 0...2.0)
            )
        }
    }
}
