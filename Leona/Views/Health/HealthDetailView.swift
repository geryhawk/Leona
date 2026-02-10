import SwiftUI
import SwiftData

struct HealthDetailView: View {
    @Bindable var record: HealthRecord
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @State private var showEndDatePicker = false
    @State private var newTemp: Double = 37.0
    @State private var newSymptom = ""
    @State private var newMedName = ""
    @State private var newMedDosage = ""
    
    var body: some View {
        NavigationStack {
            List {
                // Overview
                Section {
                    HStack(spacing: 12) {
                        Image(systemName: record.illnessType.icon)
                            .font(.title)
                            .foregroundStyle(record.illnessType.color)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(record.illnessType.displayName)
                                .font(.title3.bold())
                            
                            HStack {
                                Text(record.startDate.dateString)
                                if let end = record.endDate {
                                    Image(systemName: "arrow.right")
                                        .font(.caption)
                                    Text(end.dateString)
                                }
                            }
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                        
                        if record.isOngoing {
                            Text(String(localized: "ongoing"))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(.red)
                                .clipShape(Capsule())
                        }
                    }
                }
                
                // Mark as resolved
                if record.isOngoing {
                    Section {
                        Button {
                            record.endDate = Date()
                            record.updatedAt = Date()
                        } label: {
                            Label(String(localized: "mark_resolved"), systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        }
                    }
                }
                
                // Temperatures
                Section(String(localized: "temperature_readings")) {
                    ForEach(record.temperatures.sorted(by: { $0.measuredAt > $1.measuredAt })) { temp in
                        HStack {
                            Image(systemName: temp.isHighFever ? "thermometer.high" : temp.isFever ? "thermometer.medium" : "thermometer.low")
                                .foregroundStyle(tempColor(temp.temperature))
                            
                            Text(String(format: "%.1f°C", temp.temperature))
                                .font(.headline.monospacedDigit())
                                .foregroundStyle(tempColor(temp.temperature))
                            
                            Spacer()
                            
                            Text(temp.measuredAt.smartDateTimeString)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    // Add new temperature
                    HStack {
                        Slider(value: $newTemp, in: 35...42, step: 0.1)
                            .tint(tempColor(newTemp))
                        
                        Text(String(format: "%.1f°C", newTemp))
                            .font(.subheadline.monospacedDigit())
                            .frame(width: 55)
                        
                        Button {
                            var temps = record.temperatures
                            temps.append(TemperatureReading(temperature: newTemp))
                            record.temperatures = temps
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(.leonaPink)
                        }
                    }
                }
                
                // Symptoms
                Section(String(localized: "symptoms")) {
                    ForEach(record.symptoms) { symptom in
                        HStack {
                            Circle()
                                .fill(symptom.severity.color)
                                .frame(width: 8)
                            Text(symptom.description)
                            Spacer()
                            Text(symptom.severity.displayName)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(symptom.severity.color.opacity(0.15))
                                .clipShape(Capsule())
                        }
                    }
                    
                    HStack {
                        TextField(String(localized: "add_symptom"), text: $newSymptom)
                        Button {
                            guard !newSymptom.isEmpty else { return }
                            var syms = record.symptoms
                            syms.append(Symptom(description: newSymptom))
                            record.symptoms = syms
                            newSymptom = ""
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(.leonaPink)
                        }
                    }
                }
                
                // Medications
                Section(String(localized: "medications")) {
                    ForEach(record.medications) { med in
                        HStack {
                            Image(systemName: "pills.fill")
                                .foregroundStyle(.teal)
                            VStack(alignment: .leading) {
                                Text(med.name)
                                    .font(.subheadline.weight(.medium))
                                if !med.dosage.isEmpty {
                                    Text(med.dosage)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            Text(med.administeredAt.smartDateTimeString)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    HStack {
                        TextField(String(localized: "medication_name"), text: $newMedName)
                        TextField(String(localized: "dosage"), text: $newMedDosage)
                            .frame(width: 70)
                        Button {
                            guard !newMedName.isEmpty else { return }
                            var meds = record.medications
                            meds.append(Medication(name: newMedName, dosage: newMedDosage))
                            record.medications = meds
                            newMedName = ""
                            newMedDosage = ""
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(.leonaPink)
                        }
                    }
                }
                
                // Notes
                if !record.notes.isEmpty {
                    Section(String(localized: "notes")) {
                        Text(record.notes)
                    }
                }
                
                // Delete
                Section {
                    Button(role: .destructive) {
                        modelContext.delete(record)
                        dismiss()
                    } label: {
                        Label(String(localized: "delete_record"), systemImage: "trash")
                    }
                }
            }
            .navigationTitle(record.illnessType.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "done")) { dismiss() }
                }
            }
        }
    }
    
    private func tempColor(_ temp: Double) -> Color {
        if temp >= 39.0 { return .red }
        if temp >= 38.0 { return .orange }
        if temp >= 37.5 { return .yellow }
        return .green
    }
}
