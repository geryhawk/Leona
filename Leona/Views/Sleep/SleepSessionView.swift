import SwiftUI
import SwiftData

/// Full-screen cover shown while a sleep is running. Dark plum world, live timer,
/// the current stretch against the baby's own average, and the "awake" button that
/// posts the sleep to the thread. With no running sleep it becomes the past-sleep form.
struct SleepSessionView: View {
    let baby: Baby

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(ThreadNavigator.self) private var navigator

    @Query private var activities: [Activity]

    @State private var showFixStart = false
    @State private var showPastSleep = false
    @State private var pastStart = Date().addingTimeInterval(-3600)
    @State private var pastEnd = Date()
    @State private var isClosing = false

    init(baby: Baby) {
        self.baby = baby
        let id = baby.id
        _activities = Query(filter: #Predicate<Activity> { $0.baby?.id == id }, sort: \Activity.startTime)
    }

    // MARK: - Data

    private var ongoing: Activity? {
        activities.first { $0.type == .sleep && $0.isOngoing }
    }

    /// Finished sleeps, oldest first.
    private var completed: [Activity] {
        activities.filter { $0.type == .sleep && !$0.isOngoing && $0.endTime != nil }
    }

    /// Mean length of the last seven finished sleeps.
    private var averageDuration: TimeInterval? {
        let recent = completed.suffix(7).compactMap(\.duration)
        guard !recent.isEmpty else { return nil }
        return recent.reduce(0, +) / Double(recent.count)
    }

    private var observation: String {
        let durations = completed.compactMap(\.duration)
        guard durations.count >= 6 else { return String(localized: "sleep_obs_thin \(baby.displayName)") }
        let recent = durations.suffix(3)
        let prior = durations.dropLast(3).suffix(3)
        let recentAvg = recent.reduce(0, +) / Double(recent.count)
        let priorAvg = prior.reduce(0, +) / Double(prior.count)
        let deltaMinutes = Int(((recentAvg - priorAvg) / 60).rounded())
        if deltaMinutes >= 5 { return String(localized: "sleep_obs_longer \(deltaMinutes)") }
        if deltaMinutes <= -5 { return String(localized: "sleep_obs_shorter \(-deltaMinutes)") }
        return String(localized: "sleep_obs_steady")
    }

    private func sleptLast24h(now: Date) -> TimeInterval {
        let windowStart = now.addingTimeInterval(-86_400)
        var total: TimeInterval = 0
        for sleep in completed {
            guard let end = sleep.endTime else { continue }
            let overlap = min(end, now).timeIntervalSince(max(sleep.startTime, windowStart))
            if overlap > 0 { total += overlap }
        }
        if let ongoing {
            total += now.timeIntervalSince(max(ongoing.startTime, windowStart))
        }
        return max(0, total)
    }

    private var napsToday: Int {
        completed.filter { $0.endTime?.isToday == true }.count
    }

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .top) {
            SleepTheme.bg.ignoresSafeArea()
            SleepGlow()
            if isClosing {
                Color.clear
            } else if let sleep = ongoing {
                runningContent(sleep)
            } else {
                pastSleepContent
            }
        }
        .foregroundStyle(SleepTheme.ink)
        .environment(\.colorScheme, .dark)
        .preferredColorScheme(.dark)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showFixStart) {
            if let sleep = ongoing {
                SleepFixStartSheet(initial: sleep.startTime) { date in
                    ActivityLogger.updateStart(sleep, to: date, context: modelContext)
                    HapticManager.success()
                    showFixStart = false
                }
            }
        }
        .sheet(isPresented: $showPastSleep) {
            SleepSheetChrome(title: String(localized: "sleep_log_past"), primary: String(localized: "save"), primaryEnabled: pastEnd > pastStart) {
                savePastSleep()
                showPastSleep = false
            } onCancel: {
                showPastSleep = false
            } content: {
                SleepPastForm(start: $pastStart, end: $pastEnd)
            }
        }
    }

    // MARK: - Running session

    private func runningContent(_ sleep: Activity) -> some View {
        let name = baby.displayName
        return VStack(alignment: .leading, spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    backButton
                    Spacer().frame(height: 34)
                    SleepBubble(text: String(localized: "sleep_went_down \(name) \(ThreadFormat.clock(sleep.startTime)) \(name)"))
                    Spacer().frame(height: 30)

                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        let elapsed = context.date.timeIntervalSince(sleep.startTime)
                        VStack(alignment: .leading, spacing: 0) {
                            LeonaSectionLabel(String(localized: "sleep_asleep_for"), size: 11, tracking: 0.14, color: SleepTheme.muted)
                            Text(ThreadFormat.timer(elapsed))
                                .font(.leona(72, .light))
                                .leonaTracking(-0.05, size: 72)
                                .monospacedDigit()
                                .lineLimit(1)
                                .minimumScaleFactor(0.6)
                                .padding(.top, 8)
                            Spacer().frame(height: 28)
                            if let average = averageDuration {
                                averageCard(elapsed: elapsed, average: average)
                                Spacer().frame(height: 14)
                            }
                            HStack(spacing: 10) {
                                SleepTile(label: String(localized: "sleep_last_24h"), value: ThreadFormat.durShort(sleptLast24h(now: context.date)))
                                SleepTile(label: String(localized: "sleep_naps_today"), value: "\(napsToday)")
                            }
                        }
                    }
                    Spacer().frame(height: 14)
                }
                .padding(.top, 14)
            }

            SleepBigButton(title: String(localized: "sleep_awake_cta \(name)")) { wake(sleep) }
            HStack(spacing: 22) {
                footerLink(String(localized: "sleep_fix_start")) { showFixStart = true }
                footerLink(String(localized: "sleep_log_past")) {
                    pastStart = Date().addingTimeInterval(-3600)
                    pastEnd = Date()
                    showPastSleep = true
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 14)
            Spacer().frame(height: 14)
        }
        .padding(.horizontal, 26)
    }

    private var backButton: some View {
        Button {
            HapticManager.impact(.light)
            dismiss()
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "chevron.left").font(.system(size: 15, weight: .heavy))
                Text(String(localized: "thread_back")).font(.leona(15, .bold))
            }
            .foregroundStyle(SleepTheme.back)
        }
        .buttonStyle(.plain)
    }

    private func footerLink(_ title: String, action: @escaping () -> Void) -> some View {
        Button {
            HapticManager.impact(.light)
            action()
        } label: {
            Text(title).font(.leona(13, .bold)).foregroundStyle(SleepTheme.muted)
        }
        .buttonStyle(.plain)
    }

    private func averageCard(elapsed: TimeInterval, average: TimeInterval) -> some View {
        let fraction = average > 0 ? min(1, (elapsed / average) * 0.52) : 0
        return VStack(alignment: .leading, spacing: 0) {
            LeonaSectionLabel(String(localized: "sleep_against_average \(baby.displayName)"), size: 11, tracking: 0.12, color: SleepTheme.muted)
            GeometryReader { geo in
                let width = geo.size.width
                ZStack(alignment: .topLeading) {
                    Capsule().fill(SleepTheme.track).frame(width: width, height: 10).offset(y: 5)
                    Capsule().fill(SleepTheme.accent).frame(width: max(10, width * fraction), height: 10).offset(y: 5)
                    Rectangle().fill(SleepTheme.marker).frame(width: 2, height: 20).offset(x: width * 0.52 - 1)
                    LeonaSectionLabel(String(localized: "sleep_usual \(ThreadFormat.durShort(average))"), size: 10, tracking: 0.02, color: SleepTheme.muted)
                        .fixedSize()
                        .position(x: width * 0.52, y: 28)
                }
            }
            .frame(height: 34)
            .padding(.top, 15)
            Text(observation)
                .font(.leona(13))
                .lineSpacing(3)
                .foregroundStyle(SleepTheme.body)
                .padding(.top, 14)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(SleepTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    // MARK: - No running sleep: log a past one with the same chrome

    private var pastSleepContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    backButton
                    Spacer().frame(height: 34)
                    SleepBubble(text: String(localized: "sleep_no_running \(baby.displayName)"))
                    Spacer().frame(height: 30)
                    LeonaSectionLabel(String(localized: "sleep_log_past"), size: 11, tracking: 0.14, color: SleepTheme.muted)
                    SleepPastForm(start: $pastStart, end: $pastEnd)
                        .padding(18)
                        .background(SleepTheme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .padding(.top, 10)
                    Spacer().frame(height: 14)
                }
                .padding(.top, 14)
            }
            SleepBigButton(title: String(localized: "sleep_save_past"), enabled: pastEnd > pastStart) {
                savePastSleep()
                dismiss()
            }
            Spacer().frame(height: 14)
        }
        .padding(.horizontal, 26)
    }

    // MARK: - Actions

    private func wake(_ sleep: Activity) {
        let duration = Date().timeIntervalSince(sleep.startTime)
        isClosing = true
        ActivityLogger.endSleep(sleep, context: modelContext)
        navigator.flash(String(localized: "sleep_slept_added \(ThreadFormat.dur(duration))"))
        dismiss()
    }

    private func savePastSleep() {
        guard pastEnd > pastStart else { return }
        ActivityLogger.logPastSleep(from: pastStart, to: pastEnd, baby: baby, context: modelContext)
        navigator.flash(String(localized: "sleep_slept_added \(ThreadFormat.dur(pastEnd.timeIntervalSince(pastStart)))"))
    }
}

// MARK: - Pieces

private struct SleepGlow: View {
    var body: some View {
        GeometryReader { geo in
            Circle()
                .fill(RadialGradient(colors: [SleepTheme.accent.opacity(0.28), .clear], center: .center, startRadius: 0, endRadius: 240))
                .frame(width: 480, height: 480)
                .scaleEffect(x: 1.33, y: 1)
                .position(x: geo.size.width * 0.72, y: 0)
        }
        .frame(height: 420)
        .clipped()
        .ignoresSafeArea(edges: .top)
        .allowsHitTesting(false)
    }
}

private struct SleepBubble: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.leona(16, .semibold))
            .lineSpacing(4)
            .foregroundStyle(SleepTheme.ink)
            .padding(.vertical, 14)
            .padding(.horizontal, 17)
            .background(SleepTheme.surface)
            .clipShape(.theirsBubble)
            .frame(maxWidth: 320, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct SleepTile: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            LeonaSectionLabel(label, size: 10, tracking: 0.12, color: SleepTheme.muted)
            Text(value)
                .font(.leona(23, .bold))
                .foregroundStyle(SleepTheme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(.vertical, 15)
        .padding(.horizontal, 17)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(SleepTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct SleepBigButton: View {
    let title: String
    var enabled = true
    let action: () -> Void

    var body: some View {
        Button {
            guard enabled else { return }
            HapticManager.impact(.medium)
            action()
        } label: {
            Text(title)
                .font(.leona(19, .heavy))
                .leonaTracking(-0.02, size: 19)
                .foregroundStyle(SleepTheme.bg)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity)
                .frame(height: 70)
                .background(SleepTheme.ink.opacity(enabled ? 1 : 0.45))
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(LeonaPressStyle(scale: 0.98))
    }
}

/// Start / end pickers shared by the past-sleep sheet and the no-session screen.
private struct SleepPastForm: View {
    @Binding var start: Date
    @Binding var end: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            row(String(localized: "fell_asleep"), selection: $start)
            Rectangle().fill(SleepTheme.track).frame(height: 1)
            row(String(localized: "woke_up"), selection: $end)
            if end > start {
                Text(ThreadFormat.dur(end.timeIntervalSince(start)))
                    .font(.leona(13, .bold))
                    .foregroundStyle(SleepTheme.accent)
            } else {
                Text(String(localized: "sleep_invalid_range"))
                    .font(.leona(13, .bold))
                    .foregroundStyle(.vermilion)
            }
        }
    }

    private func row(_ title: String, selection: Binding<Date>) -> some View {
        HStack {
            Text(title)
                .font(.leona(14, .semibold))
                .foregroundStyle(SleepTheme.body)
            Spacer(minLength: 8)
            DatePicker("", selection: selection, in: ...Date(), displayedComponents: [.date, .hourAndMinute])
                .datePickerStyle(.compact)
                .labelsHidden()
                .tint(SleepTheme.accent)
        }
    }
}

private struct SleepFixStartSheet: View {
    let onSave: (Date) -> Void
    @State private var date: Date
    @Environment(\.dismiss) private var dismiss

    init(initial: Date, onSave: @escaping (Date) -> Void) {
        self.onSave = onSave
        _date = State(initialValue: initial)
    }

    var body: some View {
        SleepSheetChrome(title: String(localized: "sleep_fix_start"), primary: String(localized: "save"), primaryEnabled: true) {
            onSave(min(date, Date()))
        } onCancel: {
            dismiss()
        } content: {
            DatePicker("", selection: $date, in: ...Date(), displayedComponents: [.date, .hourAndMinute])
                .datePickerStyle(.wheel)
                .labelsHidden()
                .tint(SleepTheme.accent)
                .frame(maxWidth: .infinity)
        }
    }
}

/// Dark sheet with its own title row: Cancel · Title · Save.
private struct SleepSheetChrome<Content: View>: View {
    let title: String
    let primary: String
    var primaryEnabled = true
    let onPrimary: () -> Void
    let onCancel: () -> Void
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: onCancel) {
                    Text(String(localized: "cancel"))
                        .font(.leona(15, .bold))
                        .foregroundStyle(SleepTheme.muted)
                }
                .buttonStyle(.plain)
                Spacer(minLength: 0)
                Text(title)
                    .font(.leona(16, .bold))
                    .leonaTracking(-0.02, size: 16)
                    .foregroundStyle(SleepTheme.ink)
                Spacer(minLength: 0)
                Button {
                    guard primaryEnabled else { return }
                    HapticManager.impact(.medium)
                    onPrimary()
                } label: {
                    Text(primary)
                        .font(.leona(15, .heavy))
                        .foregroundStyle(primaryEnabled ? SleepTheme.accent : SleepTheme.muted)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .frame(height: 54)
            .overlay(alignment: .bottom) { Rectangle().fill(SleepTheme.track).frame(height: 1) }

            content
                .padding(.horizontal, 20)
                .padding(.top, 18)
            Spacer(minLength: 0)
        }
        .foregroundStyle(SleepTheme.ink)
        .background(SleepTheme.surface.ignoresSafeArea())
        .environment(\.colorScheme, .dark)
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}
