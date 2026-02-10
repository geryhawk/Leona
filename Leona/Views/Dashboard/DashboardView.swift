import SwiftUI
import SwiftData

struct DashboardView: View {
    let baby: Baby
    
    @Environment(\.modelContext) private var modelContext
    @Environment(AppSettings.self) private var settings
    
    @Query private var allActivities: [Activity]
    
    @State private var showBreastfeeding = false
    @State private var showFormula = false
    @State private var showMomsMilk = false
    @State private var showSolidFood = false
    @State private var showSleepTracking = false
    @State private var showDiaper = false
    @State private var showNote = false
    @State private var showBabySelector = false
    @State private var showMealForecast = false
    @State private var showConfetti = false
    @State private var filterCategory: ActivityCategory? = nil
    
    private var babyActivities: [Activity] {
        allActivities
            .filter { $0.baby?.id == baby.id }
            .sorted { $0.startTime > $1.startTime }
    }
    
    private var todayActivities: [Activity] {
        babyActivities.filter { $0.startTime.isToday }
    }
    
    private var ongoingSleep: Activity? {
        babyActivities.first { $0.type == .sleep && $0.isOngoing }
    }
    
    private var ongoingBreastfeeding: Activity? {
        babyActivities.first { $0.type == .breastfeeding && $0.isOngoing }
    }
    
    private var filteredActivities: [Activity] {
        if let category = filterCategory {
            return babyActivities.filter { $0.type.category == category }
        }
        return babyActivities
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 16) {
                    // Baby header
                    babyHeaderSection
                        .slideInFromBottom(delay: 0)
                    
                    // Ongoing status banners
                    if settings.showOngoingStatus {
                        ongoingStatusSection
                    }
                    
                    // Quick action grid
                    quickActionSection
                        .slideInFromBottom(delay: 0.1)
                    
                    // Daily summary
                    dailySummarySection
                        .slideInFromBottom(delay: 0.15)
                    
                    // Meal forecast
                    if settings.showFeedingTracking {
                        mealForecastButton
                            .slideInFromBottom(delay: 0.2)
                    }
                    
                    // Activity filter
                    activityFilterSection
                    
                    // Activity history
                    activityHistorySection
                }
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Leona")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    babyAvatarButton
                }
                ToolbarItem(placement: .topBarTrailing) {
                    notificationBellButton
                }
            }
            .sheet(isPresented: $showBreastfeeding) {
                BreastfeedingView(baby: baby)
            }
            .sheet(isPresented: $showFormula) {
                FormulaView(baby: baby)
            }
            .sheet(isPresented: $showMomsMilk) {
                MomsMilkView(baby: baby)
            }
            .sheet(isPresented: $showSolidFood) {
                SolidFoodView(baby: baby)
            }
            .sheet(isPresented: $showSleepTracking) {
                SleepTrackingView(baby: baby)
            }
            .sheet(isPresented: $showDiaper) {
                DiaperEntryView(baby: baby)
            }
            .sheet(isPresented: $showNote) {
                NoteEntryView(baby: baby)
            }
            .sheet(isPresented: $showBabySelector) {
                BabySelectorView()
            }
            .sheet(isPresented: $showMealForecast) {
                MealForecastView(baby: baby, activities: babyActivities)
            }
            .overlay {
                if showConfetti {
                    ConfettiView()
                        .ignoresSafeArea()
                        .allowsHitTesting(false)
                }
            }
            .onAppear {
                checkMilestones()
            }
        }
    }
    
    // MARK: - Baby Header
    
    private var babyHeaderSection: some View {
        HStack(spacing: 16) {
            // Profile image
            Group {
                if let image = baby.profileImage {
                    image
                        .resizable()
                        .scaledToFill()
                } else {
                    Image(systemName: "person.crop.circle.fill")
                        .resizable()
                        .foregroundStyle(.leonaPink.opacity(0.6))
                }
            }
            .frame(width: 56, height: 56)
            .clipShape(Circle())
            .overlay(Circle().stroke(.leonaPink.opacity(0.3), lineWidth: 2))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(baby.displayName)
                    .font(.title2.bold())
                    .foregroundStyle(.primary)
                
                Text(baby.ageDescription)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            // Quick status
            if let sleep = ongoingSleep {
                sleepingBadge(since: sleep.startTime)
            } else if let bf = ongoingBreastfeeding {
                breastfeedingBadge(since: bf.startTime)
            }
        }
        .padding()
        .leonaCard()
    }
    
    // MARK: - Ongoing Status
    
    @ViewBuilder
    private var ongoingStatusSection: some View {
        if let sleep = ongoingSleep {
            OngoingStatusBanner(
                icon: "moon.fill",
                title: String(localized: "status_sleeping"),
                subtitle: String(localized: "status_since \(sleep.startTime.timeString)"),
                color: .indigo,
                action: { showSleepTracking = true }
            )
        }
        
        if let bf = ongoingBreastfeeding {
            OngoingStatusBanner(
                icon: "heart.fill",
                title: String(localized: "status_breastfeeding"),
                subtitle: String(localized: "status_since \(bf.startTime.timeString)"),
                color: .pink,
                action: { showBreastfeeding = true }
            )
        }
    }
    
    // MARK: - Quick Actions
    
    private var quickActionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "quick_actions"))
                .font(.headline)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                if settings.showBreastfeeding {
                    QuickActionButton(
                        icon: "heart.fill",
                        label: String(localized: "action_breastfeed"),
                        color: .pink,
                        isActive: ongoingBreastfeeding != nil
                    ) { showBreastfeeding = true }
                }
                
                if settings.showFeedingTracking {
                    QuickActionButton(
                        icon: "cup.and.saucer.fill",
                        label: String(localized: "action_formula"),
                        color: .orange
                    ) { showFormula = true }
                    
                    QuickActionButton(
                        icon: "drop.fill",
                        label: String(localized: "action_moms_milk"),
                        color: .purple
                    ) { showMomsMilk = true }
                    
                    QuickActionButton(
                        icon: "fork.knife",
                        label: String(localized: "action_solid"),
                        color: .green
                    ) { showSolidFood = true }
                }
                
                if settings.showSleepTracking {
                    QuickActionButton(
                        icon: ongoingSleep != nil ? "sun.max.fill" : "moon.fill",
                        label: ongoingSleep != nil ? String(localized: "action_wake") : String(localized: "action_sleep"),
                        color: .indigo,
                        isActive: ongoingSleep != nil
                    ) { showSleepTracking = true }
                }
                
                if settings.showDiaperTracking {
                    QuickActionButton(
                        icon: "humidity.fill",
                        label: String(localized: "action_diaper"),
                        color: .cyan
                    ) { showDiaper = true }
                }
                
                QuickActionButton(
                    icon: "note.text",
                    label: String(localized: "action_note"),
                    color: .gray
                ) { showNote = true }
            }
        }
    }
    
    // MARK: - Daily Summary
    
    private var dailySummarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "today_summary"))
                .font(.headline)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)
            
            HStack(spacing: 12) {
                DailySummaryCard(
                    icon: "fork.knife",
                    value: "\(todayActivities.filter { $0.type.category == .feeding }.count)",
                    label: String(localized: "summary_feedings"),
                    color: .orange
                )
                
                DailySummaryCard(
                    icon: "moon.fill",
                    value: todaySleepDuration,
                    label: String(localized: "summary_sleep"),
                    color: .indigo
                )
                
                DailySummaryCard(
                    icon: "humidity.fill",
                    value: "\(todayActivities.filter { $0.type == .diaper }.count)",
                    label: String(localized: "summary_diapers"),
                    color: .cyan
                )
            }
        }
    }
    
    private var todaySleepDuration: String {
        let sleeps = todayActivities.filter { $0.type == .sleep && !$0.isOngoing }
        let total = sleeps.compactMap(\.duration).reduce(0, +)
        return total.compactFormatted
    }
    
    // MARK: - Meal Forecast
    
    private var mealForecastButton: some View {
        Button { showMealForecast = true } label: {
            HStack(spacing: 12) {
                Image(systemName: "clock.badge.checkmark")
                    .font(.title2)
                    .foregroundStyle(.leonaOrange)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(String(localized: "meal_forecast"))
                        .font(.subheadline.weight(.semibold))
                    
                    if let forecast = MealForecastEngine.forecast(from: babyActivities, babyAgeInDays: baby.ageInDays) {
                        Text(forecast.nextMealFormatted)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text(String(localized: "forecast_not_enough_data"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding()
            .leonaCard()
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Activity Filter
    
    private var activityFilterSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(
                    label: String(localized: "filter_all"),
                    isSelected: filterCategory == nil
                ) { filterCategory = nil }
                
                ForEach(ActivityCategory.allCases) { category in
                    FilterChip(
                        label: category.displayName,
                        isSelected: filterCategory == category
                    ) { filterCategory = category }
                }
            }
            .padding(.horizontal, 4)
        }
    }
    
    // MARK: - Activity History
    
    private var activityHistorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "recent_activities"))
                .font(.headline)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)
            
            if filteredActivities.isEmpty {
                ContentUnavailableView(
                    String(localized: "no_activities"),
                    systemImage: "tray",
                    description: Text(String(localized: "no_activities_description"))
                )
                .padding(.vertical, 40)
            } else {
                // Group by day
                let grouped = groupActivitiesByDay(filteredActivities)
                
                ForEach(grouped, id: \.0) { date, activities in
                    Section {
                        ForEach(activities) { activity in
                            ActivityCardView(activity: activity)
                        }
                    } header: {
                        Text(date.relativeString)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .padding(.top, 8)
                    }
                }
            }
        }
    }
    
    // MARK: - Toolbar Buttons
    
    private var babyAvatarButton: some View {
        Button { showBabySelector = true } label: {
            Group {
                if let image = baby.profileImage {
                    image
                        .resizable()
                        .scaledToFill()
                } else {
                    Image(systemName: "person.2.fill")
                        .font(.caption)
                        .foregroundStyle(.leonaPink)
                }
            }
            .frame(width: 32, height: 32)
            .clipShape(Circle())
            .overlay(Circle().stroke(.leonaPink.opacity(0.3), lineWidth: 1))
        }
    }
    
    private var notificationBellButton: some View {
        Button {
            // Show notifications
        } label: {
            Image(systemName: "bell.fill")
                .foregroundStyle(.leonaPink)
        }
    }
    
    // MARK: - Helpers
    
    private func sleepingBadge(since: Date) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "moon.fill")
                .font(.caption)
            Text(since.timeAgo())
                .font(.caption)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.indigo.opacity(0.15))
        .clipShape(Capsule())
        .foregroundStyle(.indigo)
    }
    
    private func breastfeedingBadge(since: Date) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "heart.fill")
                .font(.caption)
                .symbolEffect(.pulse, options: .repeating)
            Text(since.timeAgo())
                .font(.caption)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.pink.opacity(0.15))
        .clipShape(Capsule())
        .foregroundStyle(.pink)
    }
    
    private func groupActivitiesByDay(_ activities: [Activity]) -> [(Date, [Activity])] {
        let grouped = Dictionary(grouping: activities) { activity in
            Calendar.current.startOfDay(for: activity.startTime)
        }
        return grouped.sorted { $0.key > $1.key }
    }
    
    private func checkMilestones() {
        if baby.isBirthday && baby.isBorn {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                showConfetti = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                    showConfetti = false
                }
            }
        }
    }
}

// MARK: - Quick Action Button

struct QuickActionButton: View {
    let icon: String
    let label: String
    let color: Color
    var isActive: Bool = false
    let action: () -> Void
    
    var body: some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            action()
        }) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(isActive ? color : color.opacity(0.12))
                        .frame(width: 52, height: 52)
                    
                    Image(systemName: icon)
                        .font(.title3)
                        .foregroundStyle(isActive ? .white : color)
                        .if(isActive) { view in
                            view.symbolEffect(.pulse, options: .repeating)
                        }
                }
                
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Daily Summary Card

struct DailySummaryCard: View {
    let icon: String
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
            
            Text(value)
                .font(.title2.bold().monospacedDigit())
            
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .leonaCard()
    }
}

// MARK: - Filter Chip

struct FilterChip: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.subheadline.weight(isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? .white : .primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? Color.leonaPink : Color(.systemGray6))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Ongoing Status Banner

struct OngoingStatusBanner: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(.white)
                    .symbolEffect(.pulse, options: .repeating)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.8))
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundStyle(.white.opacity(0.7))
            }
            .padding()
            .background(color.gradient)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}
