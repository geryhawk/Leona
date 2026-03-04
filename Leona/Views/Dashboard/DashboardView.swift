import SwiftUI
import SwiftData
import PhotosUI

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
    @State private var showBabyProfile = false
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var showMealForecast = false
    @State private var showConfetti = false
    @State private var filterCategory: ActivityCategory? = nil
    @State private var showFeedingMenu = false
    
    private var babyActivities: [Activity] {
        allActivities
            .filter { !$0.isDeleted && $0.baby?.id == baby.id }
            .sorted { $0.sortTime > $1.sortTime }
    }

    private var todayActivities: [Activity] {
        babyActivities.filter { $0.sortTime.isToday }
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
                    
                    // Action cards (Feeding, Sleep, Diaper)
                    actionCardsSection
                        .slideInFromBottom(delay: 0.1)

                    // Note button
                    noteButton
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
            .navigationBarHidden(true)
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
            .onChange(of: selectedPhoto) { _, newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self) {
                        baby.profileImageData = data
                        try? modelContext.save()
                    }
                }
            }
            .onAppear {
                checkMilestones()
            }
        }
    }
    
    // MARK: - Baby Header
    
    private var babyHeaderSection: some View {
        Button { showBabySelector = true } label: {
            HStack(spacing: 14) {
                // Profile image — tappable to change photo
                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    ZStack {
                        if let image = baby.profileImage {
                            image
                                .resizable()
                                .scaledToFill()
                        } else {
                            Image(systemName: "person.crop.circle.fill")
                                .resizable()
                                .foregroundStyle(Color.leonaPink.opacity(0.6))
                        }
                    }
                    .frame(width: 52, height: 52)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.leonaPink.opacity(0.3), lineWidth: 2))
                    .overlay(alignment: .bottomTrailing) {
                        // Small camera badge
                        Image(systemName: "camera.fill")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(4)
                            .background(Color.leonaPink.gradient)
                            .clipShape(Circle())
                            .offset(x: 2, y: 2)
                    }
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(baby.displayName)
                            .font(.title3.bold())
                            .foregroundStyle(.primary)

                        if baby.isShared {
                            Image(systemName: "person.2.fill")
                                .font(.caption2)
                                .foregroundStyle(.green)
                        }

                        Image(systemName: "chevron.down")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }

                    Text(baby.ageDescription)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Quick status badge OR notification bell
                if let sleep = ongoingSleep {
                    sleepingBadge(since: sleep.startTime)
                } else if let bf = ongoingBreastfeeding {
                    breastfeedingBadge(since: bf.startTime)
                } else {
                    Image(systemName: "bell.fill")
                        .font(.subheadline)
                        .foregroundStyle(.leonaPink)
                        .frame(width: 36, height: 36)
                        .background(Color.leonaPink.opacity(0.1))
                        .clipShape(Circle())
                }
            }
            .padding(14)
            .leonaCard()
        }
        .buttonStyle(CardPressStyle())
    }
    
    // MARK: - Ongoing Status
    
    @ViewBuilder
    private var ongoingStatusSection: some View {
        if let sleep = ongoingSleep {
            OngoingStatusBanner(
                icon: "moon.fill",
                title: String(localized: "status_sleeping"),
                subtitle: String(localized: "status_since \(sleep.startTime.timeString)"),
                color: .leonaSleep,
                action: { showSleepTracking = true }
            )
        }
        
        if let bf = ongoingBreastfeeding {
            OngoingStatusBanner(
                icon: "drop.circle.fill",
                title: String(localized: "status_breastfeeding"),
                subtitle: String(localized: "status_since \(bf.startTime.timeString)"),
                color: .pink,
                action: { showBreastfeeding = true }
            )
        }
    }
    
    // MARK: - Action Cards

    private var actionCardsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "today_summary"))
                .font(.headline)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)

            HStack(spacing: 12) {
                // Feeding card
                if settings.showFeedingTracking || settings.showBreastfeeding {
                    ActionSummaryCard(
                        icon: ongoingBreastfeeding != nil ? "drop.circle.fill" : "fork.knife",
                        value: "\(todayActivities.filter { $0.type.category == .feeding }.count)",
                        label: String(localized: "summary_feedings"),
                        color: ongoingBreastfeeding != nil ? .pink : .orange,
                        isActive: ongoingBreastfeeding != nil
                    ) {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                            showFeedingMenu.toggle()
                        }
                    }
                }

                // Sleep card
                if settings.showSleepTracking {
                    ActionSummaryCard(
                        icon: "moon.fill",
                        value: todaySleepDuration,
                        label: String(localized: "summary_sleep"),
                        color: .leonaSleep,
                        isActive: ongoingSleep != nil
                    ) {
                        showSleepTracking = true
                    }
                }

                // Diaper card
                if settings.showDiaperTracking {
                    ActionSummaryCard(
                        icon: "humidity.fill",
                        value: "\(todayActivities.filter { $0.type == .diaper }.count)",
                        label: String(localized: "summary_diapers"),
                        color: .cyan
                    ) {
                        showDiaper = true
                    }
                }
            }
            .padding(.bottom, 10)

            // Feeding type picker (expands below cards)
            if showFeedingMenu {
                feedingTypePicker
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.8, anchor: .top).combined(with: .opacity),
                        removal: .scale(scale: 0.9, anchor: .top).combined(with: .opacity)
                    ))
            }
        }
    }

    // MARK: - Feeding Type Picker

    private var feedingTypePicker: some View {
        HStack(spacing: 10) {
            if settings.showBreastfeeding {
                FeedingTypeButton(
                    icon: "drop.circle.fill",
                    label: String(localized: "action_breastfeed"),
                    color: .pink,
                    isActive: ongoingBreastfeeding != nil
                ) {
                    showFeedingMenu = false
                    showBreastfeeding = true
                }
            }

            FeedingTypeButton(
                icon: "waterbottle.fill",
                label: String(localized: "action_formula"),
                color: .orange
            ) {
                showFeedingMenu = false
                showFormula = true
            }

            FeedingTypeButton(
                icon: "drop.fill",
                label: String(localized: "action_moms_milk"),
                color: .purple
            ) {
                showFeedingMenu = false
                showMomsMilk = true
            }

            FeedingTypeButton(
                icon: "fork.knife",
                label: String(localized: "action_solid"),
                color: .green
            ) {
                showFeedingMenu = false
                showSolidFood = true
            }
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 4)
    }

    // MARK: - Note Button

    private var noteButton: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            showNote = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "note.text")
                    .font(.subheadline)
                    .foregroundStyle(.gray)
                    .frame(width: 32, height: 32)
                    .background(Color.gray.opacity(0.1))
                    .clipShape(Circle())

                Text(String(localized: "action_note"))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)

                Spacer()

                Image(systemName: "plus")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .leonaCard()
        }
        .buttonStyle(.plain)
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
    
    // MARK: - Helpers
    
    private func sleepingBadge(since: Date) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "moon.fill")
                .font(.caption)
                .foregroundStyle(.white)
                .shadow(color: .white.opacity(0.8), radius: 4)
                .symbolEffect(.pulse, options: .repeating)
            Text(since.timeAgo())
                .font(.caption)
                .foregroundStyle(.white.opacity(0.9))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.leonaSleep.gradient)
        .clipShape(Capsule())
    }
    
    private func breastfeedingBadge(since: Date) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "drop.circle.fill")
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
            Calendar.current.startOfDay(for: activity.sortTime)
        }
        return grouped.sorted { $0.key > $1.key }
    }
    
    private func checkMilestones() {
        guard baby.isBorn else { return }
        let cal = Calendar.current
        let today = Date()
        let dayMatch = cal.component(.day, from: baby.dateOfBirth) == cal.component(.day, from: today)
        guard dayMatch else { return }

        let components = cal.dateComponents([.year, .month], from: baby.dateOfBirth, to: today)
        let totalMonths = (components.year ?? 0) * 12 + (components.month ?? 0)

        // Show confetti for: monthly milestones (1-11 months) and yearly birthdays (1y, 2y, 3y…)
        let isMonthlyMilestone = totalMonths >= 1 && totalMonths <= 11 && baby.isMonthBirthday
        let isYearlyBirthday = totalMonths >= 12 && baby.isBirthday

        if isMonthlyMilestone || isYearlyBirthday {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                showConfetti = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                    showConfetti = false
                }
            }
        }
    }
}

// MARK: - Action Summary Card (with + button overlay)

struct ActionSummaryCard: View {
    let icon: String
    let value: String
    let label: String
    let color: Color
    var isActive: Bool = false
    let action: () -> Void

    var body: some View {
        Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            action()
        } label: {
            VStack(spacing: 6) {
                if isActive {
                    // Active state: white icon with soft glow halo
                    Image(systemName: icon)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.white)
                        .shadow(color: .white.opacity(0.9), radius: 8)
                        .shadow(color: color.opacity(0.6), radius: 12)
                        .symbolEffect(.pulse, options: .repeating)
                } else {
                    Image(systemName: icon)
                        .font(.title3)
                        .foregroundStyle(color)
                }

                Text(value)
                    .font(.title2.bold().monospacedDigit())
                    .foregroundStyle(isActive ? .white : .primary)

                Text(label)
                    .font(.caption)
                    .foregroundStyle(isActive ? .white.opacity(0.8) : .secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 16)
            .padding(.bottom, 24)
            .background(isActive ? AnyShapeStyle(color.gradient) : AnyShapeStyle(.regularMaterial))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
            .overlay(alignment: .bottom) {
                ZStack {
                    Circle()
                        .fill(color.gradient)
                        .frame(width: 36, height: 36)
                        .shadow(color: color.opacity(0.35), radius: 6, x: 0, y: 3)

                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                }
                .offset(y: 18)
            }
        }
        .buttonStyle(CardPressStyle())
    }
}

/// A press-down style for cards
struct CardPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Feeding Type Button

struct FeedingTypeButton: View {
    let icon: String
    let label: String
    let color: Color
    var isActive: Bool = false
    let action: () -> Void

    var body: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        } label: {
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(isActive ? color : color.opacity(0.12))
                        .frame(width: 48, height: 48)

                    Image(systemName: icon)
                        .font(.body)
                        .foregroundStyle(isActive ? .white : color)
                        .if(isActive) { view in
                            view.symbolEffect(.pulse, options: .repeating)
                        }
                }

                Text(label)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(CardPressStyle())
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
                    .shadow(color: .white.opacity(0.9), radius: 8)
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
