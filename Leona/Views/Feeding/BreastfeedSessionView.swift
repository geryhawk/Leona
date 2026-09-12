import SwiftUI
import SwiftData

/// Full-screen cover for the running breastfeeding session. Warm rust world, a glow that
/// follows the active side, LEFT / RIGHT tiles to switch, pause, per-stretch record and Done.
struct BreastfeedSessionView: View {
    let baby: Baby

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(ThreadNavigator.self) private var navigator

    @Query private var activities: [Activity]

    @State private var isClosing = false

    init(baby: Baby) {
        self.baby = baby
        let id = baby.id
        _activities = Query(filter: #Predicate<Activity> { $0.baby?.id == id }, sort: \Activity.startTime)
    }

    // MARK: - Data

    private var session: Activity? {
        activities.first { $0.type == .breastfeeding && $0.isOngoing }
    }

    /// The most recent finished breastfeed, used for the "so I have started on the other side" hint.
    private var previousSession: Activity? {
        activities.last { $0.type == .breastfeeding && !$0.isOngoing }
    }

    var body: some View {
        ZStack(alignment: .top) {
            BreastTheme.bg.ignoresSafeArea()
            BreastfeedGlow(side: session.map { BreastfeedLaps(session: $0).activeSide } ?? .left)
            if isClosing {
                Color.clear
            } else if let session {
                BreastfeedRunningContent(
                    baby: baby,
                    session: session,
                    previousSession: previousSession,
                    onBack: { dismiss() },
                    onTapSide: { tapSide($0, session: session) },
                    onPause: { togglePause(session) },
                    onDone: { finish(session) },
                    onDiscard: { discard(session) }
                )
            } else {
                noSession
            }
        }
        .foregroundStyle(BreastTheme.ink)
        .environment(\.colorScheme, .dark)
        .preferredColorScheme(.dark)
        .toolbar(.hidden, for: .navigationBar)
    }

    private var noSession: some View {
        VStack(alignment: .leading, spacing: 0) {
            BreastfeedBackButton { dismiss() }
            Spacer().frame(height: 22)
            BreastfeedBubble(text: String(localized: "bf_no_session \(baby.displayName)"))
            Spacer()
            BreastfeedBigButton(title: String(localized: "close")) { dismiss() }
            Spacer().frame(height: 28)
        }
        .padding(.horizontal, 26)
        .padding(.top, 14)
    }

    // MARK: - Actions

    private func tapSide(_ side: BreastSide, session: Activity) {
        let laps = BreastfeedLaps(session: session)
        if laps.isPaused {
            ActivityLogger.resumeBreastfeeding(session, side: side, context: modelContext)
        } else if laps.activeSide != side {
            ActivityLogger.switchBreastSide(session, to: side, context: modelContext)
        }
    }

    private func togglePause(_ session: Activity) {
        let laps = BreastfeedLaps(session: session)
        if laps.isPaused {
            ActivityLogger.resumeBreastfeeding(session, side: laps.activeSide, context: modelContext)
        } else {
            ActivityLogger.pauseBreastfeeding(session, context: modelContext)
        }
    }

    private func finish(_ session: Activity) {
        let laps = BreastfeedLaps(session: session)
        let total = laps.feedingSeconds(now: Date())
        isClosing = true
        if total < 5 {
            ActivityLogger.delete(session, context: modelContext)
            navigator.flash(String(localized: "bf_too_short"))
        } else {
            let minutes = max(1, Int((total / 60).rounded()))
            let sideLabel = ThreadFormat.sideLabel(laps.overallSide)
            ActivityLogger.finishBreastfeeding(session, baby: baby, context: modelContext)
            navigator.flash(String(localized: "bf_added \(sideLabel) \(minutes)"))
        }
        dismiss()
    }

    private func discard(_ session: Activity) {
        isClosing = true
        ActivityLogger.delete(session, context: modelContext)
        navigator.flash(String(localized: "bf_discarded"))
        dismiss()
    }
}

// MARK: - Lap arithmetic

/// Reads the session's laps once and answers every question the screen asks about them.
private struct BreastfeedLaps {
    let laps: [BreastfeedingLap]

    init(session: Activity) {
        let stored = session.breastfeedingLaps
        // Legacy sessions without laps: treat the whole session as one open stretch.
        laps = stored.isEmpty ? [BreastfeedingLap(side: session.breastSide ?? .left, startTime: session.startTime)] : stored
    }

    var activeSide: BreastSide { laps.last?.side ?? .left }
    var isPaused: Bool { laps.last?.endTime != nil }
    var closed: [BreastfeedingLap] { laps.filter { $0.endTime != nil } }
    var firstSide: BreastSide { laps.first?.side ?? .left }

    /// Number of times the side actually changed between consecutive stretches.
    var switches: Int {
        zip(laps, laps.dropFirst()).filter { $0.side != $1.side }.count
    }

    var overallSide: BreastSide {
        let sides = Set(laps.map(\.side))
        return sides.count == 1 ? (sides.first ?? .left) : .both
    }

    func feedingSeconds(now: Date) -> TimeInterval {
        laps.reduce(0) { $0 + max(0, ($1.endTime ?? now).timeIntervalSince($1.startTime)) }
    }

    func seconds(for side: BreastSide, now: Date) -> TimeInterval {
        laps.filter { $0.side == side }.reduce(0) { $0 + max(0, ($1.endTime ?? now).timeIntervalSince($1.startTime)) }
    }
}

// MARK: - Running session

private struct BreastfeedRunningContent: View {
    let baby: Baby
    let session: Activity
    let previousSession: Activity?
    let onBack: () -> Void
    let onTapSide: (BreastSide) -> Void
    let onPause: () -> Void
    let onDone: () -> Void
    let onDiscard: () -> Void

    var body: some View {
        let laps = BreastfeedLaps(session: session)
        VStack(alignment: .leading, spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        BreastfeedBackButton(action: onBack)
                        Spacer(minLength: 0)
                        LeonaSectionLabel(
                            laps.isPaused ? String(localized: "bf_status_paused") : String(localized: "bf_status_recording"),
                            size: 11, tracking: 0.14, color: BreastTheme.muted
                        )
                    }
                    Spacer().frame(height: 22)
                    BreastfeedBubble(text: hint(laps))
                    Spacer().frame(height: 26)

                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        let now = context.date
                        VStack(alignment: .leading, spacing: 0) {
                            LeonaSectionLabel(
                                laps.isPaused ? String(localized: "bf_paused_at") : String(localized: "bf_feeding_for"),
                                size: 11, tracking: 0.14, color: BreastTheme.muted
                            )
                            HStack(alignment: .firstTextBaseline, spacing: 10) {
                                Text(ThreadFormat.mmss(laps.feedingSeconds(now: now)))
                                    .font(.leona(70, .light))
                                    .leonaTracking(-0.05, size: 70)
                                    .monospacedDigit()
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.6)
                                Text(verbatim: laps.activeSide == .left ? "L" : "R")
                                    .font(.leona(15, .heavy))
                                    .foregroundStyle(.white)
                                    .padding(.vertical, 5)
                                    .padding(.horizontal, 11)
                                    .background(Color.vermilion)
                                    .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                            }
                            .padding(.top, 6)
                            Spacer().frame(height: 24)
                            HStack(spacing: 10) {
                                BreastfeedSideTile(side: .left, active: laps.activeSide == .left && !laps.isPaused, seconds: laps.seconds(for: .left, now: now)) { onTapSide(.left) }
                                BreastfeedSideTile(side: .right, active: laps.activeSide == .right && !laps.isPaused, seconds: laps.seconds(for: .right, now: now)) { onTapSide(.right) }
                            }
                        }
                    }

                    Spacer().frame(height: 16)
                    pauseButton(paused: laps.isPaused)
                    if !laps.closed.isEmpty {
                        lapsCard(laps.closed).padding(.top, 16)
                    }
                    Spacer().frame(height: 14)
                }
                .padding(.top, 14)
            }

            TimelineView(.periodic(from: .now, by: 1)) { context in
                let minutes = max(1, Int((laps.feedingSeconds(now: context.date) / 60).rounded()))
                BreastfeedBigButton(title: String(localized: "bf_done \(minutes)"), action: onDone)
            }
            Button {
                HapticManager.impact(.light)
                onDiscard()
            } label: {
                Text(String(localized: "bf_discard"))
                    .font(.leona(13, .bold))
                    .foregroundStyle(BreastTheme.muted)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
            .padding(.top, 14)
            Spacer().frame(height: 14)
        }
        .padding(.horizontal, 26)
        .animation(.easeOut(duration: 0.2), value: laps.closed.count)
    }

    private func hint(_ laps: BreastfeedLaps) -> String {
        let switches = laps.switches
        if switches == 1 { return String(localized: "bf_hint_switched_one") }
        if switches > 1 { return String(localized: "bf_hint_switched \(switches)") }
        if let previous = previousSession,
           let previousSide = previous.breastfeedingLaps.last?.side ?? previous.breastSide {
            return String(localized: "bf_hint_previous \(baby.displayName) \(ThreadFormat.sideLabel(previousSide)) \(ThreadFormat.clock(previous.startTime)) \(ThreadFormat.sideLabel(laps.firstSide))")
        }
        return String(localized: "bf_hint_first")
    }

    private func pauseButton(paused: Bool) -> some View {
        Button {
            onPause()
        } label: {
            Text(paused ? String(localized: "bf_resume") : String(localized: "bf_pause \(baby.displayName)"))
                .font(.leona(15, .heavy))
                .foregroundStyle(BreastTheme.accent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(BreastTheme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.leonaPress)
    }

    private func lapsCard(_ closed: [BreastfeedingLap]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            LeonaSectionLabel(String(localized: "bf_this_session"), size: 10, tracking: 0.12, color: BreastTheme.muted)
            ForEach(closed) { lap in
                HStack(spacing: 0) {
                    ColorTick(color: lap.side == .left ? .vermilion : BreastTheme.accent, height: 18)
                    Text(lap.side == .left ? String(localized: "breast_left") : String(localized: "breast_right"))
                        .font(.leona(14, .bold))
                        .foregroundStyle(BreastTheme.ink)
                        .padding(.leading, 11)
                    Spacer(minLength: 8)
                    Text(ThreadFormat.mmss(lap.duration ?? 0))
                        .font(.leona(14, .bold))
                        .monospacedDigit()
                        .foregroundStyle(BreastTheme.value)
                }
                .padding(.top, 10)
            }
        }
        .padding(.vertical, 15)
        .padding(.horizontal, 17)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(BreastTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

// MARK: - Pieces

private struct BreastfeedGlow: View {
    let side: BreastSide

    var body: some View {
        GeometryReader { geo in
            Circle()
                .fill(RadialGradient(colors: [Color.vermilion.opacity(0.3), .clear], center: .center, startRadius: 0, endRadius: 240))
                .frame(width: 480, height: 480)
                .scaleEffect(x: 1.33, y: 1)
                .position(x: geo.size.width * (side == .left ? 0.26 : 0.74), y: 0)
                .animation(.easeInOut(duration: 0.6), value: side)
        }
        .frame(height: 440)
        .clipped()
        .ignoresSafeArea(edges: .top)
        .allowsHitTesting(false)
    }
}

private struct BreastfeedBackButton: View {
    let action: () -> Void

    var body: some View {
        Button {
            HapticManager.impact(.light)
            action()
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 15, weight: .heavy))
                Text(String(localized: "thread_back"))
                    .font(.leona(15, .bold))
            }
            .foregroundStyle(BreastTheme.accent)
        }
        .buttonStyle(.plain)
    }
}

private struct BreastfeedBubble: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.leona(15, .semibold))
            .lineSpacing(3)
            .foregroundStyle(BreastTheme.ink)
            .padding(.vertical, 13)
            .padding(.horizontal, 16)
            .background(BreastTheme.surface)
            .clipShape(.theirsBubble)
            .frame(maxWidth: 330, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct BreastfeedSideTile: View {
    let side: BreastSide
    let active: Bool
    let seconds: TimeInterval
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text((side == .left ? String(localized: "breast_left") : String(localized: "breast_right")).uppercased())
                    .font(.leona(26, .heavy))
                    .leonaTracking(-0.03, size: 26)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .foregroundStyle(active ? Color.white : BreastTheme.sideInk)
                Text(ThreadFormat.mmss(seconds))
                    .font(.leona(12, .bold))
                    .monospacedDigit()
                    .foregroundStyle(active ? Color.white.opacity(0.75) : BreastTheme.sideSub)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 22)
            .background(active ? Color.vermilion : BreastTheme.sideOff)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(active ? Color.vermilion : BreastTheme.sideLine, lineWidth: 1.5)
            )
        }
        .buttonStyle(LeonaPressStyle(scale: 0.97))
        .animation(.easeOut(duration: 0.2), value: active)
    }
}

private struct BreastfeedBigButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button {
            HapticManager.impact(.medium)
            action()
        } label: {
            Text(title)
                .font(.leona(19, .heavy))
                .leonaTracking(-0.02, size: 19)
                .foregroundStyle(BreastTheme.bg)
                .lineLimit(1)
                .frame(maxWidth: .infinity)
                .frame(height: 70)
                .background(BreastTheme.ink)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(LeonaPressStyle(scale: 0.98))
    }
}
