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
                // Day/Night background
                backgroundGradient
                    .ignoresSafeArea()
                
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
                        .foregroundStyle(isRunning && !isDaytime ? .white : .primary)
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
                if isDaytime {
                    LinearGradient(
                        colors: [.blue.opacity(0.15), .cyan.opacity(0.08), Color(.systemBackground)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                } else {
                    LinearGradient(
                        colors: [
                            Color(red: 0.1, green: 0.1, blue: 0.3),
                            Color(red: 0.15, green: 0.15, blue: 0.4),
                            Color(red: 0.2, green: 0.2, blue: 0.45)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
            } else {
                LinearGradient(
                    colors: [.indigo.opacity(0.08), Color(.systemBackground)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        }
    }
    
    // MARK: - Celestial Body
    
    private var celestialBody: some View {
        ZStack {
            if isRunning && !isDaytime {
                // Stars (fixed positions to avoid re-render flicker)
                ForEach(0..<20, id: \.self) { i in
                    let seed = Double(i)
                    Circle()
                        .fill(.white)
                        .frame(width: CGFloat(1.0 + (seed * 7.3).truncatingRemainder(dividingBy: 2.0)))
                        .offset(
                            x: CGFloat(-150 + (seed * 31.7).truncatingRemainder(dividingBy: 300)),
                            y: CGFloat(-80 + (seed * 17.3).truncatingRemainder(dividingBy: 160))
                        )
                        .opacity(0.3 + (seed * 13.7).truncatingRemainder(dividingBy: 0.5))
                }
            }
            
            Image(systemName: isRunning ? (isDaytime ? "cloud.sun.fill" : "moon.stars.fill") : "moon.fill")
                .font(.system(size: 80))
                .foregroundStyle(
                    isRunning
                        ? (isDaytime ? .yellow : .white)
                        : .indigo
                )
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
            .foregroundStyle(isRunning && !isDaytime ? .white : .primary)
            .contentTransition(.numericText(countsDown: false))
            .animation(.default, value: elapsedTime)
    }
    
    // MARK: - Status
    
    private var statusText: some View {
        Group {
            if isRunning {
                Text(String(localized: "sleep_in_progress"))
                    .font(.headline)
                    .foregroundStyle(isRunning && !isDaytime ? .white.opacity(0.8) : .indigo)
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
                    Label(String(localized: "wake_up"), systemImage: "sun.max.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(LeonaButtonStyle(color: isDaytime ? .orange : .yellow))
            } else {
                Button {
                    startSleep()
                } label: {
                    Label(String(localized: "start_sleep"), systemImage: "moon.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(LeonaButtonStyle(color: .indigo))
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
                .foregroundStyle(isRunning && !isDaytime ? .white.opacity(0.7) : .secondary)
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
                    .buttonStyle(LeonaSecondaryButtonStyle(color: .indigo))
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
                        .foregroundStyle(isRunning && !isDaytime ? .white.opacity(0.8) : .secondary)
                    
                    ForEach(Array(recentSleeps)) { sleep in
                        HStack {
                            Image(systemName: sleep.startTime.isDaytime ? "sun.min.fill" : "moon.fill")
                                .foregroundStyle(sleep.startTime.isDaytime ? .orange : .indigo)
                            
                            VStack(alignment: .leading) {
                                Text(sleep.startTime.smartDateTimeString)
                                    .font(.subheadline)
                                Text(sleep.durationFormatted)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
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
