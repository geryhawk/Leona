import SwiftUI
import SwiftData

struct GrowthEntryView: View {
    let baby: Baby
    var editingRecord: GrowthRecord?
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @State private var date: Date
    @State private var weightKg: String
    @State private var heightCm: String
    @State private var headCm: String
    
    var isEditing: Bool { editingRecord != nil }
    
    init(baby: Baby, editingRecord: GrowthRecord? = nil) {
        self.baby = baby
        self.editingRecord = editingRecord
        self._date = State(initialValue: editingRecord?.date ?? Date())
        self._weightKg = State(initialValue: editingRecord?.weightKg.map { String(format: "%.2f", $0) } ?? "")
        self._heightCm = State(initialValue: editingRecord?.heightCm.map { String(format: "%.1f", $0) } ?? "")
        self._headCm = State(initialValue: editingRecord?.headCircumferenceCm.map { String(format: "%.1f", $0) } ?? "")
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section(String(localized: "measurement_date")) {
                    DatePicker(String(localized: "date"), selection: $date, displayedComponents: .date)
                }
                
                Section(String(localized: "measurements")) {
                    HStack {
                        Label(String(localized: "weight"), systemImage: "scalemass.fill")
                            .foregroundStyle(.blue)
                        Spacer()
                        TextField("0.00", text: $weightKg)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                        Text("kg")
                            .foregroundStyle(.secondary)
                    }
                    
                    HStack {
                        Label(String(localized: "height"), systemImage: "ruler.fill")
                            .foregroundStyle(.green)
                        Spacer()
                        TextField("0.0", text: $heightCm)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                        Text("cm")
                            .foregroundStyle(.secondary)
                    }
                    
                    HStack {
                        Label(String(localized: "head_circumference"), systemImage: "circle.dashed")
                            .foregroundStyle(.purple)
                        Spacer()
                        TextField("0.0", text: $headCm)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                        Text("cm")
                            .foregroundStyle(.secondary)
                    }
                }
                
                // Percentile preview
                if hasAnyValue {
                    Section(String(localized: "percentiles")) {
                        if let weight = Double(weightKg) {
                            percentileRow(
                                label: String(localized: "weight"),
                                value: weight,
                                type: .weight,
                                color: .blue
                            )
                        }
                        if let height = Double(heightCm) {
                            percentileRow(
                                label: String(localized: "height"),
                                value: height,
                                type: .height,
                                color: .green
                            )
                        }
                        if let head = Double(headCm) {
                            percentileRow(
                                label: String(localized: "head_circumference"),
                                value: head,
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
    
    private var hasAnyValue: Bool {
        !weightKg.isEmpty || !heightCm.isEmpty || !headCm.isEmpty
    }
    
    private enum PercentileType {
        case weight, height, head
    }
    
    private func percentileRow(label: String, value: Double, type: PercentileType, color: Color) -> some View {
        let data: [WHOPercentilePoint]
        switch type {
        case .weight: data = WHODataService.weightPercentiles(gender: baby.gender)
        case .height: data = WHODataService.heightPercentiles(gender: baby.gender)
        case .head: data = WHODataService.headCircumferencePercentiles(gender: baby.gender)
        }
        
        let percentile = WHODataService.calculatePercentile(
            value: value,
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
            record.weightKg = Double(weightKg)
            record.heightCm = Double(heightCm)
            record.headCircumferenceCm = Double(headCm)
            record.updatedAt = Date()
        } else {
            let record = GrowthRecord(
                date: date,
                weightKg: Double(weightKg),
                heightCm: Double(heightCm),
                headCircumferenceCm: Double(headCm),
                baby: baby
            )
            modelContext.insert(record)
        }
        
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        dismiss()
    }
}
