import SwiftUI
import SwiftData

struct SleepTrackingView: View {
    let baby: Baby
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @Query private var allActivities: [Activity]
    
    @State private var elapsedTime: TimeInterval = 0
    @State private var timer: Timer?
    @State private var isRunning = false
    @State private var showManualEntry = false
    @State private var manualStartTime = Date()
    @State private var manualEndTime = Date()
    
    private var ongoingSleep: Activity? {
        allActivities.first {
            $0.baby?.id == baby.id && $0.type == .sleep && $0.isOngoing
        }
    }
    
    private var isDaytime: Bool {
        Date().isDaytime
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Night background
                backgroundGradient
                    .ignoresSafeArea()

                // Twinkling stars over the full screen
                if isRunning {
                    TwinklingStarsView()
                        .ignoresSafeArea()
                }

                ScrollView {
                    VStack(spacing: 28) {
                        // Moon/Sun animation
                        celestialBody
                        
                        // Timer
                        timerDisplay
                        
                        // Status text
                        statusText
                        
                        // Action buttons
                        actionButtons
                        
                        // Manual entry toggle
                        manualEntrySection
                        
                        // Recent sleep history
                        recentSleepSection
                    }
                    .padding()
                }
            }
            .navigationTitle(String(localized: "sleep_tracking"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "close")) { dismiss() }
                        .foregroundStyle(isRunning ? .white : .primary)
                }
            }
            .onAppear { setupSession() }
            .onDisappear { timer?.invalidate() }
        }
    }
    
    // MARK: - Background
    
    private var backgroundGradient: some View {
        Group {
            if isRunning {
                LinearGradient(
                    colors: [
                        Color(red: 0.08, green: 0.08, blue: 0.22),
                        Color(red: 0.12, green: 0.11, blue: 0.32),
                        Color(red: 0.18, green: 0.16, blue: 0.42)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            } else {
                LinearGradient(
                    colors: [.leonaSleep.opacity(0.08), Color(.systemBackground)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        }
    }
    
    // MARK: - Celestial Body
    
    private var celestialBody: some View {
        ZStack {
            // Glow halo behind moon
            if isRunning {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [.white.opacity(0.25), .white.opacity(0.05), .clear],
                            center: .center,
                            startRadius: 30,
                            endRadius: 80
                        )
                    )
                    .frame(width: 160, height: 160)
            }

            Image(systemName: "moon.stars.fill")
                .font(.system(size: 80))
                .foregroundStyle(isRunning ? .white : .leonaSleep)
                .shadow(color: isRunning ? .white.opacity(0.8) : .clear, radius: 12)
                .symbolEffect(.pulse, options: .repeating, isActive: isRunning)
        }
        .frame(height: 180)
        .padding(.top, 20)
    }
    
    // MARK: - Timer Display
    
    private var timerDisplay: some View {
        Text(elapsedTime.hoursMinutesSecondsFormatted)
            .font(.system(size: 56, weight: .light, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(isRunning ? .white : .primary)
            .contentTransition(.numericText(countsDown: false))
            .animation(.default, value: elapsedTime)
    }
    
    // MARK: - Status
    
    private var statusText: some View {
        Group {
            if isRunning {
                Text(String(localized: "sleep_in_progress"))
                    .font(.headline)
                    .foregroundStyle(isRunning ? .white.opacity(0.8) : .leonaSleep)
            } else {
                Text(String(localized: "sleep_tap_to_start"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    // MARK: - Action Buttons
    
    private var actionButtons: some View {
        VStack(spacing: 12) {
            if isRunning {
                Button {
                    wakeUp()
                } label: {
                    Label(String(localized: "wake_up"), systemImage: "bell.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(LeonaButtonStyle(color: .leonaSleep))
            } else {
                Button {
                    startSleep()
                } label: {
                    Label(String(localized: "start_sleep"), systemImage: "moon.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(LeonaButtonStyle(color: .leonaSleep))
            }
        }
    }
    
    // MARK: - Manual Entry
    
    private var manualEntrySection: some View {
        VStack(spacing: 12) {
            Button {
                withAnimation { showManualEntry.toggle() }
            } label: {
                HStack {
                    Image(systemName: "pencil.circle")
                    Text(String(localized: "manual_entry"))
                        .font(.subheadline)
                    Spacer()
                    Image(systemName: showManualEntry ? "chevron.up" : "chevron.down")
                        .font(.caption)
                }
                .foregroundStyle(isRunning ? .white.opacity(0.7) : .secondary)
            }
            
            if showManualEntry {
                VStack(spacing: 12) {
                    DatePicker(String(localized: "fell_asleep"), selection: $manualStartTime, in: ...Date())
                    DatePicker(String(localized: "woke_up"), selection: $manualEndTime, in: ...Date())
                    
                    Button {
                        saveManualSleep()
                    } label: {
                        Label(String(localized: "save_sleep"), systemImage: "checkmark.circle.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(LeonaSecondaryButtonStyle(color: .leonaSleep))
                }
                .padding()
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }
    
    // MARK: - Recent Sleep
    
    private var recentSleepSection: some View {
        let recentSleeps = allActivities
            .filter { $0.baby?.id == baby.id && $0.type == .sleep && !$0.isOngoing }
            .sorted { $0.startTime > $1.startTime }
            .prefix(5)
        
        return Group {
            if !recentSleeps.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text(String(localized: "recent_sleep"))
                        .font(.headline)
                        .foregroundStyle(isRunning ? .white.opacity(0.8) : .secondary)
                    
                    ForEach(Array(recentSleeps)) { sleep in
                        HStack {
                            Image(systemName: "moon.fill")
                                .foregroundStyle(isRunning ? .white : .leonaSleep)
                                .shadow(color: isRunning ? .white.opacity(0.7) : .clear, radius: 4)

                            VStack(alignment: .leading) {
                                Text(sleep.startTime.smartDateTimeString)
                                    .font(.subheadline)
                                    .foregroundStyle(isRunning ? .white : .primary)
                                Text(sleep.durationFormatted)
                                    .font(.caption)
                                    .foregroundStyle(isRunning ? .white.opacity(0.6) : .secondary)
                            }

                            Spacer()
                        }
                        .padding(.vertical, 6)
                    }
                }
            }
        }
    }
    
    // MARK: - Session Management
    
    private func setupSession() {
        if let ongoing = ongoingSleep {
            elapsedTime = Date().timeIntervalSince(ongoing.startTime)
            isRunning = true
            startTimer()
        }
    }
    
    private func startSleep() {
        let activity = Activity(type: .sleep, isOngoing: true, baby: baby)
        modelContext.insert(activity)
        try? modelContext.save()

        elapsedTime = 0
        isRunning = true
        startTimer()
        
        Task {
            await NotificationManager.shared.scheduleSleepCheckReminder(
                babyName: baby.displayName,
                sleepStartTime: Date()
            )
        }
        
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }
    
    private func wakeUp() {
        timer?.invalidate()
        isRunning = false
        
        if let ongoing = ongoingSleep {
            ongoing.endTime = Date()
            ongoing.isOngoing = false
            ongoing.updatedAt = Date()
            try? modelContext.save()
            
            // Trigger immediate sync to push changes to CloudKit
            NotificationCenter.default.post(name: .shouldPushLocalChanges, object: nil)
        }

        NotificationManager.shared.cancelNotification(identifier: "sleep-check")
        UINotificationFeedbackGenerator().notificationOccurred(.success)

        dismiss()
    }
    
    private func saveManualSleep() {
        guard manualEndTime > manualStartTime else { return }
        
        let activity = Activity(type: .sleep, startTime: manualStartTime, endTime: manualEndTime, baby: baby)
        modelContext.insert(activity)
        
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        showManualEntry = false
    }
    
    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if let ongoing = ongoingSleep {
                elapsedTime = Date().timeIntervalSince(ongoing.startTime)
            } else {
                elapsedTime += 1
            }
        }
    }
}

// MARK: - Twinkling Stars + Milky Way + Shooting Stars

private struct StarData: Identifiable {
    let id: Int
    let x: CGFloat      // 0...1 fraction
    let y: CGFloat      // 0...1 fraction
    let size: CGFloat
    let baseOpacity: Double
    let twinkleSpeed: Double
}

private struct TwinklingStarsView: View {
    static let stars: [StarData] = (0..<60).map { i in
        let s = Double(i)
        let x = ((s * 127.1 + 311.7).truncatingRemainder(dividingBy: 1000.0)) / 1000.0
        let y = ((s * 269.5 + 183.3).truncatingRemainder(dividingBy: 1000.0)) / 1000.0
        let size = 1.0 + ((s * 43.7).truncatingRemainder(dividingBy: 3.0))
        let opacity = 0.3 + ((s * 97.3).truncatingRemainder(dividingBy: 0.5))
        let speed = 1.2 + ((s * 53.1).truncatingRemainder(dividingBy: 2.5))
        return StarData(id: i, x: CGFloat(x), y: CGFloat(y), size: CGFloat(size), baseOpacity: opacity, twinkleSpeed: speed)
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Milky way — soft diagonal band
                MilkyWayView()

                // Stars
                ForEach(Self.stars) { star in
                    TwinklingStar(star: star)
                        .position(
                            x: star.x * geo.size.width,
                            y: star.y * geo.size.height
                        )
                }

                // Shooting stars
                ShootingStarView()
            }
        }
    }
}

private struct TwinklingStar: View {
    let star: StarData
    @State private var isBright = false

    var body: some View {
        Circle()
            .fill(.white)
            .frame(width: star.size, height: star.size)
            .opacity(isBright ? min(star.baseOpacity + 0.4, 1.0) : star.baseOpacity * 0.2)
            .shadow(color: .white.opacity(isBright ? 0.5 : 0), radius: star.size * 1.5)
            .onAppear {
                withAnimation(
                    .easeInOut(duration: star.twinkleSpeed)
                    .repeatForever(autoreverses: true)
                    .delay(star.twinkleSpeed * 0.3)
                ) {
                    isBright = true
                }
            }
    }
}

private struct MilkyWayView: View {
    var body: some View {
        GeometryReader { geo in
            Ellipse()
                .fill(
                    LinearGradient(
                        colors: [
                            .clear,
                            .white.opacity(0.02),
                            .white.opacity(0.04),
                            .white.opacity(0.03),
                            .clear
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: geo.size.width * 1.8, height: geo.size.height * 0.25)
                .rotationEffect(.degrees(-30))
                .position(x: geo.size.width * 0.5, y: geo.size.height * 0.35)
                .blur(radius: 20)
        }
    }
}

private struct ShootingStarView: View {
    @State private var shoot = false
    @State private var visible = false

    // Randomized start position and angle per cycle
    @State private var startX: CGFloat = 0.7
    @State private var startY: CGFloat = 0.15

    var body: some View {
        GeometryReader { geo in
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [.white, .white.opacity(0.3), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: shoot ? 60 : 0, height: 1.5)
                .rotationEffect(.degrees(35))
                .position(
                    x: geo.size.width * startX + (shoot ? -120 : 0),
                    y: geo.size.height * startY + (shoot ? 80 : 0)
                )
                .opacity(visible ? 1 : 0)
                .onAppear {
                    scheduleShootingStar()
                }
        }
    }

    private func scheduleShootingStar() {
        // Random delay between 4-9 seconds
        let delay = Double.random(in: 4...9)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            startX = CGFloat.random(in: 0.4...0.9)
            startY = CGFloat.random(in: 0.05...0.35)
            visible = true
            withAnimation(.easeOut(duration: 0.6)) {
                shoot = true
            }
            // Fade out after streak
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation(.easeOut(duration: 0.3)) {
                    visible = false
                }
                // Reset for next cycle
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    shoot = false
                    scheduleShootingStar()
                }
            }
        }
    }
}
