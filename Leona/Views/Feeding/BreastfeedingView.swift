import SwiftUI
import SwiftData

struct BreastfeedingView: View {
    let baby: Baby
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @Query private var allActivities: [Activity]
    
    @State private var selectedSide: BreastSide = .left
    @State private var selectedSlot: SessionSlot = SessionSlot.current()
    @State private var elapsedTime: TimeInterval = 0
    @State private var timer: Timer?
    @State private var isRunning = false
    @State private var showSavedConfirmation = false
    
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
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    // Timer display
                    timerSection
                    
                    // Breast side selector
                    breastSideSection
                    
                    // Session slot
                    sessionSlotSection
                    
                    // Last session info
                    lastSessionInfo
                    
                    // Action buttons
                    actionButtons
                }
                .padding()
            }
            .background(
                LinearGradient(
                    colors: [.pink.opacity(0.08), .white],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
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
        VStack(spacing: 16) {
            // Animated heart
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [.pink.opacity(0.3), .pink.opacity(0.05)],
                            center: .center,
                            startRadius: isRunning ? 30 : 40,
                            endRadius: isRunning ? 80 : 60
                        )
                    )
                    .frame(width: 160, height: 160)
                    .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true), value: isRunning)
                
                Image(systemName: "heart.fill")
                    .font(.system(size: 50))
                    .foregroundStyle(.pink)
                    .symbolEffect(.pulse, options: .repeating, isActive: isRunning)
            }
            
            // Timer display
            Text(elapsedTime.hoursMinutesSecondsFormatted)
                .font(.system(size: 56, weight: .light, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(isRunning ? .pink : .primary)
                .contentTransition(.numericText(countsDown: false))
                .animation(.default, value: elapsedTime)
            
            if isRunning {
                Text(String(localized: "bf_in_progress"))
                    .font(.subheadline)
                    .foregroundStyle(.pink)
            }
        }
        .padding(.top, 20)
    }
    
    // MARK: - Breast Side Selection
    
    private var breastSideSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(String(localized: "breast_side"))
                    .font(.headline)
                
                if let last = lastBreastSide {
                    Text(String(localized: "last_used \(last.displayName)"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                }
            }
            
            HStack(spacing: 12) {
                ForEach(BreastSide.allCases) { side in
                    Button {
                        withAnimation(.spring(response: 0.3)) {
                            selectedSide = side
                        }
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        VStack(spacing: 8) {
                            Image(systemName: side.icon)
                                .font(.title2)
                            Text(side.displayName)
                                .font(.subheadline.weight(.medium))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(
                            selectedSide == side
                                ? Color.pink.opacity(0.15)
                                : Color(.systemGray6)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(selectedSide == side ? .pink : .clear, lineWidth: 2)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .foregroundStyle(selectedSide == side ? .pink : .primary)
                }
            }
        }
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
    
    // MARK: - Action Buttons
    
    private var actionButtons: some View {
        VStack(spacing: 12) {
            if isRunning {
                Button {
                    stopSession()
                } label: {
                    Label(String(localized: "stop_session"), systemImage: "stop.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(LeonaButtonStyle(color: .red))
            } else if ongoingSession != nil {
                Button {
                    resumeSession()
                } label: {
                    Label(String(localized: "resume_session"), systemImage: "play.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(LeonaButtonStyle(color: .pink))
                
                Button {
                    stopSession()
                } label: {
                    Label(String(localized: "finish_session"), systemImage: "checkmark.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(LeonaSecondaryButtonStyle(color: .green))
            } else {
                Button {
                    startSession()
                } label: {
                    Label(String(localized: "start_session"), systemImage: "play.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(LeonaButtonStyle(color: .pink))
            }
        }
        .padding(.top, 8)
    }
    
    // MARK: - Session Management
    
    private func setupSession() {
        if let ongoing = ongoingSession {
            elapsedTime = Date().timeIntervalSince(ongoing.startTime)
            selectedSide = ongoing.breastSide ?? .left
            selectedSlot = ongoing.sessionSlot ?? SessionSlot.current()
            startTimer()
            isRunning = true
        } else {
            // Suggest opposite side from last
            if let last = lastBreastSide {
                switch last {
                case .left: selectedSide = .right
                case .right: selectedSide = .left
                case .both: selectedSide = .both
                }
            }
        }
    }
    
    private func startSession() {
        let activity = Activity(type: .breastfeeding, isOngoing: true, baby: baby)
        activity.breastSide = selectedSide
        activity.sessionSlot = selectedSlot
        modelContext.insert(activity)
        
        elapsedTime = 0
        isRunning = true
        startTimer()
        
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }
    
    private func resumeSession() {
        isRunning = true
        startTimer()
    }
    
    private func stopSession() {
        timer?.invalidate()
        isRunning = false
        
        if let ongoing = ongoingSession {
            ongoing.endTime = Date()
            ongoing.isOngoing = false
            ongoing.breastSide = selectedSide
            ongoing.sessionSlot = selectedSlot
            ongoing.updatedAt = Date()
            
            // Schedule next feeding reminder
            Task {
                await NotificationManager.shared.scheduleFeedingReminder(
                    babyName: baby.displayName,
                    lastFeedingTime: Date()
                )
            }
        }
        
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            dismiss()
        }
    }
    
    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if let ongoing = ongoingSession {
                elapsedTime = Date().timeIntervalSince(ongoing.startTime)
            } else {
                elapsedTime += 1
            }
        }
    }
}
