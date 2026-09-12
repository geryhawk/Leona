import SwiftUI
import SwiftData

/// One health record, editable in place: notes, readings, symptoms, medications.
struct HealthDetailView: View {
    @Bindable var record: HealthRecord

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var showDeleteConfirm = false

    init(record: HealthRecord) {
        _record = Bindable(record)
    }

    var body: some View {
        VStack(spacing: 0) {
            InsightsSheetHeader(
                title: record.illnessType.displayName,
                leadingTitle: String(localized: "close"),
                trailingTitle: String(localized: "done"),
                onLeading: finish,
                onTrailing: finish
            )

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    heroCard

                    LeonaSectionLabel(String(localized: "notes"))
                        .padding(.top, 6)
                    notesCard

                    LeonaSectionLabel(String(localized: "temperature_readings"))
                        .padding(.top, 6)
                    HealthTemperatureEditor(temperatures: $record.temperatures)

                    LeonaSectionLabel(String(localized: "symptoms"))
                        .padding(.top, 6)
                    HealthSymptomEditor(symptoms: $record.symptoms)

                    LeonaSectionLabel(String(localized: "medications"))
                        .padding(.top, 6)
                    HealthMedicationEditor(medications: $record.medications)

                    LeonaGroup {
                        LeonaRow(title: String(localized: "delete_record"), destructive: true) {
                            showDeleteConfirm = true
                        }
                    }
                    .padding(.top, 10)
                }
                .padding(18)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .background(Color.tCanvas.ignoresSafeArea())
        .alert(String(localized: "delete_record"), isPresented: $showDeleteConfirm) {
            Button(String(localized: "delete"), role: .destructive) {
                ActivityLogger.delete(record, context: modelContext)
                HapticManager.impact(.light)
                dismiss()
            }
            Button(String(localized: "cancel"), role: .cancel) {}
        } message: {
            Text(String(localized: "delete_record_message"))
        }
    }

    // MARK: - Hero

    private var heroCard: some View {
        PlumCard(padding: 17) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 8) {
                    if record.isOngoing {
                        PulseDot(color: .breastDot, size: 7)
                    }
                    Text(kindLabel.uppercased())
                        .font(.leona(11, .heavy))
                        .leonaTracking(0.12, size: 11)
                        .foregroundStyle(.highlight)
                }
                Text(record.illnessType.displayName)
                    .font(.leona(25, .bold))
                    .leonaTracking(-0.03, size: 25)
                    .padding(.top, 9)
                Text("\(record.healthRangeText) · \(record.healthDurationText)")
                    .font(.leona(14))
                    .foregroundStyle(.white.opacity(0.78))
                    .padding(.top, 7)
                if record.isOngoing {
                    LeonaSmallButton(title: String(localized: "health_mark_resolved_short"), tone: .vermilion, fontSize: 13, vertical: 10, horizontal: 16, radius: 12) {
                        record.endDate = Date()
                        record.updatedAt = Date()
                        HapticManager.success()
                    }
                    .padding(.top, 14)
                }
            }
            .padding(.horizontal, 2)
        }
    }

    private var kindLabel: String {
        record.isOngoing
            ? String(localized: "health_pinned_active_day \((record.durationDays ?? 0) + 1)")
            : String(localized: "health_record_kind")
    }

    // MARK: - Notes

    private var notesCard: some View {
        LeonaCard(padding: EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12)) {
            TextEditor(text: Binding(
                get: { record.notes },
                set: {
                    record.notes = $0
                    record.updatedAt = Date()
                }
            ))
            .font(.leona(15))
            .foregroundStyle(.tInk)
            .scrollContentBackground(.hidden)
            .frame(minHeight: 80)
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Actions

    private func finish() {
        ActivityLogger.save(modelContext)
        NotificationCenter.default.post(name: .shouldPushLocalChanges, object: nil)
        dismiss()
    }
}
