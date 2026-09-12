import SwiftUI

// MARK: - Tray state

/// Everything the tray needs to log one entry. Values are in display units.
struct LogTrayState: Equatable {
    enum Kind: Equatable { case bottle, breast, solid, diaper }

    let kind: Kind
    var value: Double
    var side: BreastSide = .left
    var diaperType: DiaperType = .pee
    var bottleKind: ActivityLogger.BottleKind = .formula
    var foodName = ""
    var foodUnit: FoodUnit = .grams
    var offsetMinutes = 0
    var customTime: Date?

    var min: Double
    var max: Double
    var step: Double
    var presets: [Double]
    var suggestedSide: BreastSide = .right

    var resolvedTime: Date {
        customTime ?? Date().addingTimeInterval(-Double(offsetMinutes) * 60)
    }

    var unit: String {
        switch kind {
        case .bottle: return UnitConversion.volumeUnit
        case .breast: return String(localized: "tray_unit_min")
        case .solid: return foodUnit.symbol
        case .diaper: return ""
        }
    }

    var title: String {
        switch kind {
        case .bottle: return String(localized: "tray_title_bottle \(UnitConversion.volumeUnit)")
        case .breast: return String(localized: "tray_title_breast")
        case .solid: return String(localized: "tray_title_solid \(foodUnit.displayName)")
        case .diaper: return String(localized: "tray_title_diaper")
        }
    }

    var valueText: String {
        if kind == .bottle && !AppSettings.shared.useMetric { return String(format: "%.1f", value) }
        return String(format: "%.0f", value)
    }

    var storageVolumeML: Double {
        UnitConversion.storageVolume(value)
    }

    var showsAmount: Bool { kind != .diaper }

    static func make(kind: Kind, predictedVolumeML: Double, lastBreastSide: BreastSide?) -> LogTrayState {
        switch kind {
        case .bottle:
            let metric = AppSettings.shared.useMetric
            let display = UnitConversion.displayVolume(predictedVolumeML)
            let value = metric ? (display / 10).rounded() * 10 : (display * 2).rounded() / 2
            let stepValue: Double = metric ? 10 : 0.5
            let lower: Double = metric ? 30 : 1
            let upper: Double = metric ? 300 : 10
            let spread: [Double] = metric ? [-30, 0, 30, 60] : [-1, 0, 1, 2]
            var presets: [Double] = []
            for delta in spread {
                let p = Swift.min(upper, Swift.max(lower, value + delta))
                if !presets.contains(p) { presets.append(p) }
            }
            return LogTrayState(kind: .bottle, value: Swift.min(upper, Swift.max(lower, value)), min: lower, max: upper, step: stepValue, presets: presets)
        case .breast:
            let suggested: BreastSide = lastBreastSide == .left ? .right : .left
            return LogTrayState(kind: .breast, value: 15, side: suggested, min: 5, max: 45, step: 1, presets: [10, 15, 20, 25], suggestedSide: suggested)
        case .solid:
            return LogTrayState(kind: .solid, value: 45, min: 10, max: 120, step: 5, presets: [20, 45, 60, 90])
        case .diaper:
            return LogTrayState(kind: .diaper, value: 0, min: 0, max: 0, step: 1, presets: [])
        }
    }
}

// MARK: - Tray view

struct LogTrayView: View {
    @Binding var state: LogTrayState
    let baby: Baby
    let onClose: () -> Void
    let onSend: (LogTrayState) -> Void

    @State private var showTimePicker = false

    private let commonFoods: [(String, String)] = [
        ("🥕", "food_carrot"), ("🍌", "food_banana"), ("🍎", "food_apple"), ("🥑", "food_avocado"),
        ("🍠", "food_sweet_potato"), ("🥦", "food_broccoli"), ("🍚", "food_rice_cereal"), ("🥣", "food_oatmeal"),
        ("🍗", "food_chicken"), ("🐟", "food_fish"), ("🥛", "food_yogurt"), ("🧀", "food_cheese")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(state.title.uppercased())
                    .font(.leona(12, .heavy))
                    .leonaTracking(0.1, size: 12)
                    .foregroundStyle(.tMuted)
                Spacer()
                Button(action: onClose) {
                    Text(String(localized: "close"))
                        .font(.leona(13, .bold))
                        .foregroundStyle(.tMuted)
                }
                .buttonStyle(.plain)
            }
            .padding(.bottom, 12)

            switch state.kind {
            case .bottle:
                bottleKindRow.padding(.bottom, 10)
                amountRow
                presetsRow.padding(.top, 12)
            case .breast:
                amountRow
                presetsRow.padding(.top, 12)
                sideRow.padding(.top, 9)
            case .solid:
                solidHeader.padding(.bottom, 10)
                amountRow
                presetsRow.padding(.top, 12)
            case .diaper:
                diaperRow
            }

            timeRow.padding(.top, 12)
        }
        .padding(.top, 14)
        .padding(.horizontal, 18)
        .padding(.bottom, 12)
        .background(Color.tTray)
        .overlay(alignment: .top) { Rectangle().fill(Color.tLine).frame(height: 1) }
        .sheet(isPresented: $showTimePicker) {
            TrayTimePicker(time: Binding(
                get: { state.customTime ?? state.resolvedTime },
                set: { state.customTime = $0; state.offsetMinutes = 0 }
            ))
            .presentationDetents([.medium])
        }
    }

    // MARK: Amount

    private var amountRow: some View {
        HStack(spacing: 12) {
            stepButton("minus") { state.value = max(state.min, state.value - state.step) }
            VStack(spacing: 7) {
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Text(state.valueText)
                        .font(.leona(42, .bold))
                        .leonaTracking(-0.045, size: 42)
                        .foregroundStyle(.tInk)
                        .contentTransition(.numericText())
                        .animation(.easeOut(duration: 0.15), value: state.value)
                    Text(state.unit)
                        .font(.leona(16, .semibold))
                        .foregroundStyle(.tMuted)
                }
                Slider(value: $state.value, in: state.min...state.max, step: state.step)
                    .tint(.vermilion)
            }
            stepButton("plus") { state.value = min(state.max, state.value + state.step) }
        }
    }

    private func stepButton(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button {
            HapticManager.selection()
            action()
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.tInk)
                .frame(width: 52, height: 52)
                .background(Color.tSurface)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.tLine, lineWidth: 1))
        }
        .buttonStyle(.leonaPress)
    }

    private var presetsRow: some View {
        HStack(spacing: 7) {
            ForEach(state.presets, id: \.self) { preset in
                let on = abs(state.value - preset) < 0.01
                trayChoice(state.kind == .bottle && !AppSettings.shared.useMetric ? String(format: "%.1f", preset) : String(format: "%.0f", preset), on: on, fontSize: 15) {
                    state.value = preset
                }
            }
        }
    }

    private var sideRow: some View {
        HStack(spacing: 7) {
            trayChoice(sideTitle(.left), on: state.side == .left, fontSize: 14) { state.side = .left }
            trayChoice(sideTitle(.right), on: state.side == .right, fontSize: 14) { state.side = .right }
        }
    }

    private func sideTitle(_ side: BreastSide) -> String {
        let base = side.displayName
        return side == state.suggestedSide ? String(localized: "tray_side_suggested \(base)") : base
    }

    private var bottleKindRow: some View {
        HStack(spacing: 7) {
            LeonaPill(title: String(localized: "formula"), isOn: state.bottleKind == .formula, tone: .plum, fontSize: 12, vertical: 8) { state.bottleKind = .formula }
            LeonaPill(title: String(localized: "tray_expressed_milk"), isOn: state.bottleKind == .expressedMilk, tone: .plum, fontSize: 12, vertical: 8) { state.bottleKind = .expressedMilk }
        }
    }

    private var solidHeader: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                LeonaTextField(placeholder: String(localized: "food_name_placeholder"), text: $state.foodName, height: 44, radius: 14, fontSize: 15, weight: .semibold)
                Menu {
                    ForEach(FoodUnit.allCases) { unit in
                        Button(unit.displayName) { state.foodUnit = unit }
                    }
                } label: {
                    Text(state.foodUnit.symbol)
                        .font(.leona(13, .bold))
                        .foregroundStyle(.tInk)
                        .frame(width: 56, height: 44)
                        .background(Color.tSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.tLine, lineWidth: 1))
                }
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(commonFoods, id: \.1) { emoji, key in
                        let name = String(localized: String.LocalizationValue(key))
                        Button {
                            HapticManager.selection()
                            state.foodName = name
                        } label: {
                            Text("\(emoji) \(name)")
                                .font(.leona(12, .bold))
                                .foregroundStyle(state.foodName == name ? Color.white : Color.tTheirsInk)
                                .padding(.vertical, 7)
                                .padding(.horizontal, 11)
                                .background(state.foodName == name ? Color.tMine : Color.tChip)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.leonaPress)
                    }
                }
            }
        }
    }

    private var diaperRow: some View {
        HStack(spacing: 9) {
            ForEach(DiaperType.allCases) { type in
                let on = state.diaperType == type
                Button {
                    HapticManager.selection()
                    state.diaperType = type
                } label: {
                    Text(type.displayName)
                        .font(.leona(16, .bold))
                        .foregroundStyle(on ? Color.white : Color.tTheirsInk)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                        .background(on ? Color.vermilion : Color.tChip)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.tLine, lineWidth: on ? 0 : 1))
                }
                .buttonStyle(.leonaPress)
            }
        }
    }

    private func trayChoice(_ title: String, on: Bool, fontSize: CGFloat, action: @escaping () -> Void) -> some View {
        Button {
            HapticManager.selection()
            action()
        } label: {
            Text(title)
                .font(.leona(fontSize, .bold))
                .foregroundStyle(on ? Color.white : Color.tInk)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(on ? Color.vermilion : Color.tSurface)
                .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous).stroke(Color.tLine, lineWidth: on ? 0 : 1))
        }
        .buttonStyle(.leonaPress)
    }

    // MARK: Time + send

    private var timeRow: some View {
        HStack(spacing: 8) {
            Button { showTimePicker = true } label: {
                Text(timeLabel)
                    .font(.leona(13, .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .padding(.vertical, 11)
                    .padding(.horizontal, 14)
                    .background(Color.tMine)
                    .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
            }
            .buttonStyle(.leonaPress)

            backButton(15)
            backButton(30)

            Spacer(minLength: 0)

            Button {
                HapticManager.impact(.medium)
                onSend(state)
            } label: {
                Text(String(localized: "tray_send"))
                    .font(.leona(15, .heavy))
                    .foregroundStyle(.white)
                    .padding(.vertical, 13)
                    .padding(.horizontal, 24)
                    .background(Color.vermilion)
                    .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
            }
            .buttonStyle(LeonaPressStyle(scale: 0.96))
        }
    }

    private var timeLabel: String {
        if state.customTime == nil && state.offsetMinutes == 0 {
            return String(localized: "tray_time_now \(ThreadFormat.clock(Date()))")
        }
        let time = state.resolvedTime
        return time.isToday ? ThreadFormat.clock(time) : time.smartDateTimeString
    }

    private func backButton(_ minutes: Int) -> some View {
        Button {
            HapticManager.selection()
            state.customTime = nil
            state.offsetMinutes += minutes
        } label: {
            Text("−\(minutes)m")
                .font(.leona(13, .bold))
                .foregroundStyle(.tInk)
                .padding(.vertical, 11)
                .padding(.horizontal, 13)
                .background(Color.tSurface)
                .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous).stroke(Color.tLine, lineWidth: 1))
        }
        .buttonStyle(.leonaPress)
    }
}

// MARK: - Time picker sheet

private struct TrayTimePicker: View {
    @Binding var time: Date
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text(String(localized: "date_time"))
                    .font(.leona(16, .bold))
                    .foregroundStyle(.tInk)
                Spacer()
                Button(String(localized: "done")) { dismiss() }
                    .font(.leona(15, .bold))
                    .foregroundStyle(.vermilion)
            }
            DatePicker(String(localized: "date_time"), selection: $time, in: ...Date())
                .datePickerStyle(.wheel)
                .labelsHidden()
            Spacer(minLength: 0)
        }
        .padding(20)
        .background(Color.tCanvas.ignoresSafeArea())
    }
}
