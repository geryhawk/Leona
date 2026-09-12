import SwiftUI
import SwiftData

// MARK: - Wording shared by the health screens

extension HealthRecord {
    /// "14 Feb → 18 Feb" or "Since 14 Feb"
    var healthRangeText: String {
        let start = startDate.formatted(.dateTime.day().month(.abbreviated))
        if let endDate {
            return "\(start) → \(endDate.formatted(.dateTime.day().month(.abbreviated)))"
        }
        return String(localized: "health_since \(start)")
    }

    /// "4 days" or "same day"
    var healthDurationText: String {
        let days = durationDays ?? 0
        return days <= 0 ? String(localized: "health_same_day") : String(localized: "health_days \(days)")
    }

    /// "Since 19 Feb. Two symptoms, no fever." plus a short note when there is one.
    var healthSummaryText: String {
        let since = startDate.formatted(.dateTime.day().month(.abbreviated))
        let symptomsText: String
        switch symptoms.count {
        case 0: symptomsText = String(localized: "health_summary_no_symptoms")
        case 1: symptomsText = String(localized: "health_summary_one_symptom")
        default: symptomsText = String(localized: "health_summary_symptoms \(symptoms.count)")
        }
        let feverText: String
        if let latest = latestTemperature {
            let reading = UnitConversion.formatTemp(latest)
            if latest >= 38.0 {
                feverText = String(localized: "health_summary_fever \(reading)")
            } else if latest >= 37.5 {
                feverText = String(localized: "health_summary_warm \(reading)")
            } else {
                feverText = String(localized: "health_summary_no_fever \(reading)")
            }
        } else {
            feverText = String(localized: "health_summary_no_temp")
        }
        var text = String(localized: "health_summary_line \(since) \(symptomsText) \(feverText)")
        let note = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        if !note.isEmpty, note.count <= 90 { text += " " + note }
        return text
    }
}

// MARK: - Screen

struct HealthView: View {
    let baby: Baby

    @Environment(\.modelContext) private var modelContext
    @Environment(ThreadNavigator.self) private var navigator
    @Query(sort: \HealthRecord.startDate, order: .reverse) private var allRecords: [HealthRecord]
    @State private var sheet: HealthSheet?

    private enum HealthSheet: Identifiable {
        case add
        case detail(HealthRecord)

        var id: String {
            switch self {
            case .add: return "add"
            case .detail(let record): return record.id.uuidString
            }
        }
    }

    private var records: [HealthRecord] { allRecords.filter { $0.baby?.id == baby.id } }
    private var ongoing: [HealthRecord] { records.filter(\.isOngoing) }
    private var history: [HealthRecord] { records.filter { !$0.isOngoing } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if let pinned = ongoing.first {
                    pinnedCard(pinned)
                }
                ForEach(Array(ongoing.dropFirst())) { record in
                    recordRow(record)
                }

                HStack {
                    LeonaSectionLabel(String(localized: "health_history_short"))
                    Spacer(minLength: 8)
                    LeonaSmallButton(title: String(localized: "health_log_short")) { sheet = .add }
                }
                .padding(.top, ongoing.isEmpty ? 0 : 4)

                if history.isEmpty {
                    emptyBubble
                } else {
                    ForEach(history) { record in
                        recordRow(record)
                    }
                }

                HealthVaccinationCard(baby: baby)
                    .padding(.top, 4)
            }
            .padding(EdgeInsets(top: 4, leading: 18, bottom: 20, trailing: 18))
        }
        .scrollIndicators(.hidden)
        .refreshable { await refreshSharedData() }
        .sheet(item: $sheet) { sheet in
            switch sheet {
            case .add: HealthEntryView(baby: baby)
            case .detail(let record): HealthDetailView(record: record)
            }
        }
    }

    // MARK: - Pinned record

    private func pinnedCard(_ record: HealthRecord) -> some View {
        PlumCard(padding: 17) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 8) {
                    PulseDot(color: .breastDot, size: 7)
                    Text(String(localized: "health_pinned_active_day \((record.durationDays ?? 0) + 1)").uppercased())
                        .font(.leona(11, .heavy))
                        .leonaTracking(0.12, size: 11)
                        .foregroundStyle(.highlight)
                }
                Text(record.illnessType.displayName)
                    .font(.leona(25, .bold))
                    .leonaTracking(-0.03, size: 25)
                    .padding(.top, 9)
                Text(record.healthSummaryText)
                    .font(.leona(14))
                    .lineSpacing(4)
                    .foregroundStyle(.white.opacity(0.78))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 7)
                HStack(spacing: 8) {
                    LeonaSmallButton(title: String(localized: "health_open_record"), tone: .vermilion, fontSize: 13, vertical: 10, horizontal: 16, radius: 12) {
                        sheet = .detail(record)
                    }
                    LeonaSmallButton(title: String(localized: "health_mark_resolved_short"), tone: .ghost, fontSize: 13, vertical: 10, horizontal: 16, radius: 12) {
                        resolve(record)
                    }
                }
                .padding(.top, 14)
            }
            .padding(.horizontal, 2)
        }
    }

    private func resolve(_ record: HealthRecord) {
        record.endDate = Date()
        record.updatedAt = Date()
        ActivityLogger.save(modelContext)
        NotificationCenter.default.post(name: .shouldPushLocalChanges, object: nil)
        HapticManager.success()
        navigator.flash(String(localized: "health_resolved_toast \(record.illnessType.displayName)"))
    }

    // MARK: - Rows

    private func recordRow(_ record: HealthRecord) -> some View {
        Button {
            HapticManager.selection()
            sheet = .detail(record)
        } label: {
            HStack(spacing: 12) {
                ColorTick(color: record.illnessType.color, height: 32)
                VStack(alignment: .leading, spacing: 1) {
                    Text(record.illnessType.displayName)
                        .font(.leona(15, .bold))
                        .foregroundStyle(.tTheirsInk)
                    Text(record.healthRangeText)
                        .font(.leona(12))
                        .foregroundStyle(.tMuted)
                }
                Spacer(minLength: 8)
                Text(record.healthDurationText)
                    .font(.leona(12, .bold))
                    .foregroundStyle(.tMuted)
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 16)
            .background(Color.tTheirs)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.leonaPress)
    }

    // MARK: - Empty state

    private var emptyBubble: some View {
        LeonaTintCard(padding: EdgeInsets(top: 14, leading: 17, bottom: 14, trailing: 17), asBubble: true) {
            VStack(alignment: .leading, spacing: 7) {
                LeonaCardHeader()
                Text(String(localized: "health_empty_bubble \(baby.displayName)"))
                    .font(.leona(15, .medium))
                    .lineSpacing(4)
                    .foregroundStyle(.tInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.trailing, 34)
    }

    private func refreshSharedData() async {
        guard baby.isShared else { return }
        await SyncEngine.shared.forcePullSharedBabies(context: modelContext)
    }
}
