import SwiftUI
import SwiftData

struct BreastfeedingView: View {
    let baby: Baby

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query private var allActivities: [Activity]

    @State private var selectedSlot: SessionSlot = SessionSlot.current()
    @State private var elapsedTime: TimeInterval = 0
    @State private var timer: Timer?
    @State private var isRunning = false

    // Slider & lap tracking
    @State private var sliderValue: Double = 0.5
    @State private var activeSide: BreastSide? = nil
    @State private var laps: [BreastfeedingLap] = []
    @State private var showSwitchFlash = false
    @State private var isPaused = false
    @State private var pauseStartTime: Date?
    @State private var totalPauseDuration: TimeInterval = 0

    private var ongoingSession: Activity? {
        allActivities.first {
            $0.baby?.id == baby.id && $0.type == .breastfeeding && $0.isOngoing
        }
    }

    private var lastBreastSide: BreastSide? {
        allActivities
            .filter { $0.baby?.id == baby.id && $0.type == .breastfeeding && !$0.isOngoing }
            .sorted { $0.startTime > $1.startTime }
            .first?.breastSide
    }

    private var sideColor: Color {
        activeSide == .left ? .pink : .purple
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Full-screen gradient background
                LinearGradient(
                    colors: isRunning
                        ? [sideColor.opacity(0.12), sideColor.opacity(0.04), Color(.systemBackground)]
                        : [.pink.opacity(0.08), Color(.systemBackground)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.5), value: activeSide)

                VStack(spacing: 0) {
                    if isRunning {
                        // When running: timer centered in available space, slider + stop at bottom
                        Spacer()

                        timerSection

                        Spacer()

                        // Bottom controls
                        VStack(spacing: 20) {
                            breastSlider
                                .padding(.horizontal, 20)

                            // Stop button (pause is handled by slider center)
                            Button {
                                stopSession()
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "stop.fill")
                                        .font(.caption.weight(.semibold))
                                    Text(String(localized: "stop_session"))
                                        .font(.subheadline.weight(.medium))
                                }
                                .foregroundStyle(.red)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background(
                                    Capsule()
                                        .fill(Color.red.opacity(0.12))
                                )
                            }
                        }
                        .padding(.bottom, 28)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    } else {
                        // When not running: scrollable content
                        ScrollView {
                            VStack(spacing: 24) {
                                timerSection

                                breastSlider
                                    .padding(.horizontal, 4)

                                sessionSlotSection

                                lastSessionInfo
                            }
                            .padding()
                        }
                    }
                }
                .animation(.easeInOut(duration: 0.3), value: isRunning)
            }
            .navigationTitle(String(localized: "breastfeeding"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "close")) { dismiss() }
                }
            }
            .onAppear { setupSession() }
            .onDisappear { timer?.invalidate() }
        }
    }

    // MARK: - Timer Section

    private var timerSection: some View {
        VStack(spacing: 12) {
            ZStack {
                // Halo — moves to the active side
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [sideColor.opacity(0.3), sideColor.opacity(0.0)],
                            center: .center,
                            startRadius: 20,
                            endRadius: isRunning ? 90 : 65
                        )
                    )
                    .frame(width: 160, height: 160)
                    .offset(x: isRunning ? (activeSide == .left ? -50 : activeSide == .right ? 50 : 0) : 0)
                    .animation(.spring(response: 0.6, dampingFraction: 0.7), value: activeSide)
                    .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: isRunning)

                // Heart — always centered
                Image(systemName: "drop.circle.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(isRunning ? sideColor : .pink)
                    .symbolEffect(.pulse, options: .repeating, isActive: isRunning)
            }
            .frame(height: 120)

            // Main timer — shows feeding time when paused, total elapsed otherwise
            if isPaused {
                // During pause: show the pause duration as the main big timer
                Text(currentPauseDuration.hoursMinutesSecondsFormatted)
                    .font(.system(size: 52, weight: .light, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.orange)
                    .contentTransition(.numericText(countsDown: false))
                    .animation(.default, value: currentPauseDuration)
            } else {
                Text(elapsedTime.hoursMinutesSecondsFormatted)
                    .font(.system(size: 52, weight: .light, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(isRunning ? sideColor : .primary)
                    .contentTransition(.numericText(countsDown: false))
                    .animation(.default, value: elapsedTime)
            }

            // Sub-timers row when paused
            if isPaused {
                HStack(spacing: 16) {
                    // Feeding time
                    HStack(spacing: 4) {
                        Image(systemName: "drop.fill")
                            .font(.caption2)
                        Text(feedingTime.hoursMinutesSecondsFormatted)
                            .monospacedDigit()
                    }
                    .font(.caption)
                    .foregroundStyle(.pink)

                    // Total elapsed
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.caption2)
                        Text(elapsedTime.hoursMinutesSecondsFormatted)
                            .monospacedDigit()
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                .transition(.opacity)
            } else if isRunning && totalPauseDuration > 0 {
                // Active feeding time (excludes breaks) — shown when there's been a pause
                HStack(spacing: 4) {
                    Image(systemName: "drop.fill")
                        .font(.caption2)
                    Text(feedingTime.hoursMinutesSecondsFormatted)
                        .monospacedDigit()
                }
                .font(.caption)
                .foregroundStyle(sideColor)
                .transition(.opacity)
            }

            // Side label
            Group {
                if isPaused {
                    VStack(spacing: 6) {
                        HStack(spacing: 6) {
                            Image(systemName: "pause.circle.fill")
                                .font(.caption)
                                .symbolEffect(.pulse, options: .repeating)
                            Text(String(localized: "session_paused"))
                                .font(.subheadline.weight(.semibold))
                        }
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(Color.orange.opacity(0.1))
                        .clipShape(Capsule())

                        Text(String(localized: "slide_to_resume_side"))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .transition(.scale.combined(with: .opacity))
                } else if isRunning, let side = activeSide {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(sideColor)
                            .frame(width: 8, height: 8)
                        Text(side.displayName)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(sideColor)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(sideColor.opacity(0.1))
                    .clipShape(Capsule())
                    .transition(.scale.combined(with: .opacity))
                } else if !isRunning && activeSide == nil {
                    Text(String(localized: "slide_to_start"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .animation(.spring(response: 0.4), value: activeSide)
            .animation(.spring(response: 0.4), value: isPaused)
        }
        .padding(.top, 8)
    }

    // MARK: - Breast Slider

    private var breastSlider: some View {
        VStack(spacing: 6) {
            // Last used hint
            if !isRunning, activeSide == nil, let last = lastBreastSide {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.uturn.right.circle.fill")
                        .font(.caption)
                    Text(String(localized: "last_used \(last.displayName)"))
                        .font(.caption)
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
            }

            // Per-side durations + timeline above the track
            if isRunning {
                VStack(spacing: 6) {
                    HStack {
                        Text(formatDuration(totalForSide(.left)))
                            .font(.caption.monospacedDigit().weight(.semibold))
                            .foregroundStyle(activeSide == .left ? .pink : .secondary.opacity(0.5))
                        Spacer()
                        Text(formatDuration(totalForSide(.right)))
                            .font(.caption.monospacedDigit().weight(.semibold))
                            .foregroundStyle(activeSide == .right ? .purple : .secondary.opacity(0.5))
                    }

                    // Timeline bar showing side switches
                    if laps.count > 1 {
                        GeometryReader { geo in
                            let totalDur = laps.reduce(0.0) { sum, lap in
                                sum + (lap.endTime ?? Date()).timeIntervalSince(lap.startTime)
                            }

                            HStack(spacing: 2) {
                                ForEach(laps) { lap in
                                    let dur = (lap.endTime ?? Date()).timeIntervalSince(lap.startTime)
                                    let fraction = totalDur > 0 ? dur / totalDur : 1.0 / Double(laps.count)

                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(lap.side == .left ? Color.pink : Color.purple)
                                        .frame(width: max(geo.size.width * fraction - 2, 4))
                                        .opacity(lap.side == activeSide ? 1.0 : 0.4)
                                }
                            }
                        }
                        .frame(height: 6)
                        .clipShape(Capsule())
                        .transition(.opacity)
                    }
                }
                .padding(.horizontal, 4)
                .animation(.easeInOut(duration: 0.3), value: activeSide)
                .animation(.easeInOut(duration: 0.3), value: laps.count)
            }

            // The slider track
            GeometryReader { geo in
                let width = geo.size.width
                let thumbSize: CGFloat = 60
                let trackPadding: CGFloat = thumbSize / 2
                let trackWidth = width - thumbSize
                let thumbX = trackPadding + sliderValue * trackWidth
                let trackHeight: CGFloat = 68

                ZStack {
                    // Track background with gradient
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.pink.opacity(0.08),
                                    Color(.systemGray6),
                                    Color.purple.opacity(0.08)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(height: trackHeight)

                    // Active glow fill
                    if let side = activeSide {
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: side == .left
                                        ? [.pink.opacity(0.25), .pink.opacity(0.05)]
                                        : [.purple.opacity(0.05), .purple.opacity(0.25)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(height: trackHeight)
                            .animation(.easeInOut(duration: 0.4), value: activeSide)
                    }

                    // Left side label
                    HStack {
                        VStack(spacing: 2) {
                            Image(systemName: "circle.lefthalf.filled")
                                .font(.title2)
                            Text(String(localized: "breast_left"))
                                .font(.caption2.weight(.medium))
                        }
                        .foregroundStyle(activeSide == .left ? .pink : .secondary.opacity(0.6))
                        .padding(.leading, 14)
                        .animation(.easeInOut(duration: 0.3), value: activeSide)
                        Spacer()
                    }

                    // Right side label
                    HStack {
                        Spacer()
                        VStack(spacing: 2) {
                            Image(systemName: "circle.righthalf.filled")
                                .font(.title2)
                            Text(String(localized: "breast_right"))
                                .font(.caption2.weight(.medium))
                        }
                        .foregroundStyle(activeSide == .right ? .purple : .secondary.opacity(0.6))
                        .padding(.trailing, 14)
                        .animation(.easeInOut(duration: 0.3), value: activeSide)
                    }

                    // Center pause indicator (only when running)
                    if isRunning && !isPaused {
                        Image(systemName: "pause.fill")
                            .font(.caption2)
                            .foregroundStyle(.secondary.opacity(0.3))
                    }

                    // Thumb — flat style with dynamic icon based on slider position
                    Circle()
                        .fill(thumbColor)
                        .frame(width: thumbSize, height: thumbSize)
                        .overlay {
                            thumbIcon
                        }
                        .animation(.spring(response: 0.3), value: thumbIconState)
                    .position(x: thumbX, y: trackHeight / 2)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                let newValue = (value.location.x - trackPadding) / trackWidth
                                sliderValue = max(0, min(1, newValue))
                            }
                            .onEnded { _ in
                                handleSliderEnd()
                            }
                    )
                }
            }
            .frame(height: 68)

            // Hint text
            if !isRunning && activeSide == nil {
                Text(String(localized: "slide_to_start"))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            } else if isPaused {
                Text(String(localized: "slide_to_resume"))
                    .font(.caption)
                    .foregroundStyle(.orange.opacity(0.6))
            } else if isRunning {
                Text(String(localized: "slide_to_switch"))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    // MARK: - Dynamic Thumb

    private enum ThumbIconState: Equatable {
        case idle, left, right, pause
    }

    private var thumbIconState: ThumbIconState {
        if activeSide == nil { return .idle }
        // When dragging, use position to determine icon
        if sliderValue < 0.3 { return .left }
        if sliderValue > 0.7 { return .right }
        if sliderValue >= 0.35 && sliderValue <= 0.65 { return .pause }
        // In transition zones, lean toward current side
        if sliderValue < 0.5 { return .left }
        return .right
    }

    private var thumbColor: Color {
        switch thumbIconState {
        case .idle: return Color(.systemGray5)
        case .left: return .pink
        case .right: return .purple
        case .pause: return .orange
        }
    }

    @ViewBuilder
    private var thumbIcon: some View {
        switch thumbIconState {
        case .idle:
            Image(systemName: "arrow.left.arrow.right")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
        case .left:
            Image(systemName: "arrow.left")
                .font(.title3.weight(.bold))
                .foregroundStyle(.white)
        case .right:
            Image(systemName: "arrow.right")
                .font(.title3.weight(.bold))
                .foregroundStyle(.white)
        case .pause:
            Image(systemName: "pause.fill")
                .font(.title3.weight(.bold))
                .foregroundStyle(.white)
        }
    }

    private func totalForSide(_ side: BreastSide) -> TimeInterval {
        laps.filter { $0.side == side }.reduce(0.0) { sum, lap in
            sum + (lap.endTime ?? Date()).timeIntervalSince(lap.startTime)
        }
    }

    private func formatDuration(_ interval: TimeInterval) -> String {
        let m = Int(interval) / 60
        let s = Int(interval) % 60
        return m > 0 ? "\(m)m\(String(format: "%02d", s))s" : "\(s)s"
    }

    // MARK: - Session Slot

    private var sessionSlotSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "session_slot"))
                .font(.headline)

            HStack(spacing: 8) {
                ForEach(SessionSlot.allCases) { slot in
                    Button {
                        withAnimation { selectedSlot = slot }
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: slot.icon)
                                .font(.caption)
                            Text(slot.displayName)
                                .font(.caption2)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(selectedSlot == slot ? slot.color.opacity(0.15) : Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(selectedSlot == slot ? slot.color : .clear, lineWidth: 1.5)
                        )
                    }
                    .foregroundStyle(selectedSlot == slot ? slot.color : .secondary)
                }
            }
        }
    }

    // MARK: - Last Session Info

    private var lastSessionInfo: some View {
        let lastSession = allActivities
            .filter { $0.baby?.id == baby.id && $0.type == .breastfeeding && !$0.isOngoing }
            .sorted { $0.startTime > $1.startTime }
            .first

        return Group {
            if let session = lastSession {
                HStack {
                    Image(systemName: "clock")
                        .foregroundStyle(.secondary)
                    Text(String(localized: "last_session"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(session.durationFormatted) · \(session.startTime.timeAgo())")
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                }
                .padding()
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    // MARK: - Slider Logic

    private func handleSliderEnd() {
        let leftThreshold = 0.3
        let rightThreshold = 0.7
        let centerLow = 0.35
        let centerHigh = 0.65

        if sliderValue < leftThreshold {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) { sliderValue = 0.0 }
            if isPaused { resumeToSide(.left) } else { switchToSide(.left) }
        } else if sliderValue > rightThreshold {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) { sliderValue = 1.0 }
            if isPaused { resumeToSide(.right) } else { switchToSide(.right) }
        } else if isRunning && !isPaused && sliderValue >= centerLow && sliderValue <= centerHigh {
            // Snap to center = pause
            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) { sliderValue = 0.5 }
            togglePause()
        } else if isPaused {
            // Didn't reach a side threshold, stay paused in center
            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) { sliderValue = 0.5 }
        } else {
            // Snap back to current position
            let target: Double = activeSide == .left ? 0.0 : activeSide == .right ? 1.0 : 0.5
            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) { sliderValue = target }
        }
    }

    /// Resume from pause directly to a specific side
    private func resumeToSide(_ side: BreastSide) {
        let now = Date()

        // Account for pause duration
        if let pauseStart = pauseStartTime {
            totalPauseDuration += now.timeIntervalSince(pauseStart)
        }
        pauseStartTime = nil

        // Start a new lap on the chosen side
        laps.append(BreastfeedingLap(side: side, startTime: now))

        withAnimation(.spring(response: 0.3)) {
            activeSide = side
            isPaused = false
        }
        // Timer is already running (kept alive during pause)

        // Persist
        if let ongoing = ongoingSession {
            ongoing.breastfeedingLaps = laps
            ongoing.breastSide = .both
            ongoing.updatedAt = now
            try? modelContext.save()
        }

        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    private func switchToSide(_ newSide: BreastSide) {
        let now = Date()

        if activeSide == nil {
            // First selection — start the session
            startSession(side: newSide)
        } else if activeSide != newSide {
            // Switching sides — close current lap, open new one
            if !laps.isEmpty {
                laps[laps.count - 1].endTime = now
            }

            withAnimation(.spring(response: 0.4)) {
                laps.append(BreastfeedingLap(side: newSide, startTime: now))
                activeSide = newSide
            }

            // Persist laps to ongoing activity
            if let ongoing = ongoingSession {
                ongoing.breastfeedingLaps = laps
                ongoing.breastSide = .both
                ongoing.updatedAt = now
                try? modelContext.save()
            }

            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
    }

    // MARK: - Pause/Resume

    private func togglePause() {
        let now = Date()
        if isPaused {
            // Resume — calculate pause duration and add it
            if let pauseStart = pauseStartTime {
                totalPauseDuration += now.timeIntervalSince(pauseStart)
            }
            pauseStartTime = nil

            // Start a new lap on the same side
            if let side = activeSide {
                laps.append(BreastfeedingLap(side: side, startTime: now))
            }

            withAnimation(.spring(response: 0.3)) { isPaused = false }
            // Timer is already running (kept alive during pause)
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        } else {
            // Pause — close current lap
            if !laps.isEmpty && laps[laps.count - 1].endTime == nil {
                laps[laps.count - 1].endTime = now
            }
            pauseStartTime = now
            // Keep timer running so pause duration ticks visibly

            // Persist
            if let ongoing = ongoingSession {
                ongoing.breastfeedingLaps = laps
                try? modelContext.save()
            }

            withAnimation(.spring(response: 0.3)) { isPaused = true }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
    }

    // MARK: - Session Management

    private func setupSession() {
        if let ongoing = ongoingSession {
            laps = ongoing.breastfeedingLaps
            selectedSlot = ongoing.sessionSlot ?? SessionSlot.current()

            if !laps.isEmpty {
                activeSide = laps.last?.side

                // Calculate total pause duration from gaps between consecutive laps
                totalPauseDuration = 0
                for i in 1..<laps.count {
                    if let prevEnd = laps[i - 1].endTime {
                        let gap = laps[i].startTime.timeIntervalSince(prevEnd)
                        if gap > 0 { totalPauseDuration += gap }
                    }
                }
            } else {
                activeSide = ongoing.breastSide ?? .left
                laps = [BreastfeedingLap(side: activeSide ?? .left, startTime: ongoing.startTime)]
            }

            elapsedTime = Date().timeIntervalSince(ongoing.startTime)
            sliderValue = activeSide == .left ? 0.0 : 1.0
            isRunning = true
            startTimer()
        } else {
            sliderValue = 0.5
            activeSide = nil
        }
    }

    private func startSession(side: BreastSide) {
        let now = Date()
        let activity = Activity(type: .breastfeeding, isOngoing: true, baby: baby)
        activity.breastSide = side
        activity.sessionSlot = selectedSlot

        let firstLap = BreastfeedingLap(side: side, startTime: now)
        laps = [firstLap]
        activity.breastfeedingLaps = laps

        modelContext.insert(activity)
        try? modelContext.save()

        withAnimation(.spring(response: 0.4)) {
            activeSide = side
            isRunning = true
        }
        elapsedTime = 0
        startTimer()

        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    private func stopSession() {
        timer?.invalidate()

        if let ongoing = ongoingSession {
            let now = Date()

            // Close the final lap
            if !laps.isEmpty && laps[laps.count - 1].endTime == nil {
                laps[laps.count - 1].endTime = now
            }

            ongoing.endTime = now
            ongoing.isOngoing = false
            ongoing.breastfeedingLaps = laps
            ongoing.sessionSlot = selectedSlot
            ongoing.updatedAt = now

            let sides = Set(laps.map(\.side))
            if sides.count == 1, let side = sides.first {
                ongoing.breastSide = side
            } else {
                ongoing.breastSide = .both
            }

            try? modelContext.save()

            NotificationCenter.default.post(name: .shouldPushLocalChanges, object: nil)

            Task {
                await NotificationManager.shared.scheduleFeedingReminder(
                    babyName: baby.displayName,
                    lastFeedingTime: Date()
                )
            }
        }

        isRunning = false
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        dismiss()
    }

    /// Active feeding time = total elapsed minus all pause durations
    private var feedingTime: TimeInterval {
        let currentPause: TimeInterval
        if isPaused, let pauseStart = pauseStartTime {
            currentPause = totalPauseDuration + Date().timeIntervalSince(pauseStart)
        } else {
            currentPause = totalPauseDuration
        }
        return max(0, elapsedTime - currentPause)
    }

    /// Current pause duration (ticking while paused)
    private var currentPauseDuration: TimeInterval {
        guard isPaused, let pauseStart = pauseStartTime else { return 0 }
        return Date().timeIntervalSince(pauseStart)
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if let ongoing = ongoingSession {
                // Total session time including breaks
                elapsedTime = Date().timeIntervalSince(ongoing.startTime)
            } else {
                elapsedTime += 1
            }
        }
    }
}
