import SwiftUI
import SwiftData
import Charts

struct StatsView: View {
    let baby: Baby
    
    @Query private var allActivities: [Activity]
    @State private var selectedPeriod: TimePeriod = .sevenDays
    @State private var selectedSection: StatsSection = .feeding
    
    private var babyActivities: [Activity] {
        allActivities.filter { $0.baby?.id == baby.id }
    }
    
    enum StatsSection: String, CaseIterable, Identifiable {
        case feeding, sleep, diaper
        
        var id: String { rawValue }
        
        var displayName: String {
            switch self {
            case .feeding: return String(localized: "stats_feeding")
            case .sleep: return String(localized: "stats_sleep")
            case .diaper: return String(localized: "stats_diaper")
            }
        }
        
        var icon: String {
            switch self {
            case .feeding: return "fork.knife"
            case .sleep: return "moon.fill"
            case .diaper: return "humidity.fill"
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Period selector
                    periodSelector
                    
                    // Section selector
                    sectionSelector
                    
                    // Stats content
                    switch selectedSection {
                    case .feeding:
                        feedingStatsSection
                    case .sleep:
                        sleepStatsSection
                    case .diaper:
                        diaperStatsSection
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(String(localized: "statistics"))
        }
    }
    
    // MARK: - Period Selector
    
    private var periodSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(TimePeriod.allCases) { period in
                    Button {
                        withAnimation(.spring(response: 0.3)) {
                            selectedPeriod = period
                        }
                    } label: {
                        Text(period.displayName)
                            .font(.subheadline.weight(selectedPeriod == period ? .semibold : .regular))
                            .foregroundStyle(selectedPeriod == period ? .white : .primary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(selectedPeriod == period ? Color.leonaPink : Color(.systemGray6))
                            .clipShape(Capsule())
                    }
                }
            }
        }
    }
    
    // MARK: - Section Selector
    
    private var sectionSelector: some View {
        HStack(spacing: 8) {
            ForEach(StatsSection.allCases) { section in
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        selectedSection = section
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: section.icon)
                            .font(.caption)
                        Text(section.displayName)
                            .font(.subheadline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(selectedSection == section ? Color.leonaPink.opacity(0.12) : Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(selectedSection == section ? .leonaPink : .clear, lineWidth: 1.5)
                    )
                }
                .foregroundStyle(selectedSection == section ? .leonaPink : .secondary)
            }
        }
    }
    
    // MARK: - Feeding Stats
    
    private var feedingStatsSection: some View {
        let stats = StatisticsEngine.feedingStats(activities: babyActivities, period: selectedPeriod)
        let chartData = StatisticsEngine.feedingChartData(activities: babyActivities, period: selectedPeriod)
        
        return VStack(spacing: 16) {
            // Summary cards
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                statCard(title: String(localized: "stat_total_feedings"), value: "\(stats.totalFeedings)", icon: "fork.knife", color: .orange)
                statCard(title: String(localized: "stat_breastfeeding"), value: "\(stats.breastfeedingCount)", icon: "heart.fill", color: .pink)
                statCard(title: String(localized: "stat_formula_total"), value: "\(Int(stats.totalFormulaMl)) ml", icon: "cup.and.saucer.fill", color: .orange)
                statCard(title: String(localized: "stat_avg_interval"), value: stats.averageInterval.compactFormatted, icon: "clock", color: .blue)
            }
            
            // Chart
            if !chartData.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text(String(localized: "feeding_chart"))
                        .font(.headline)
                    
                    Chart(chartData) { point in
                        BarMark(
                            x: .value("Date", point.date, unit: .day),
                            y: .value("Value", point.value)
                        )
                        .foregroundStyle(by: .value("Type", point.category))
                    }
                    .chartForegroundStyleScale([
                        "formula": Color.orange,
                        "momsMilk": Color.purple,
                        "breastfeeding": Color.pink,
                        "solidFood": Color.green
                    ])
                    .chartLegend(position: .bottom)
                    .frame(height: 220)
                    .padding()
                    .leonaCard()
                }
            }
        }
    }
    
    // MARK: - Sleep Stats
    
    private var sleepStatsSection: some View {
        let stats = StatisticsEngine.sleepStats(activities: babyActivities, period: selectedPeriod)
        let chartData = StatisticsEngine.sleepChartData(activities: babyActivities, period: selectedPeriod)
        
        return VStack(spacing: 16) {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                statCard(title: String(localized: "stat_total_sleep"), value: stats.totalDuration.compactFormatted, icon: "moon.fill", color: .indigo)
                statCard(title: String(localized: "stat_avg_per_day"), value: stats.averageDurationPerDay.compactFormatted, icon: "calendar", color: .blue)
                statCard(title: String(localized: "stat_day_sleep"), value: stats.dayDuration.compactFormatted, icon: "sun.max.fill", color: .orange)
                statCard(title: String(localized: "stat_night_sleep"), value: stats.nightDuration.compactFormatted, icon: "moon.stars.fill", color: .indigo)
                statCard(title: String(localized: "stat_longest"), value: stats.longestSession.compactFormatted, icon: "arrow.up.circle", color: .green)
                statCard(title: String(localized: "stat_sessions"), value: "\(stats.totalSessions)", icon: "number", color: .purple)
            }
            
            if !chartData.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text(String(localized: "sleep_chart"))
                        .font(.headline)
                    
                    Chart(chartData) { point in
                        BarMark(
                            x: .value("Date", point.date, unit: .day),
                            y: .value("Hours", point.value)
                        )
                        .foregroundStyle(by: .value("Type", point.category))
                    }
                    .chartForegroundStyleScale([
                        "day": Color.orange,
                        "night": Color.indigo
                    ])
                    .chartYAxisLabel(String(localized: "chart_hours"))
                    .chartLegend(position: .bottom)
                    .frame(height: 220)
                    .padding()
                    .leonaCard()
                }
            }
        }
    }
    
    // MARK: - Diaper Stats
    
    private var diaperStatsSection: some View {
        let stats = StatisticsEngine.diaperStats(activities: babyActivities, period: selectedPeriod)
        let chartData = StatisticsEngine.diaperChartData(activities: babyActivities, period: selectedPeriod)
        
        return VStack(spacing: 16) {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                statCard(title: String(localized: "stat_total_diapers"), value: "\(stats.totalChanges)", icon: "humidity.fill", color: .cyan)
                statCard(title: String(localized: "stat_avg_per_day"), value: String(format: "%.1f", stats.averagePerDay), icon: "calendar", color: .blue)
                statCard(title: String(localized: "stat_pee"), value: "\(stats.peeCount)", icon: "drop.fill", color: .yellow)
                statCard(title: String(localized: "stat_poop"), value: "\(stats.poopCount)", icon: "leaf.fill", color: .brown)
            }
            
            if !chartData.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text(String(localized: "diaper_chart"))
                        .font(.headline)
                    
                    Chart(chartData) { point in
                        BarMark(
                            x: .value("Date", point.date, unit: .day),
                            y: .value("Count", point.value)
                        )
                        .foregroundStyle(by: .value("Type", point.category))
                    }
                    .chartForegroundStyleScale([
                        "pee": Color.yellow,
                        "poop": Color.brown
                    ])
                    .chartLegend(position: .bottom)
                    .frame(height: 220)
                    .padding()
                    .leonaCard()
                }
            }
        }
    }
    
    // MARK: - Stat Card
    
    private func statCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(color)
                Spacer()
            }
            
            Text(value)
                .font(.title2.bold().monospacedDigit())
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .leonaCard()
    }
}
