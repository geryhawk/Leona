import SwiftUI
import SwiftData

/// One entry of the thread, in full, with edit and delete.
struct RecordDetailView: View {
    let activity: Activity

    @Environment(ThreadNavigator.self) private var navigator
    @Environment(\.modelContext) private var modelContext
    @Query private var allActivities: [Activity]

    @State private var showEditor = false
    @State private var showDeleteConfirm = false

    init(activity: Activity) {
        self.activity = activity
    }

    var body: some View {
        Group {
            if activity.isDeleted {
                Color.tCanvas
                    .onAppear { navigator.backToThread() }
            } else {
                content
            }
        }
        .leonaScreen()
    }

    private var content: some View {
        VStack(spacing: 0) {
            SubScreenHeader(title: String(localized: "record_title")) { navigator.backToThread() }
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    heroCard
                    detailsGroup
                    actionRow
                }
                .padding(.horizontal, 18)
                .padding(.top, 16)
                .padding(.bottom, 20)
            }
        }
        .sheet(isPresented: $showEditor) {
            RecordEditorView(activity: activity)
        }
        .confirmationDialog(
            String(localized: "delete_activity_confirm"),
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button(String(localized: "delete"), role: .destructive) { deleteRecord() }
        }
    }

    // MARK: - Hero

    private var metaLine: String {
        let day = activity.startTime.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))
        return "\(day) · \(ThreadFormat.clock(activity.startTime))"
    }

    private var heroCard: some View {
        PlumCard(padding: 19) {
            VStack(alignment: .leading, spacing: 0) {
                Text(ThreadFormat.kindLabel(for: activity).uppercased())
                    .font(.leona(11, .heavy))
                    .leonaTracking(0.12, size: 11)
                    .foregroundStyle(Color.white.opacity(0.6))
                Text(ThreadFormat.title(for: activity))
                    .font(.leona(27, .bold))
                    .leonaTracking(-0.035, size: 27)
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 8)
                Text(metaLine)
                    .font(.leona(14))
                    .foregroundStyle(Color.white.opacity(0.72))
                    .padding(.top, 6)
            }
            .padding(.horizontal, 2)
        }
    }

    // MARK: - Details

    private var babyName: String {
        activity.baby?.displayName ?? String(localized: "baby")
    }

    private var detailsGroup: some View {
        LeonaGroup {
            detailRow(String(localized: "record_started"), ThreadFormat.clock(activity.startTime))
            if let end = activity.endTime {
                detailRow(String(localized: "record_ended"), ThreadFormat.clock(end))
            }
            detailRow(String(localized: "record_logged_by"), activity.authorDisplayName)
            if let comparison = comparisonLine {
                detailRow(String(localized: "record_against_average \(babyName)"), comparison)
            }
            if activity.type != .note, let note = activity.noteText, !note.isEmpty {
                detailRow(String(localized: "record_note"), note)
            }
        }
    }

    private func detailRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(label)
                .font(.leona(14))
                .foregroundStyle(.tMuted)
            Spacer(minLength: 0)
            Text(value)
                .font(.leona(15, .bold))
                .foregroundStyle(.tInk)
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, 15)
        .padding(.horizontal, 17)
    }

    // MARK: - Against the baby's own average

    /// Other finished entries of this baby, excluding this one.
    private var siblings: [Activity] {
        guard let babyID = activity.baby?.id else { return [] }
        return allActivities.filter { $0.baby?.id == babyID && $0.id != activity.id && !$0.isOngoing }
    }

    private var comparisonLine: String? {
        switch activity.type {
        case .formula, .momsMilk:
            return bottleComparison
        case .sleep:
            return durationComparison(mine: activity.duration)
        case .breastfeeding:
            return durationComparison(mine: activity.breastfeedingSeconds)
        case .diaper:
            return diaperComparison
        case .note, .solidFood:
            return nil
        }
    }

    private var bottleComparison: String? {
        guard let mine = activity.volumeML, mine > 0 else { return nil }
        let cutoff = activity.startTime.addingTimeInterval(-7 * 86_400)
        let volumes = siblings
            .filter { $0.type == activity.type && $0.startTime >= cutoff && $0.startTime <= activity.startTime }
            .compactMap(\.volumeML)
            .filter { $0 > 0 }
        guard !volumes.isEmpty else { return String(localized: "record_no_baseline") }
        let average = volumes.reduce(0, +) / Double(volumes.count)
        let diff = mine - average
        if abs(diff) < max(5, average * 0.05) {
            return String(localized: "record_on_average")
        }
        let amount = UnitConversion.formatVolume(abs(diff))
        return diff < 0
            ? String(localized: "record_under_average \(amount)")
            : String(localized: "record_over_average \(amount)")
    }

    /// Compares a duration with the average of the last seven of the same kind before it.
    private func durationComparison(mine: TimeInterval?) -> String? {
        guard let mine, mine > 0 else { return nil }
        let earlier = siblings
            .filter { $0.startTime <= activity.startTime }
            .sorted { $0.startTime > $1.startTime }
        let sameKind = earlier.filter { $0.type == activity.type }.prefix(7)
        let durations: [TimeInterval] = sameKind.map { entry in
            entry.type == .breastfeeding ? entry.breastfeedingSeconds : (entry.duration ?? 0)
        }.filter { $0 > 0 }
        guard !durations.isEmpty else { return String(localized: "record_no_baseline") }
        let average = durations.reduce(0, +) / Double(durations.count)
        let diff = mine - average
        if abs(diff) < 300 {
            return String(localized: "record_usual_length")
        }
        let text = ThreadFormat.dur(abs(diff))
        return diff > 0
            ? String(localized: "record_longer_than_usual \(text)")
            : String(localized: "record_shorter_than_usual \(text)")
    }

    private var diaperComparison: String? {
        let previous = siblings
            .filter { $0.type == .diaper && $0.startTime < activity.startTime }
            .sorted { $0.startTime > $1.startTime }
        guard let last = previous.first else { return String(localized: "record_no_baseline") }
        let gap = activity.startTime.timeIntervalSince(last.startTime)
        let window = Array(previous.prefix(8))
        var gaps: [TimeInterval] = []
        if window.count > 1 {
            for index in 0..<(window.count - 1) {
                gaps.append(window[index].startTime.timeIntervalSince(window[index + 1].startTime))
            }
        }
        guard !gaps.isEmpty else { return String(localized: "record_no_baseline") }
        let average = gaps.reduce(0, +) / Double(gaps.count)
        let diff = gap - average
        if abs(diff) < 900 {
            return String(localized: "record_usual_spacing")
        }
        let text = ThreadFormat.dur(abs(diff))
        return diff < 0
            ? String(localized: "record_sooner_than_usual \(text)")
            : String(localized: "record_later_than_usual \(text)")
    }

    // MARK: - Actions

    private var actionRow: some View {
        HStack(spacing: 10) {
            RecordActionButton(title: String(localized: "edit"), style: .plum) {
                showEditor = true
            }
            RecordActionButton(title: String(localized: "delete"), style: .outline) {
                showDeleteConfirm = true
            }
        }
    }

    private func deleteRecord() {
        ActivityLogger.delete(activity, context: modelContext)
        navigator.flash(String(localized: "record_removed_toast"))
        navigator.backToThread()
    }
}

// MARK: - Full-width action button

private struct RecordActionButton: View {
    enum Style { case plum, outline }

    let title: String
    let style: Style
    let action: () -> Void

    var body: some View {
        Button {
            HapticManager.impact(.light)
            action()
        } label: {
            Text(title)
                .font(.leona(15, .heavy))
                .foregroundStyle(style == .plum ? Color.white : Color.vermilion)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(style == .plum ? Color.tMine : Color.tSurface)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.vermilion, lineWidth: style == .outline ? 1.5 : 0)
                )
        }
        .buttonStyle(.leonaPress)
    }
}
