import SwiftUI
import SwiftData

// MARK: - Metric

enum GrowthMetric: String, CaseIterable, Identifiable {
    case weight, height, head

    var id: String { rawValue }

    var title: String {
        switch self {
        case .weight: return String(localized: "growth_weight")
        case .height: return String(localized: "growth_height")
        case .head: return String(localized: "growth_head")
        }
    }

    var unit: String {
        self == .weight ? UnitConversion.weightUnit : UnitConversion.heightUnit
    }

    /// The stored (metric) value of this measurement on a record.
    func storedValue(of record: GrowthRecord) -> Double? {
        switch self {
        case .weight: return record.weightKg
        case .height: return record.heightCm
        case .head: return record.headCircumferenceCm
        }
    }

    /// Stored value → display unit.
    func display(_ stored: Double) -> Double {
        self == .weight ? UnitConversion.displayWeight(stored) : UnitConversion.displayHeight(stored)
    }

    func format(_ displayValue: Double) -> String {
        String(format: self == .weight ? "%.2f" : "%.1f", displayValue)
    }

    func percentiles(gender: BabyGender) -> [WHOPercentilePoint] {
        switch self {
        case .weight: return WHODataService.weightPercentiles(gender: gender)
        case .height: return WHODataService.heightPercentiles(gender: gender)
        case .head: return WHODataService.headCircumferencePercentiles(gender: gender)
        }
    }

    func percentile(value: Double, ageInMonths: Double, gender: BabyGender) -> Int? {
        WHODataService.calculatePercentile(value: value, ageInMonths: max(0, ageInMonths), data: percentiles(gender: gender))
            .map { Int($0.rounded()) }
    }
}

// MARK: - Age wording

enum GrowthAge {
    static func months(from birth: Date, to date: Date) -> Double {
        let components = Calendar.current.dateComponents([.month, .day], from: birth, to: date)
        return Double(components.month ?? 0) + Double(components.day ?? 0) / 30.44
    }

    /// "Birth", "3 weeks", "3 months", "1 year, 2 months"
    static func phrase(from birth: Date, to date: Date) -> String {
        let calendar = Calendar.current
        let days = calendar.dateComponents([.day], from: birth, to: date).day ?? 0
        if days <= 0 { return String(localized: "growth_age_birth") }
        if days < 7 { return String(localized: "growth_age_in_days \(days)") }
        let parts = calendar.dateComponents([.year, .month], from: birth, to: date)
        let years = parts.year ?? 0
        let months = parts.month ?? 0
        if years > 0 {
            return months > 0
                ? String(localized: "age_years_months \(years) \(months)")
                : String(localized: "age_years \(years)")
        }
        if months == 0 { return String(localized: "growth_age_in_weeks \(days / 7)") }
        return String(localized: "age_months \(months)")
    }
}

// MARK: - Percentile badge

struct GrowthPercentileBadge: View {
    let percentile: Int?

    var body: some View {
        Text(percentile.map { "P\($0)" } ?? "—")
            .font(.leona(13, .heavy))
            .foregroundStyle(.white)
            .padding(.vertical, 5)
            .padding(.horizontal, 11)
            .background(percentile == nil ? Color.tDisabled : Color.vermilion)
            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
    }
}

// MARK: - Screen

struct GrowthView: View {
    let baby: Baby
    @Binding var metric: GrowthMetric

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \GrowthRecord.date, order: .reverse) private var allRecords: [GrowthRecord]
    @State private var sheet: GrowthSheet?

    private enum GrowthSheet: Identifiable {
        case add
        case edit(GrowthRecord)

        var id: String {
            switch self {
            case .add: return "add"
            case .edit(let record): return record.id.uuidString
            }
        }
    }

    /// Newest first.
    private var records: [GrowthRecord] { allRecords.filter { $0.baby?.id == baby.id } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                metricPills
                if records.isEmpty {
                    emptyBubble
                } else {
                    leonaCard
                }
                GrowthChartCard(baby: baby, metric: metric, records: records)
                HStack {
                    LeonaSectionLabel(String(localized: "growth_every_measurement"))
                    Spacer(minLength: 8)
                    LeonaSmallButton(title: String(localized: "growth_add_short")) { sheet = .add }
                }
                .padding(.top, 4)
                ForEach(records) { record in
                    recordRow(record)
                }
            }
            .padding(EdgeInsets(top: 4, leading: 18, bottom: 20, trailing: 18))
        }
        .scrollIndicators(.hidden)
        .refreshable { await refreshSharedData() }
        .sheet(item: $sheet) { sheet in
            switch sheet {
            case .add: GrowthEntryView(baby: baby)
            case .edit(let record): GrowthEntryView(baby: baby, editingRecord: record)
            }
        }
    }

    // MARK: - Pills

    private var metricPills: some View {
        HStack(spacing: 7) {
            ForEach(GrowthMetric.allCases) { candidate in
                LeonaPill(title: candidate.title, isOn: metric == candidate) {
                    withAnimation(.easeOut(duration: 0.18)) { metric = candidate }
                }
            }
        }
    }

    // MARK: - Leona's card

    private var latest: GrowthRecord? { records.first { metric.storedValue(of: $0) != nil } }

    private var previous: GrowthRecord? {
        guard let latest else { return nil }
        return records.first { $0.date < latest.date && metric.storedValue(of: $0) != nil }
    }

    private var leonaCard: some View {
        LeonaTintCard(padding: EdgeInsets(top: 16, leading: 18, bottom: 16, trailing: 18), asBubble: true) {
            VStack(alignment: .leading, spacing: 10) {
                LeonaCardHeader()
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(latestValueText)
                        .font(.leona(38, .bold))
                        .leonaTracking(-0.045, size: 38)
                        .foregroundStyle(.tInk)
                    Text(metric.unit)
                        .font(.leona(16, .bold))
                        .foregroundStyle(.tMuted)
                    if let delta = deltaText {
                        Text(delta.text)
                            .font(.leona(14, .bold))
                            .foregroundStyle(delta.isGain ? Color.moss : Color.vermilion)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    Spacer(minLength: 4)
                    GrowthPercentileBadge(percentile: latestPercentile)
                }
                Text(verdict)
                    .font(.leona(15, .medium))
                    .lineSpacing(4)
                    .foregroundStyle(.tInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var latestValueText: String {
        guard let latest, let value = metric.storedValue(of: latest) else { return "—" }
        return metric.format(metric.display(value))
    }

    private var deltaText: (text: String, isGain: Bool)? {
        guard let latest, let previous,
              let now = metric.storedValue(of: latest), let before = metric.storedValue(of: previous) else { return nil }
        let delta = metric.display(now) - metric.display(before)
        guard abs(delta) >= 0.005 else { return nil }
        let signed = (delta < 0 ? "−" : "+") + metric.format(abs(delta)) + " " + metric.unit
        return (String(localized: "growth_delta_since_last \(signed)"), delta > 0)
    }

    private func percentile(of record: GrowthRecord) -> Int? {
        guard let value = metric.storedValue(of: record) else { return nil }
        let age = record.ageInMonthsAtMeasurement ?? GrowthAge.months(from: baby.dateOfBirth, to: record.date)
        return metric.percentile(value: value, ageInMonths: age, gender: baby.gender)
    }

    private var latestPercentile: Int? { latest.flatMap(percentile(of:)) }

    private var verdict: String {
        guard let latest else {
            return String(localized: "growth_metric_empty \(metric.title.lowercased())")
        }
        let name = baby.displayName
        var parts: [String] = []
        if let p = latestPercentile {
            let formatter = NumberFormatter()
            formatter.numberStyle = .ordinal
            let ordinal = formatter.string(from: NSNumber(value: p)) ?? "\(p)"
            let who: String
            switch baby.gender {
            case .girl: who = String(localized: "growth_gender_girl")
            case .boy: who = String(localized: "growth_gender_boy")
            case .unspecified: who = String(localized: "growth_gender_baby")
            }
            let age = GrowthAge.phrase(from: baby.dateOfBirth, to: latest.date)
            parts.append(String(localized: "growth_verdict_percentile \(ordinal) \(who) \(age)"))
        }

        let history = records
            .filter { metric.storedValue(of: $0) != nil }
            .sorted { $0.date < $1.date }
            .suffix(4)
            .compactMap(percentile(of:))
        if history.count < 2 {
            parts.append(String(localized: "growth_steady_single"))
        } else if let first = history.first, let last = history.last {
            let drift = last - first
            if abs(drift) <= 15 {
                parts.append(String(localized: "growth_steady_held \(name)"))
            } else if drift > 0 {
                parts.append(String(localized: "growth_steady_up \(name)"))
            } else {
                parts.append(String(localized: "growth_steady_down \(name)"))
            }
        }
        return parts.joined(separator: " ")
    }

    // MARK: - Empty state

    private var emptyBubble: some View {
        LeonaTintCard(padding: EdgeInsets(top: 16, leading: 18, bottom: 16, trailing: 18), asBubble: true) {
            VStack(alignment: .leading, spacing: 10) {
                LeonaCardHeader()
                Text(String(localized: "growth_empty_bubble \(baby.displayName)"))
                    .font(.leona(15, .medium))
                    .lineSpacing(4)
                    .foregroundStyle(.tInk)
                    .fixedSize(horizontal: false, vertical: true)
                LeonaSmallButton(title: String(localized: "add_measurement"), tone: .vermilion, fontSize: 13, vertical: 10, horizontal: 16, radius: 12) {
                    sheet = .add
                }
            }
        }
    }

    // MARK: - Rows

    private func recordRow(_ record: GrowthRecord) -> some View {
        Button {
            HapticManager.selection()
            sheet = .edit(record)
        } label: {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(record.date.formatted(.dateTime.day().month(.abbreviated).year()))
                        .font(.leona(14, .bold))
                        .foregroundStyle(.tTheirsInk)
                    Text(GrowthAge.phrase(from: baby.dateOfBirth, to: record.date))
                        .font(.leona(12))
                        .foregroundStyle(.tMuted)
                }
                Spacer(minLength: 8)
                HStack(spacing: 12) {
                    Text(record.weightKg.map { UnitConversion.formatWeight($0) } ?? "—")
                        .foregroundStyle(.tTheirsInk)
                    Text(record.heightCm.map { UnitConversion.formatHeight($0) } ?? "—")
                        .foregroundStyle(.tMuted)
                    Text(record.headCircumferenceCm.map { UnitConversion.formatHeight($0) } ?? "—")
                        .foregroundStyle(.tMuted)
                }
                .font(.leona(13, .bold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            }
            .padding(.vertical, 13)
            .padding(.horizontal, 15)
            .background(Color.tTheirs)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.leonaPress)
    }

    private func refreshSharedData() async {
        guard baby.isShared else { return }
        await SyncEngine.shared.forcePullSharedBabies(context: modelContext)
    }
}
