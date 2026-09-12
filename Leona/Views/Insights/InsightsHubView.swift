import SwiftUI
import SwiftData

/// "‹ Thread · Trends / Growth / Health" — one pushed screen, three tabs switched in place.
struct InsightsHubView: View {
    let baby: Baby

    @Environment(ThreadNavigator.self) private var navigator
    @State private var tab: InsightsTab
    @State private var period: TrendsPeriod = .sevenDays
    @State private var metric: GrowthMetric = .weight

    init(baby: Baby, initialTab: InsightsTab) {
        self.baby = baby
        _tab = State(initialValue: initialTab)
    }

    var body: some View {
        VStack(spacing: 0) {
            SubScreenHeader(title: title, meta: meta) {
                navigator.backToThread()
            }

            HStack(spacing: 7) {
                LeonaSegment(title: String(localized: "trends_title"), isOn: tab == .trends) { select(.trends) }
                LeonaSegment(title: String(localized: "growth"), isOn: tab == .growth) { select(.growth) }
                LeonaSegment(title: String(localized: "health"), isOn: tab == .health) { select(.health) }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 12)

            Group {
                switch tab {
                case .trends:
                    TrendsView(baby: baby, period: $period)
                case .growth:
                    GrowthView(baby: baby, metric: $metric)
                case .health:
                    HealthView(baby: baby)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .transition(.opacity)
            .id(tab)
        }
        .leonaScreen()
        .onAppear {
            #if DEBUG
            applyDemoSelection()
            #endif
        }
    }

    private var title: String {
        switch tab {
        case .trends: return String(localized: "trends_title")
        case .growth: return String(localized: "growth")
        case .health: return String(localized: "health")
        }
    }

    private var meta: String {
        switch tab {
        case .trends: return period.title
        case .growth: return metric.title
        case .health: return ""
        }
    }

    private func select(_ newTab: InsightsTab) {
        guard newTab != tab else { return }
        withAnimation(.easeOut(duration: 0.18)) { tab = newTab }
    }

    // MARK: - Screenshot automation

    #if DEBUG
    private func applyDemoSelection() {
        guard DemoDataGenerator.isDemoMode, let screen = DemoDataGenerator.requestedScreen else { return }
        switch screen {
        case .stats:
            // The old stats screen had feeding / diaper / sleep sections; the thread's Trends
            // page shows milk and sleep together, so every variant lands on the 30-day view.
            period = .thirtyDays
        case .growth:
            switch DemoDataGenerator.requestedVariant {
            case "height": metric = .height
            case "head": metric = .head
            default: metric = .weight
            }
        default:
            break
        }
    }
    #endif
}
