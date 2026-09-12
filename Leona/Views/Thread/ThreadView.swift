import SwiftUI
import SwiftData

/// The thread: one conversation per baby where every entry is a message.
struct ThreadView: View {
    let baby: Baby

    @Environment(AppSettings.self) private var settings
    @Environment(CloudKitManager.self) private var cloudKit
    @Environment(SharingManager.self) private var sharing
    @Environment(ThreadNavigator.self) private var navigator
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase

    @Query private var allActivities: [Activity]

    @State private var tray: LogTrayState?
    @State private var snoozedUntil: Date?
    @State private var remarks: [LeonaRemark] = []
    @State private var lastSeen: Date?
    @State private var seenLoaded = false
    @FocusState private var composerFocused: Bool
    @State private var showConfetti = false

    init(baby: Baby) {
        self.baby = baby
        let id = baby.id
        _allActivities = Query(filter: #Predicate<Activity> { $0.baby?.id == id })
    }

    /// Everything the body derives from the activity list, computed once per evaluation.
    private struct Snapshot {
        let activities: [Activity]
        let totals: ThreadTotals
        let ongoingSleep: Activity?
        let ongoingBreastfeeding: Activity?
    }

    private func snapshot() -> Snapshot {
        let activities = allActivities.filter { !$0.isDeleted }
        return Snapshot(
            activities: activities,
            totals: ThreadTotals.compute(activities: activities, baby: baby),
            ongoingSleep: activities.first { $0.type == .sleep && $0.isOngoing },
            ongoingBreastfeeding: activities.first { $0.type == .breastfeeding && $0.isOngoing }
        )
    }

    var body: some View {
        let snap = snapshot()
        VStack(spacing: 0) {
            header(snap)
            totalsStrip(snap)
            messages(snap)
            if let tray {
                LogTrayView(state: Binding(get: { tray }, set: { self.tray = $0 }), baby: baby, onClose: { self.tray = nil }, onSend: send)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            composer(snap)
        }
        .leonaScreen()
        .animation(.easeOut(duration: 0.2), value: tray?.kind)
        .onAppear {
            loadSeen()
            remarks = LeonaRemarkStore.load(for: baby.id)
            checkMilestones()
        }
        .task { await loadSharingInfo() }
        .overlay {
            if showConfetti {
                ConfettiView()
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }
        }
        .onDisappear(perform: markSeen)
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { markSeen() }
        }
        // The tray freezes its value and bounds in display units when armed; a unit change
        // would otherwise send the old number through the new conversion.
        .onChange(of: settings.useMetric) { _, _ in tray = nil }
    }

    // MARK: - Header

    private func header(_ snap: Snapshot) -> some View {
        HStack(spacing: 11) {
            Button { navigator.go(.profile) } label: {
                BabyAvatar(baby: baby, size: 38, radius: 13)
            }
            .buttonStyle(.plain)

            Button { navigator.go(.profile) } label: {
                VStack(alignment: .leading, spacing: 1) {
                    Text(baby.displayName)
                        .font(.leona(18, .bold))
                        .leonaTracking(-0.025, size: 18)
                        .foregroundStyle(.tInk)
                    Text(presenceLine(ongoingSleep: snap.ongoingSleep))
                        .font(.leona(12, .semibold))
                        .foregroundStyle(snap.ongoingSleep != nil ? Color.lilac : Color.tMuted)
                        .lineLimit(1)
                }
            }
            .buttonStyle(.plain)

            Spacer(minLength: 0)

            HStack(spacing: 6) {
                LeonaIconButton(systemImage: "moon.fill", isOn: colorScheme == .dark, iconSize: 15) {
                    toggleNightTheme()
                }
                LeonaIconButton(systemImage: "chart.xyaxis.line", iconSize: 15) {
                    navigator.go(.insights(.trends))
                }
                LeonaIconButton(systemImage: "magnifyingglass", iconSize: 15) {
                    navigator.go(.search)
                }
            }
        }
        .padding(.top, 2)
        .padding(.horizontal, 18)
        .padding(.bottom, 12)
    }

    private func presenceLine(ongoingSleep: Activity?) -> String {
        if let sleep = ongoingSleep {
            return String(localized: "thread_presence_asleep \(ThreadFormat.durShort(Date().timeIntervalSince(sleep.startTime)))")
        }
        if baby.isShared {
            let partners = sharing.participants
                .filter { $0.acceptanceStatus == .accepted && $0.role != .owner }
                .compactMap { $0.userIdentity.nameComponents?.givenName }
            if !partners.isEmpty {
                return String(localized: "thread_presence_shared \(partners.joined(separator: " & "))")
            }
            if let owner = baby.ownerName, !owner.isEmpty {
                return String(localized: "thread_presence_shared \(owner)")
            }
            return String(localized: "thread_presence_shared_generic")
        }
        return baby.ageDescription
    }

    /// Dark ⇄ light peek. Turning dark off returns to "follow iOS" unless iOS itself is dark,
    /// in which case light is forced so the tap has a visible effect.
    private func toggleNightTheme() {
        settings.autoNightTheme = false
        if colorScheme == .dark {
            settings.colorScheme = AppSettings.systemPrefersDark ? .light : .system
        } else {
            settings.colorScheme = .dark
        }
    }

    // MARK: - Totals strip

    private func totalsStrip(_ snap: Snapshot) -> some View {
        let totals = snap.totals
        return Button { navigator.go(.insights(.trends)) } label: {
            HStack(spacing: 14) {
                totalItem(color: .vermilion, text: String(localized: "thread_feeds \(totals.feeds)"))
                totalItem(color: .lilac, text: ThreadFormat.durShort(totals.slept))
                totalItem(color: .moss, text: String(localized: "thread_diapers \(totals.diapers)"))
                Spacer(minLength: 0)
                Text(totals.nextLabel(asleep: snap.ongoingSleep != nil))
                    .font(.leona(12, .bold))
                    .foregroundStyle(.tMuted)
                    .lineLimit(1)
            }
            .padding(.vertical, 11)
            .padding(.horizontal, 14)
            .background(Color.tPinned)
            .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 18)
        .padding(.bottom, 10)
    }

    private func totalItem(color: Color, text: String) -> some View {
        HStack(spacing: 7) {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(color)
                .frame(width: 8, height: 8)
            Text(text)
                .font(.leona(13, .bold))
                .foregroundStyle(.tInk)
                .lineLimit(1)
        }
    }

    // MARK: - Messages

    /// Rows are laid out in a vertically flipped scroll view so the newest entry sits at the
    /// bottom and the list opens scrolled to the end, the way a conversation does.
    private func messages(_ snap: Snapshot) -> some View {
        let rows = ThreadBuilder.rows(activities: snap.activities, lastSeen: lastSeen, remarks: remarks)
        return ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 9) {
                footer(snap)
                    .flipped()
                ForEach(rows.reversed()) { row in
                    ThreadRowView(row: row, babyName: baby.displayName, onOpen: open(row:), onOpenSleep: { navigator.open(.sleep) }, onOpenBreast: { navigator.open(.breastfeeding) })
                        .flipped()
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 4)
        }
        .flipped()
        .scrollDismissesKeyboard(.interactively)
    }

    /// Leona's card, the "NOW" divider and the sync receipt — the bottom of the conversation.
    /// The card is re-evaluated every minute so it appears when a feed comes due and leaves
    /// when a snooze expires, without any other state change.
    private func footer(_ snap: Snapshot) -> some View {
        VStack(spacing: 9) {
            TimelineView(.periodic(from: .now, by: 60)) { context in
                if let advice = LeonaAdvisor.advice(
                    totals: snap.totals,
                    ongoingSleep: snap.ongoingSleep,
                    snoozedUntil: snoozedUntil,
                    enabled: settings.leonaSuggestions,
                    babyName: baby.displayName,
                    now: context.date
                ) {
                    LeonaSuggestionCard(
                        advice: advice,
                        babyName: baby.displayName,
                        onPrimary: handleLeonaPrimary,
                        onSecondary: handleLeonaSecondary,
                        onWhy: { navigator.go(.insights(.trends)) }
                    )
                }
            }
            TimelineView(.periodic(from: .now, by: 30)) { context in
                HStack(spacing: 10) {
                    Rectangle().fill(Color.vermilion.opacity(0.3)).frame(height: 1)
                    Text(String(localized: "thread_now \(ThreadFormat.clock(context.date))").uppercased())
                        .font(.leona(11, .heavy))
                        .leonaTracking(0.09, size: 11)
                        .foregroundStyle(.vermilion)
                    Rectangle().fill(Color.vermilion.opacity(0.3)).frame(height: 1)
                }
            }
            if let receipt {
                Button(action: refreshShared) {
                    Text(receipt)
                        .font(.leona(11, .semibold))
                        .foregroundStyle(.tMuted)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .padding(.horizontal, 8)
                        .padding(.bottom, 4)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var receipt: String? {
        guard baby.isShared, let date = cloudKit.lastSyncDate else { return nil }
        return String(localized: "thread_synced \(ThreadFormat.clock(date))")
    }

    private func open(row: ThreadRow) {
        if case .entry(let activity) = row.kind {
            navigator.go(.record(activity.id))
        }
    }

    // MARK: - Leona's suggestion

    private func handleLeonaPrimary(_ advice: LeonaAdvice) {
        switch advice.action {
        case .logBottle:
            let ml = snapshot().totals.predictedVolumeML
            // The remark lands just before the entry it led to.
            remember(advice, outcome: .logged, until: nil)
            ActivityLogger.logBottle(ml, kind: .formula, at: Date(), baby: baby, context: modelContext)
            snoozedUntil = nil
            navigator.flash(String(localized: "thread_added \(ThreadFormat.title(for: previewBottle(ml)))"))
        case .openSleep:
            navigator.open(.sleep)
        case .openBottleTray:
            arm(.bottle)
        case .none:
            break
        }
    }

    private func handleLeonaSecondary(_ advice: LeonaAdvice) {
        switch advice.secondary {
        case .snooze:
            let base = snapshot().totals.nextFeed ?? Date()
            let until = max(base, Date()).addingTimeInterval(20 * 60)
            snoozedUntil = until
            remember(advice, outcome: .snoozed, until: until)
        case .fixSleepStart:
            navigator.open(.sleep)
        case .none:
            break
        }
    }

    /// Keeps the answered suggestion as a message in the thread, one per occasion.
    private func remember(_ advice: LeonaAdvice, outcome: LeonaRemark.Outcome, until: Date?) {
        let now = Date()
        if let index = remarks.firstIndex(where: { $0.occasion == advice.occasion }) {
            remarks[index].date = now
            remarks[index].outcome = outcome
            remarks[index].until = until
        } else {
            remarks.append(LeonaRemark(occasion: advice.occasion, date: now, line: advice.line, outcome: outcome, until: until))
        }
        LeonaRemarkStore.save(remarks, for: baby.id)
    }

    private func previewBottle(_ ml: Double) -> Activity {
        let a = Activity(type: .formula)
        a.volumeML = ml
        return a
    }

    // MARK: - Composer

    private func composer(_ snap: Snapshot) -> some View {
        VStack(spacing: 11) {
            chips(snap)
            ThreadComposerBar(focus: $composerFocused, onPlus: { arm(.bottle) }, onSend: sendNote(_:))
                .padding(.bottom, 8)
        }
        .padding(.top, 12)
        .padding(.horizontal, 18)
        .overlay(alignment: .top) { Rectangle().fill(Color.tLine).frame(height: 1) }
    }

    private func chips(_ snap: Snapshot) -> some View {
        let asleep = snap.ongoingSleep != nil
        let feeding = snap.ongoingBreastfeeding
        let predicted = snap.totals.predictedVolumeML
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 7) {
                if settings.showFeedingTracking {
                    chip(String(localized: "thread_chip_bottle \(ThreadFormat.volume(predicted))"),
                         bg: tray?.kind == .bottle ? .vermilion : .tMine, ink: .white, weight: .heavy) { arm(.bottle) }
                }
                if settings.showBreastfeeding {
                    let label = feeding.map { String(localized: "thread_chip_feeding \(ThreadFormat.mmss($0.breastfeedingSeconds))") } ?? String(localized: "thread_chip_breast")
                    chip(label,
                         bg: feeding != nil ? .vermilion : (tray?.kind == .breast ? .tMine : .tChip),
                         ink: (feeding != nil || tray?.kind == .breast) ? .white : .tTheirsInk) {
                        if feeding != nil {
                            navigator.open(.breastfeeding)
                        } else {
                            startBreastfeeding()
                        }
                    }
                }
                if settings.showSleepTracking {
                    chip(asleep ? String(localized: "thread_chip_woke \(baby.displayName)") : String(localized: "thread_chip_sleep"),
                         bg: asleep ? .lilac : .tChip, ink: asleep ? .white : .tTheirsInk) { toggleSleep() }
                }
                if settings.showDiaperTracking {
                    chip(String(localized: "thread_chip_diaper"),
                         bg: tray?.kind == .diaper ? .tMine : .tChip, ink: tray?.kind == .diaper ? .white : .tTheirsInk) { arm(.diaper) }
                }
                if settings.showFeedingTracking {
                    chip(String(localized: "thread_chip_solid"),
                         bg: tray?.kind == .solid ? .tMine : .tChip, ink: tray?.kind == .solid ? .white : .tTheirsInk) { arm(.solid) }
                }
            }
        }
    }

    private func chip(_ title: String, bg: Color, ink: Color, weight: Font.Weight = .bold, action: @escaping () -> Void) -> some View {
        Button {
            HapticManager.impact(.light)
            action()
        } label: {
            Text(title)
                .font(.leona(13, weight))
                .foregroundStyle(ink)
                .lineLimit(1)
                .padding(.vertical, 9)
                .padding(.horizontal, 15)
                .background(bg)
                .clipShape(Capsule())
        }
        .buttonStyle(LeonaPressStyle(scale: 0.95))
    }

    // MARK: - Actions

    private func arm(_ kind: LogTrayState.Kind) {
        composerFocused = false
        if tray?.kind == kind {
            tray = nil
            return
        }
        tray = LogTrayState.make(kind: kind, predictedVolumeML: snapshot().totals.predictedVolumeML, lastBreastSide: lastBreastSide)
    }

    /// The side the last finished session ended on, so the next one can alternate.
    /// Sessions that switched sides store `.both` as their aggregate, so the last lap decides.
    private var lastBreastSide: BreastSide? {
        guard let last = allActivities
            .filter({ !$0.isDeleted && $0.type == .breastfeeding && !$0.isOngoing })
            .max(by: { $0.startTime < $1.startTime }) else { return nil }
        return last.breastfeedingLaps.last?.side ?? last.breastSide
    }

    private func send(_ state: LogTrayState) {
        let time = state.resolvedTime
        let activity: Activity
        switch state.kind {
        case .bottle:
            activity = ActivityLogger.logBottle(state.storageVolumeML, kind: state.bottleKind, at: time, baby: baby, context: modelContext)
        case .breast:
            activity = ActivityLogger.logBreastfeedManual(minutes: Int(state.value), side: state.side, endingAt: time, baby: baby, context: modelContext)
        case .solid:
            activity = ActivityLogger.logSolid(name: state.foodName, quantity: state.value, unit: state.foodUnit, at: time, baby: baby, context: modelContext)
        case .diaper:
            activity = ActivityLogger.logDiaper(state.diaperType, at: time, baby: baby, context: modelContext)
        }
        tray = nil
        snoozedUntil = nil
        navigator.flash(String(localized: "thread_added \(ThreadFormat.title(for: activity))"))
    }

    private func sendNote(_ text: String) {
        ActivityLogger.logNote(text, baby: baby, context: modelContext)
        navigator.flash(String(localized: "thread_note_added"))
    }

    private func toggleSleep() {
        if let sleep = snapshot().ongoingSleep {
            let duration = Date().timeIntervalSince(sleep.startTime)
            ActivityLogger.endSleep(sleep, context: modelContext)
            navigator.flash(String(localized: "thread_slept_added \(ThreadFormat.dur(duration))"))
        } else {
            tray = nil
            ActivityLogger.startSleep(baby: baby, context: modelContext)
            navigator.flash(String(localized: "thread_sleep_started \(ThreadFormat.clock(Date()))"))
        }
    }

    private func startBreastfeeding() {
        tray = nil
        let side: BreastSide = lastBreastSide == .left ? .right : .left
        ActivityLogger.startBreastfeeding(side: side, baby: baby, context: modelContext)
        navigator.open(.breastfeeding)
    }

    // MARK: - Shared thread helpers

    private func loadSharingInfo() async {
        guard baby.isShared else { return }
        await sharing.fetchShareInfo(for: baby)
    }

    private func refreshShared() {
        guard baby.isShared else { return }
        HapticManager.impact(.light)
        Task {
            await SyncEngine.shared.forcePullSharedBabies(context: modelContext)
            await sharing.fetchShareInfo(for: baby)
            navigator.flash(String(localized: "thread_refreshed"))
        }
    }

    // MARK: - Milestones (monthly birthdays in the first year, then yearly)

    private func checkMilestones() {
        guard baby.isBorn, !showConfetti else { return }
        let calendar = Calendar.current
        let today = Date()
        guard calendar.component(.day, from: baby.dateOfBirth) == calendar.component(.day, from: today) else { return }
        let parts = calendar.dateComponents([.year, .month], from: baby.dateOfBirth, to: today)
        let totalMonths = (parts.year ?? 0) * 12 + (parts.month ?? 0)
        let monthly = totalMonths >= 1 && totalMonths <= 11 && baby.isMonthBirthday
        let yearly = totalMonths >= 12 && baby.isBirthday
        guard monthly || yearly else { return }
        let key = "milestone-\(baby.id.uuidString)-\(calendar.startOfDay(for: today).timeIntervalSince1970)"
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        UserDefaults.standard.set(true, forKey: key)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            showConfetti = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 4) { showConfetti = false }
        }
    }

    // MARK: - Unread tracking

    private func loadSeen() {
        guard !seenLoaded else { return }
        seenLoaded = true
        lastSeen = settings.threadLastSeen(for: baby.id)
        if lastSeen == nil { settings.markThreadSeen(for: baby.id) }
    }

    private func markSeen() {
        settings.markThreadSeen(for: baby.id)
    }
}

// MARK: - Composer bar

/// Owns the draft so typing re-renders this bar only, not the whole thread.
private struct ThreadComposerBar: View {
    let focus: FocusState<Bool>.Binding
    let onPlus: () -> Void
    let onSend: (String) -> Void

    @State private var draft = ""

    var body: some View {
        HStack(spacing: 10) {
            Button(action: onPlus) {
                Image(systemName: "plus")
                    .font(.system(size: 17, weight: .heavy))
                    .foregroundStyle(.tMuted)
                    .frame(width: 42, height: 42)
                    .background(Color.tChip)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.leonaPress)

            TextField(String(localized: "thread_note_placeholder"), text: $draft, axis: .vertical)
                .lineLimit(1...4)
                .font(.leona(15))
                .foregroundStyle(.tInk)
                .focused(focus)
                .submitLabel(.send)
                .onSubmit(send)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.tSurface)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Color.tLine, lineWidth: 1))

            Button(action: send) {
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(draft.trimmingCharacters(in: .whitespaces).isEmpty ? Color.tMine : Color.vermilion)
                    .clipShape(Circle())
            }
            .buttonStyle(LeonaPressStyle(scale: 0.94))
        }
    }

    private func send() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        onSend(text)
        draft = ""
    }
}

// MARK: - Flip helper for the bottom-anchored conversation

private extension View {
    func flipped() -> some View {
        scaleEffect(x: 1, y: -1, anchor: .center)
    }
}
