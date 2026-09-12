import SwiftUI
import SwiftData

/// Add or edit one measurement. Inputs are in the display unit; storage stays metric.
struct GrowthEntryView: View {
    let baby: Baby
    var editingRecord: GrowthRecord?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var date: Date
    @State private var weightStr: String
    @State private var heightStr: String
    @State private var headStr: String
    @State private var showDeleteConfirm = false

    var isEditing: Bool { editingRecord != nil }

    init(baby: Baby, editingRecord: GrowthRecord? = nil) {
        self.baby = baby
        self.editingRecord = editingRecord
        _date = State(initialValue: editingRecord?.date ?? Date())
        _weightStr = State(initialValue: editingRecord?.weightKg.map { GrowthMetric.weight.format(GrowthMetric.weight.display($0)) } ?? "")
        _heightStr = State(initialValue: editingRecord?.heightCm.map { GrowthMetric.height.format(GrowthMetric.height.display($0)) } ?? "")
        _headStr = State(initialValue: editingRecord?.headCircumferenceCm.map { GrowthMetric.head.format(GrowthMetric.head.display($0)) } ?? "")
    }

    var body: some View {
        VStack(spacing: 0) {
            InsightsSheetHeader(
                title: isEditing ? String(localized: "edit_measurement") : String(localized: "add_measurement"),
                trailingEnabled: hasAnyValue,
                onLeading: { dismiss() },
                onTrailing: save
            )

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    LeonaGroup {
                        dateRow
                        valueRow(String(localized: "growth_weight"), text: $weightStr, placeholder: "0.00", unit: UnitConversion.weightUnit)
                        valueRow(String(localized: "growth_height"), text: $heightStr, placeholder: "0.0", unit: UnitConversion.heightUnit)
                        valueRow(String(localized: "head_circumference"), text: $headStr, placeholder: "0.0", unit: UnitConversion.heightUnit)
                    }

                    if hasAnyValue {
                        LeonaSectionLabel(String(localized: "percentiles"))
                            .padding(.top, 6)
                        LeonaGroup {
                            if let kg = metricWeight { percentileRow(String(localized: "growth_weight"), value: kg, metric: .weight) }
                            if let cm = metricHeight { percentileRow(String(localized: "growth_height"), value: cm, metric: .height) }
                            if let cm = metricHead { percentileRow(String(localized: "head_circumference"), value: cm, metric: .head) }
                        }
                        Text(String(localized: "growth_percentile_note \(GrowthAge.phrase(from: baby.dateOfBirth, to: date))"))
                            .font(.leona(12, .semibold))
                            .foregroundStyle(.tMuted)
                            .padding(.horizontal, 4)
                    }

                    if isEditing {
                        LeonaGroup {
                            LeonaRow(title: String(localized: "growth_delete_measurement"), destructive: true) {
                                showDeleteConfirm = true
                            }
                        }
                        .padding(.top, 10)
                    }
                }
                .padding(18)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .background(Color.tCanvas.ignoresSafeArea())
        .alert(String(localized: "delete_record"), isPresented: $showDeleteConfirm) {
            Button(String(localized: "delete"), role: .destructive) { deleteRecord() }
            Button(String(localized: "cancel"), role: .cancel) {}
        } message: {
            Text(String(localized: "growth_delete_message"))
        }
    }

    // MARK: - Rows

    private var dateRow: some View {
        HStack(spacing: 12) {
            Text(String(localized: "measurement_date"))
                .font(.leona(15, .bold))
                .foregroundStyle(.tInk)
            Spacer(minLength: 0)
            DatePicker("", selection: $date, in: ...Date(), displayedComponents: .date)
                .labelsHidden()
                .datePickerStyle(.compact)
        }
        .padding(.vertical, 11)
        .padding(.horizontal, 17)
    }

    private func valueRow(_ label: String, text: Binding<String>, placeholder: String, unit: String) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.leona(15, .bold))
                .foregroundStyle(.tInk)
            Spacer(minLength: 0)
            TextField(placeholder, text: text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .font(.leona(15, .bold))
                .foregroundStyle(.tInk)
                .frame(width: 96)
            Text(unit)
                .font(.leona(13, .semibold))
                .foregroundStyle(.tMuted)
                .frame(width: 30, alignment: .leading)
        }
        .padding(.vertical, 15)
        .padding(.horizontal, 17)
    }

    private func percentileRow(_ label: String, value: Double, metric: GrowthMetric) -> some View {
        let age = GrowthAge.months(from: baby.dateOfBirth, to: date)
        return HStack {
            Text(label)
                .font(.leona(15, .bold))
                .foregroundStyle(.tInk)
            Spacer(minLength: 0)
            GrowthPercentileBadge(percentile: metric.percentile(value: value, ageInMonths: age, gender: baby.gender))
        }
        .padding(.vertical, 11)
        .padding(.horizontal, 17)
    }

    // MARK: - Parsing (display unit → metric storage)

    private func parsed(_ text: String) -> Double? {
        let cleaned = text.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")
        guard let value = Double(cleaned), value > 0 else { return nil }
        return value
    }

    private var metricWeight: Double? { parsed(weightStr).map(UnitConversion.storageWeight) }
    private var metricHeight: Double? { parsed(heightStr).map(UnitConversion.storageHeight) }
    private var metricHead: Double? { parsed(headStr).map(UnitConversion.storageHeight) }

    private var hasAnyValue: Bool {
        metricWeight != nil || metricHeight != nil || metricHead != nil
    }

    // MARK: - Actions

    private func save() {
        guard hasAnyValue else { return }
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
        ActivityLogger.save(modelContext)
        NotificationCenter.default.post(name: .shouldPushLocalChanges, object: nil)
        HapticManager.success()
        dismiss()
    }

    private func deleteRecord() {
        guard let record = editingRecord else { return }
        ActivityLogger.delete(record, context: modelContext)
        HapticManager.impact(.light)
        dismiss()
    }
}
