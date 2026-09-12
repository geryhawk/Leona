import SwiftUI
import SwiftData

/// Sheet that edits one entry: times, then the fields that belong to its type.
struct RecordEditorView: View {
    let activity: Activity

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var startTime: Date
    @State private var endTime: Date
    @State private var hasEndTime: Bool
    @State private var displayVolume: Double
    @State private var breastSide: BreastSide
    @State private var diaperType: DiaperType
    @State private var noteText: String
    @State private var foodName: String
    @State private var foodQuantity: Double
    @State private var foodUnit: FoodUnit

    init(activity: Activity) {
        self.activity = activity
        _startTime = State(initialValue: activity.startTime)
        _endTime = State(initialValue: activity.endTime ?? Date())
        _hasEndTime = State(initialValue: activity.endTime != nil)
        _displayVolume = State(initialValue: UnitConversion.displayVolume(activity.volumeML ?? 0))
        _breastSide = State(initialValue: activity.breastSide ?? .left)
        _diaperType = State(initialValue: activity.diaperType ?? .pee)
        _noteText = State(initialValue: activity.noteText ?? "")
        _foodName = State(initialValue: activity.foodName ?? "")
        _foodQuantity = State(initialValue: activity.foodQuantity ?? 0)
        _foodUnit = State(initialValue: activity.foodUnit ?? .grams)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    LeonaSectionLabel(String(localized: "edit_time"))
                    timeGroup
                    if activity.type != .sleep {
                        LeonaSectionLabel(String(localized: "edit_details"))
                        detailsGroup
                    }
                }
                .padding(18)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .background(Color.tCanvas.ignoresSafeArea())
    }

    // MARK: - Header

    private var header: some View {
        ZStack {
            Text(String(localized: "record_edit_title"))
                .font(.leona(16, .bold))
                .foregroundStyle(.tInk)
            HStack {
                Button { dismiss() } label: {
                    Text(String(localized: "cancel"))
                        .font(.leona(15, .semibold))
                        .foregroundStyle(.tMuted)
                }
                .buttonStyle(.plain)
                Spacer()
                Button { save() } label: {
                    Text(String(localized: "save"))
                        .font(.leona(15, .bold))
                        .foregroundStyle(.vermilion)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 18)
        .frame(height: 54)
        .overlay(alignment: .bottom) { Rectangle().fill(Color.tLine).frame(height: 1) }
    }

    // MARK: - Time

    private var timeGroup: some View {
        LeonaGroup {
            dateRow(String(localized: "start_time"), $startTime)
            if activity.isOngoing {
                LeonaToggleRow(title: String(localized: "record_mark_finished"), isOn: $hasEndTime)
                if hasEndTime {
                    dateRow(String(localized: "end_time"), $endTime)
                }
            } else if activity.endTime != nil {
                dateRow(String(localized: "end_time"), $endTime)
            }
        }
    }

    private func dateRow(_ label: String, _ date: Binding<Date>) -> some View {
        HStack(spacing: 12) {
            Text(label)
                .font(.leona(14))
                .foregroundStyle(.tMuted)
            Spacer(minLength: 0)
            DatePicker("", selection: date, in: ...Date())
                .labelsHidden()
                .tint(.vermilion)
        }
        .padding(.vertical, 11)
        .padding(.horizontal, 17)
    }

    // MARK: - Details per type

    @ViewBuilder
    private var detailsGroup: some View {
        switch activity.type {
        case .breastfeeding:
            LeonaGroup {
                if activity.breastfeedingLaps.count > 1 {
                    lapRows
                } else {
                    sideRow
                }
            }
        case .formula, .momsMilk:
            LeonaGroup {
                numberRow(String(localized: "volume_label"), value: $displayVolume, unit: UnitConversion.volumeUnit)
            }
        case .solidFood:
            LeonaGroup {
                textRow(String(localized: "food_name"), text: $foodName, placeholder: String(localized: "food_name_placeholder"))
                numberRow(String(localized: "quantity"), value: $foodQuantity, unit: nil)
                unitRow
            }
        case .diaper:
            LeonaGroup {
                diaperRow
            }
        case .note:
            LeonaCard(padding: EdgeInsets(top: 8, leading: 13, bottom: 8, trailing: 13)) {
                TextEditor(text: $noteText)
                    .font(.leona(15))
                    .foregroundStyle(.tInk)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 110)
            }
        case .sleep:
            EmptyView()
        }
    }

    @ViewBuilder
    private var lapRows: some View {
        let laps = activity.breastfeedingLaps
        ForEach(Array(laps.enumerated()), id: \.element.id) { index, lap in
            if index > 0, let previousEnd = laps[index - 1].endTime,
               lap.startTime.timeIntervalSince(previousEnd) > 1 {
                valueRow(String(localized: "break_label"), Self.formatLap(lap.startTime.timeIntervalSince(previousEnd)), muted: true)
            }
            valueRow(lap.side.displayName, lap.duration.map(Self.formatLap) ?? "—")
        }
        valueRow(String(localized: "total_feeding"), Self.formatLap(laps.compactMap(\.duration).reduce(0, +)))
        if Self.breakDuration(from: laps) > 1 {
            valueRow(String(localized: "total_breaks"), Self.formatLap(Self.breakDuration(from: laps)), muted: true)
        }
    }

    private var sideRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(String(localized: "breast_side"))
                .font(.leona(14))
                .foregroundStyle(.tMuted)
            HStack(spacing: 7) {
                ForEach(BreastSide.allCases) { side in
                    LeonaPill(title: side.displayName, isOn: breastSide == side, tone: .plum, fontSize: 13, vertical: 9) {
                        breastSide = side
                    }
                }
            }
        }
        .padding(.vertical, 15)
        .padding(.horizontal, 17)
    }

    private var diaperRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(String(localized: "diaper_type"))
                .font(.leona(14))
                .foregroundStyle(.tMuted)
            HStack(spacing: 7) {
                ForEach(DiaperType.allCases) { type in
                    LeonaPill(title: type.displayName, isOn: diaperType == type, tone: .plum, fontSize: 13, vertical: 9) {
                        diaperType = type
                    }
                }
            }
        }
        .padding(.vertical, 15)
        .padding(.horizontal, 17)
    }

    private var unitRow: some View {
        HStack(spacing: 12) {
            Text(String(localized: "unit"))
                .font(.leona(14))
                .foregroundStyle(.tMuted)
            Spacer(minLength: 0)
            Menu {
                ForEach(FoodUnit.allCases) { unit in
                    Button {
                        foodUnit = unit
                        HapticManager.selection()
                    } label: {
                        if foodUnit == unit {
                            Label(unit.displayName, systemImage: "checkmark")
                        } else {
                            Text(unit.displayName)
                        }
                    }
                }
            } label: {
                HStack(spacing: 5) {
                    Text(foodUnit.displayName)
                        .font(.leona(15, .bold))
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 11, weight: .bold))
                }
                .foregroundStyle(.tInk)
            }
        }
        .padding(.vertical, 15)
        .padding(.horizontal, 17)
    }

    // MARK: - Row primitives

    private func textRow(_ label: String, text: Binding<String>, placeholder: String) -> some View {
        HStack(spacing: 12) {
            Text(label)
                .font(.leona(14))
                .foregroundStyle(.tMuted)
            TextField(placeholder, text: text)
                .font(.leona(15, .bold))
                .foregroundStyle(.tInk)
                .multilineTextAlignment(.trailing)
                .submitLabel(.done)
        }
        .padding(.vertical, 15)
        .padding(.horizontal, 17)
    }

    private func numberRow(_ label: String, value: Binding<Double>, unit: String?) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.leona(14))
                .foregroundStyle(.tMuted)
            Spacer(minLength: 0)
            TextField("0", value: value, format: .number)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .font(.leona(15, .bold))
                .foregroundStyle(.tInk)
                .frame(width: 90)
            if let unit {
                Text(unit)
                    .font(.leona(14))
                    .foregroundStyle(.tMuted)
            }
        }
        .padding(.vertical, 15)
        .padding(.horizontal, 17)
    }

    private func valueRow(_ label: String, _ value: String, muted: Bool = false) -> some View {
        HStack(spacing: 12) {
            Text(label)
                .font(.leona(15, muted ? .regular : .bold))
                .foregroundStyle(muted ? Color.tMuted : Color.tInk)
            Spacer(minLength: 0)
            Text(value)
                .font(.leona(15, .bold))
                .foregroundStyle(.tMuted)
        }
        .padding(.vertical, 13)
        .padding(.horizontal, 17)
    }

    // MARK: - Helpers

    private static func formatLap(_ interval: TimeInterval) -> String {
        let minutes = Int(interval) / 60
        let seconds = Int(interval) % 60
        return minutes > 0 ? "\(minutes)m \(String(format: "%02d", seconds))s" : "\(seconds)s"
    }

    private static func breakDuration(from laps: [BreastfeedingLap]) -> TimeInterval {
        guard laps.count > 1 else { return 0 }
        var total: TimeInterval = 0
        for index in 1..<laps.count {
            if let previousEnd = laps[index - 1].endTime {
                let gap = laps[index].startTime.timeIntervalSince(previousEnd)
                if gap > 1 { total += gap }
            }
        }
        return total
    }

    // MARK: - Save (same write-back as the old EditActivityView.saveChanges)

    private func save() {
        activity.startTime = startTime

        if hasEndTime {
            activity.endTime = endTime > startTime ? endTime : startTime
            activity.isOngoing = false
        } else if !activity.isOngoing, activity.endTime != nil {
            activity.endTime = endTime > startTime ? endTime : startTime
        }

        switch activity.type {
        case .formula, .momsMilk:
            let storedMl = UnitConversion.storageVolume(displayVolume)
            activity.volumeML = storedMl > 0 ? storedMl : nil
        case .breastfeeding:
            activity.breastSide = breastSide
        case .diaper:
            activity.diaperType = diaperType
        case .solidFood:
            activity.foodName = foodName.isEmpty ? nil : foodName
            activity.foodQuantity = foodQuantity > 0 ? foodQuantity : nil
            activity.foodUnit = foodUnit
        case .note:
            activity.noteText = noteText.isEmpty ? nil : noteText
        case .sleep:
            break
        }

        activity.updatedAt = Date()
        ActivityLogger.save(modelContext)
        HapticManager.success()
        dismiss()
    }
}
