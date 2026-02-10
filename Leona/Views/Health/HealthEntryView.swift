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
    
    // Temperature
    @State private var temperatures: [TemperatureReading] = []
    @State private var newTemp: Double = 37.0
    
    var body: some View {
        NavigationStack {
            Form {
                // Illness Type
                Section(String(localized: "illness_type")) {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                        ForEach(IllnessType.allCases) { type in
                            Button {
                                withAnimation { illnessType = type }
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: type.icon)
                                        .foregroundStyle(type.color)
                                    Text(type.displayName)
                                        .font(.caption)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(10)
                                .background(illnessType == type ? type.color.opacity(0.12) : Color(.systemGray6))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(illnessType == type ? type.color : .clear, lineWidth: 1.5)
                                )
                            }
                            .foregroundStyle(.primary)
                        }
                    }
                }
                
                // Dates
                Section(String(localized: "dates")) {
                    DatePicker(String(localized: "start_date"), selection: $startDate, displayedComponents: .date)
                    
                    Toggle(String(localized: "has_end_date"), isOn: $hasEndDate)
                    
                    if hasEndDate {
                        DatePicker(String(localized: "end_date"), selection: $endDate, displayedComponents: .date)
                    }
                }
                
                // Temperature
                Section(String(localized: "temperature")) {
                    HStack {
                        Slider(value: $newTemp, in: 35.0...42.0, step: 0.1)
                            .tint(temperatureColor(newTemp))
                        
                        Text(String(format: "%.1f°C", newTemp))
                            .font(.headline.monospacedDigit())
                            .foregroundStyle(temperatureColor(newTemp))
                            .frame(width: 70, alignment: .trailing)
                    }
                    
                    Button {
                        addTemperature()
                    } label: {
                        Label(String(localized: "add_temperature"), systemImage: "plus.circle.fill")
                    }
                    
                    ForEach(temperatures) { temp in
                        HStack {
                            Text(String(format: "%.1f°C", temp.temperature))
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
                
                // Symptoms
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
                
                // Medications
                Section(String(localized: "medications")) {
                    HStack {
                        TextField(String(localized: "medication_name"), text: $newMedName)
                        TextField(String(localized: "dosage"), text: $newMedDosage)
                            .frame(width: 80)
                        
                        Button {
                            addMedication()
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(.leonaPink)
                        }
                        .disabled(newMedName.isEmpty)
                    }
                    
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
                
                // Notes
                Section(String(localized: "notes")) {
                    TextEditor(text: $notes)
                        .frame(minHeight: 80)
                }
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
    
    private func addTemperature() {
        temperatures.append(TemperatureReading(temperature: newTemp))
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
    
    private func temperatureColor(_ temp: Double) -> Color {
        if temp >= 39.0 { return .red }
        if temp >= 38.0 { return .orange }
        if temp >= 37.5 { return .yellow }
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
        record.symptoms = symptoms
        record.medications = medications
        record.temperatures = temperatures
        
        modelContext.insert(record)
        
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        dismiss()
    }
}
