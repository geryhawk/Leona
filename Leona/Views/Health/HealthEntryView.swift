import SwiftUI
import SwiftData

struct HealthEntryView: View {
    let baby: Baby

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var illnessType: IllnessType = .cold
    @State private var startDate = Date()
    @State private var hasEndDate = false
    @State private var endDate = Date()
    @State private var notes = ""

    // Symptoms
    @State private var symptoms: [Symptom] = []
    @State private var newSymptom = ""
    @State private var newSeverity: SymptomSeverity = .moderate

    // Medications
    @State private var medications: [Medication] = []
    @State private var newMedName = ""
    @State private var newMedDosage = ""

    // Temperature — slider works in display units, stored in °C
    @State private var temperatures: [TemperatureReading] = []
    @State private var newTempDisplay: Double = UnitConversion.displayTemp(37.0)

    /// Convert display slider value to °C for storage
    private var newTempCelsius: Double { UnitConversion.storageTemp(newTempDisplay) }

    var body: some View {
        NavigationStack {
            Form {
                illnessTypeSection
                datesSection
                temperatureSection
                symptomsSection
                medicationsSection
                notesSection
            }
            .navigationTitle(String(localized: "add_health_record"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "save")) { save() }
                        .fontWeight(.semibold)
                }
            }
        }
    }

    // MARK: - Sections

    private var illnessTypeSection: some View {
        Section(String(localized: "illness_type")) {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(IllnessType.allCases) { type in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { illnessType = type }
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: type.icon)
                                .foregroundStyle(type.color)
                                .font(.subheadline)
                            Text(type.displayName)
                                .font(.caption.weight(illnessType == type ? .semibold : .regular))
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                        .background(illnessType == type ? type.color.opacity(0.12) : Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(illnessType == type ? type.color : .clear, lineWidth: 1.5)
                        )
                        .scaleEffect(illnessType == type ? 1.02 : 1.0)
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.primary)
                }
            }
        }
    }

    private var datesSection: some View {
        Section(String(localized: "dates")) {
            DatePicker(String(localized: "start_date"), selection: $startDate, displayedComponents: .date)
            Toggle(String(localized: "has_end_date"), isOn: $hasEndDate)
            if hasEndDate {
                DatePicker(String(localized: "end_date"), selection: $endDate, displayedComponents: .date)
            }
        }
    }

    private var temperatureSection: some View {
        Section(String(localized: "temperature")) {
            HStack {
                Slider(value: $newTempDisplay, in: UnitConversion.tempSliderMin...UnitConversion.tempSliderMax, step: UnitConversion.tempSliderStep)
                    .tint(temperatureColor(newTempCelsius))
                Text(String(format: "%.1f%@", newTempDisplay, UnitConversion.tempUnit))
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(temperatureColor(newTempCelsius))
                    .frame(width: 80, alignment: .trailing)
            }
            Button {
                addTemperature()
            } label: {
                Label(String(localized: "add_temperature"), systemImage: "plus.circle.fill")
            }
            ForEach(temperatures) { temp in
                HStack {
                    Text(UnitConversion.formatTemp(temp.temperature))
                        .foregroundStyle(temperatureColor(temp.temperature))
                    Spacer()
                    Text(temp.measuredAt.timeString)
                        .foregroundStyle(.secondary)
                }
            }
            .onDelete { indexSet in
                temperatures.remove(atOffsets: indexSet)
            }
        }
    }

    private var symptomsSection: some View {
        Section(String(localized: "symptoms")) {
            HStack {
                TextField(String(localized: "symptom_placeholder"), text: $newSymptom)
                Picker("", selection: $newSeverity) {
                    ForEach(SymptomSeverity.allCases) { sev in
                        Text(sev.displayName).tag(sev)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 100)
                Button {
                    addSymptom()
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(.leonaPink)
                }
                .disabled(newSymptom.isEmpty)
            }
            ForEach(symptoms) { symptom in
                HStack {
                    Circle()
                        .fill(symptom.severity.color)
                        .frame(width: 8)
                    Text(symptom.description)
                    Spacer()
                    Text(symptom.severity.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .onDelete { indexSet in
                symptoms.remove(atOffsets: indexSet)
            }
        }
    }

    private var medicationsSection: some View {
        Section(String(localized: "medications")) {
            TextField(String(localized: "medication_name"), text: $newMedName)
            TextField(String(localized: "dosage"), text: $newMedDosage)
            Button {
                addMedication()
            } label: {
                Label(String(localized: "add_medication"), systemImage: "plus.circle.fill")
                    .foregroundStyle(newMedName.isEmpty ? Color.secondary : Color.leonaPink)
            }
            .disabled(newMedName.isEmpty)
            ForEach(medications) { med in
                HStack {
                    Image(systemName: "pills.fill")
                        .foregroundStyle(.teal)
                    Text(med.name)
                    if !med.dosage.isEmpty {
                        Text("(\(med.dosage))")
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(med.administeredAt.timeString)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .onDelete { indexSet in
                medications.remove(atOffsets: indexSet)
            }
        }
    }

    private var notesSection: some View {
        Section(String(localized: "notes")) {
            TextEditor(text: $notes)
                .frame(minHeight: 80)
        }
    }

    private func addTemperature() {
        // Store in °C regardless of display unit
        temperatures.append(TemperatureReading(temperature: newTempCelsius))
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func addSymptom() {
        guard !newSymptom.isEmpty else { return }
        symptoms.append(Symptom(description: newSymptom, severity: newSeverity))
        newSymptom = ""
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func addMedication() {
        guard !newMedName.isEmpty else { return }
        medications.append(Medication(name: newMedName, dosage: newMedDosage))
        newMedName = ""
        newMedDosage = ""
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    /// Temperature color thresholds (always in °C since stored values are °C)
    private func temperatureColor(_ tempCelsius: Double) -> Color {
        if tempCelsius >= 39.0 { return .red }
        if tempCelsius >= 38.0 { return .orange }
        if tempCelsius >= 37.5 { return .yellow }
        return .green
    }

    private func save() {
        let record = HealthRecord(
            illnessType: illnessType,
            startDate: startDate,
            endDate: hasEndDate ? endDate : nil,
            notes: notes,
            baby: baby
        )
        // Insert into context FIRST so SwiftData tracks property changes
        modelContext.insert(record)

        // Now set embedded JSON data — context tracks these mutations
        record.symptoms = symptoms
        record.medications = medications
        record.temperatures = temperatures

        try? modelContext.save()

        UINotificationFeedbackGenerator().notificationOccurred(.success)
        dismiss()
    }
}
