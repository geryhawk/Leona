import SwiftUI
import SwiftData

/// New health record: kind, dates, then whatever was observed so far.
struct HealthEntryView: View {
    let baby: Baby

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var illnessType: IllnessType = .cold
    @State private var startDate = Date()
    @State private var hasEndDate = false
    @State private var endDate = Date()
    @State private var notes = ""
    @State private var symptoms: [Symptom] = []
    @State private var medications: [Medication] = []
    @State private var temperatures: [TemperatureReading] = []

    init(baby: Baby) {
        self.baby = baby
    }

    var body: some View {
        VStack(spacing: 0) {
            InsightsSheetHeader(
                title: String(localized: "add_health_record"),
                onLeading: { dismiss() },
                onTrailing: save
            )

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    LeonaSectionLabel(String(localized: "illness_type"))
                    illnessPills

                    LeonaSectionLabel(String(localized: "dates"))
                        .padding(.top, 6)
                    LeonaGroup {
                        dateRow(String(localized: "start_date"), selection: $startDate)
                        LeonaToggleRow(title: String(localized: "has_end_date"), isOn: $hasEndDate)
                        if hasEndDate {
                            dateRow(String(localized: "end_date"), selection: $endDate)
                        }
                    }

                    LeonaSectionLabel(String(localized: "temperature"))
                        .padding(.top, 6)
                    HealthTemperatureEditor(temperatures: $temperatures)

                    LeonaSectionLabel(String(localized: "symptoms"))
                        .padding(.top, 6)
                    HealthSymptomEditor(symptoms: $symptoms)

                    LeonaSectionLabel(String(localized: "medications"))
                        .padding(.top, 6)
                    HealthMedicationEditor(medications: $medications)

                    LeonaSectionLabel(String(localized: "notes"))
                        .padding(.top, 6)
                    LeonaCard(padding: EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12)) {
                        TextEditor(text: $notes)
                            .font(.leona(15))
                            .foregroundStyle(.tInk)
                            .scrollContentBackground(.hidden)
                            .frame(minHeight: 80)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(18)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .background(Color.tCanvas.ignoresSafeArea())
    }

    // MARK: - Pieces

    private var illnessPills: some View {
        HealthFlowLayout(spacing: 7) {
            ForEach(IllnessType.allCases) { type in
                LeonaPill(title: type.displayName, isOn: illnessType == type, fontSize: 12, vertical: 9, horizontal: 14, fill: false) {
                    withAnimation(.easeOut(duration: 0.15)) { illnessType = type }
                }
            }
        }
    }

    private func dateRow(_ label: String, selection: Binding<Date>) -> some View {
        HStack(spacing: 12) {
            Text(label)
                .font(.leona(15, .bold))
                .foregroundStyle(.tInk)
            Spacer(minLength: 0)
            DatePicker("", selection: selection, displayedComponents: .date)
                .labelsHidden()
                .datePickerStyle(.compact)
        }
        .padding(.vertical, 11)
        .padding(.horizontal, 17)
    }

    // MARK: - Save

    private func save() {
        let record = HealthRecord(
            illnessType: illnessType,
            startDate: startDate,
            endDate: hasEndDate ? max(endDate, startDate) : nil,
            notes: notes,
            baby: baby
        )
        // Insert first so SwiftData tracks the embedded JSON mutations below.
        modelContext.insert(record)
        record.symptoms = symptoms
        record.medications = medications
        record.temperatures = temperatures

        ActivityLogger.save(modelContext)
        NotificationCenter.default.post(name: .shouldPushLocalChanges, object: nil)
        HapticManager.success()
        dismiss()
    }
}
