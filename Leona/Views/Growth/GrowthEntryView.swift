import SwiftUI
import SwiftData

struct GrowthEntryView: View {
    let baby: Baby
    var editingRecord: GrowthRecord?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var date: Date
    @State private var weightStr: String
    @State private var heightStr: String
    @State private var headStr: String

    var isEditing: Bool { editingRecord != nil }

    init(baby: Baby, editingRecord: GrowthRecord? = nil) {
        self.baby = baby
        self.editingRecord = editingRecord
        self._date = State(initialValue: editingRecord?.date ?? Date())

        // Convert from metric storage to display units
        let settings = AppSettings.shared
        if let w = editingRecord?.weightKg {
            let display = settings.useMetric ? w : UnitConversion.kgToLbs(w)
            self._weightStr = State(initialValue: String(format: "%.2f", display))
        } else {
            self._weightStr = State(initialValue: "")
        }
        if let h = editingRecord?.heightCm {
            let display = settings.useMetric ? h : UnitConversion.cmToInches(h)
            self._heightStr = State(initialValue: String(format: "%.1f", display))
        } else {
            self._heightStr = State(initialValue: "")
        }
        if let hc = editingRecord?.headCircumferenceCm {
            let display = settings.useMetric ? hc : UnitConversion.cmToInches(hc)
            self._headStr = State(initialValue: String(format: "%.1f", display))
        } else {
            self._headStr = State(initialValue: "")
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(String(localized: "measurement_date")) {
                    DatePicker(String(localized: "date"), selection: $date, in: ...Date(), displayedComponents: .date)
                }

                Section(String(localized: "measurements")) {
                    HStack {
                        Label(String(localized: "weight"), systemImage: "scalemass.fill")
                            .foregroundStyle(.blue)
                        Spacer()
                        TextField("0.00", text: $weightStr)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                        Text(UnitConversion.weightUnit)
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Label(String(localized: "height"), systemImage: "ruler.fill")
                            .foregroundStyle(.green)
                        Spacer()
                        TextField("0.0", text: $heightStr)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                        Text(UnitConversion.heightUnit)
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Label(String(localized: "head_circumference"), systemImage: "circle.dashed")
                            .foregroundStyle(.purple)
                        Spacer()
                        TextField("0.0", text: $headStr)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                        Text(UnitConversion.heightUnit)
                            .foregroundStyle(.secondary)
                    }
                }

                // Percentile preview
                if hasAnyValue {
                    Section(String(localized: "percentiles")) {
                        if let weightKg = metricWeight {
                            percentileRow(
                                label: String(localized: "weight"),
                                metricValue: weightKg,
                                type: .weight,
                                color: .blue
                            )
                        }
                        if let heightCm = metricHeight {
                            percentileRow(
                                label: String(localized: "height"),
                                metricValue: heightCm,
                                type: .height,
                                color: .green
                            )
                        }
                        if let headCm = metricHead {
                            percentileRow(
                                label: String(localized: "head_circumference"),
                                metricValue: headCm,
                                type: .head,
                                color: .purple
                            )
                        }
                    }
                }
            }
            .navigationTitle(isEditing ? String(localized: "edit_measurement") : String(localized: "add_measurement"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "save")) { save() }
                        .fontWeight(.semibold)
                        .disabled(!hasAnyValue)
                }
            }
        }
    }

    // MARK: - Metric Conversion

    /// Convert display input to metric kg
    private var metricWeight: Double? {
        guard let v = Double(weightStr), v > 0 else { return nil }
        return UnitConversion.storageWeight(v)
    }

    /// Convert display input to metric cm
    private var metricHeight: Double? {
        guard let v = Double(heightStr), v > 0 else { return nil }
        return UnitConversion.storageHeight(v)
    }

    /// Convert display input to metric cm
    private var metricHead: Double? {
        guard let v = Double(headStr), v > 0 else { return nil }
        return UnitConversion.storageHeight(v)
    }

    private var hasAnyValue: Bool {
        !weightStr.isEmpty || !heightStr.isEmpty || !headStr.isEmpty
    }

    private enum PercentileType {
        case weight, height, head
    }

    private func percentileRow(label: String, metricValue: Double, type: PercentileType, color: Color) -> some View {
        let data: [WHOPercentilePoint]
        switch type {
        case .weight: data = WHODataService.weightPercentiles(gender: baby.gender)
        case .height: data = WHODataService.heightPercentiles(gender: baby.gender)
        case .head: data = WHODataService.headCircumferencePercentiles(gender: baby.gender)
        }

        let percentile = WHODataService.calculatePercentile(
            value: metricValue,
            ageInMonths: baby.ageInMonths,
            data: data
        )

        return HStack {
            Text(label)
                .foregroundStyle(color)
            Spacer()
            if let p = percentile {
                Text("P\(Int(p))")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(percentileColor(p))
                    .clipShape(Capsule())
            } else {
                Text("--")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func percentileColor(_ p: Double) -> Color {
        if p < 3 || p > 97 { return .red }
        if p < 15 || p > 85 { return .orange }
        return .green
    }

    private func save() {
        if let record = editingRecord {
            record.date = date
            record.weightKg = metricWeight
            record.heightCm = metricHeight
            record.headCircumferenceCm = metricHead
            record.updatedAt = Date()
        } else {
            let record = GrowthRecord(
                date: date,
                weightKg: metricWeight,
                heightCm: metricHeight,
                headCircumferenceCm: metricHead,
                baby: baby
            )
            modelContext.insert(record)
        }

        UINotificationFeedbackGenerator().notificationOccurred(.success)
        dismiss()
    }
}
