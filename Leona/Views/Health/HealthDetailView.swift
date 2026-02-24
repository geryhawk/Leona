import SwiftUI
import SwiftData

struct HealthDetailView: View {
    @Bindable var record: HealthRecord

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var newTemp: Double = 37.0
    @State private var newSymptom = ""
    @State private var newSymptomSeverity: SymptomSeverity = .moderate
    @State private var newMedName = ""
    @State private var newMedDosage = ""
    @State private var editingTempID: UUID?
    @State private var editingTempValue: Double = 37.0
    @State private var editingSymptomID: UUID?
    @State private var editingSymptomText = ""
    @State private var editingSymptomSeverity: SymptomSeverity = .moderate
    @State private var editingMedID: UUID?
    @State private var editingMedName = ""
    @State private var editingMedDosage = ""
    @State private var showDeleteConfirm = false

    var body: some View {
        NavigationStack {
            List {
                // Overview
                overviewSection

                // Mark as resolved
                if record.isOngoing {
                    Section {
                        Button {
                            record.endDate = Date()
                            record.updatedAt = Date()
                            UINotificationFeedbackGenerator().notificationOccurred(.success)
                        } label: {
                            Label(String(localized: "mark_resolved"), systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        }
                    }
                }

                // Notes (editable)
                Section(String(localized: "notes")) {
                    TextEditor(text: Binding(
                        get: { record.notes },
                        set: { record.notes = $0; record.updatedAt = Date() }
                    ))
                    .frame(minHeight: 60)
                }

                // Temperatures
                temperatureSection

                // Symptoms
                symptomSection

                // Medications
                medicationSection

                // Delete
                Section {
                    Button(role: .destructive) {
                        showDeleteConfirm = true
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
            .alert(String(localized: "delete_record"), isPresented: $showDeleteConfirm) {
                Button(String(localized: "delete"), role: .destructive) {
                    modelContext.delete(record)
                    try? modelContext.save()
                    dismiss()
                }
                Button(String(localized: "cancel"), role: .cancel) {}
            } message: {
                Text(String(localized: "delete_record_message"))
            }
        }
    }

    // MARK: - Overview

    private var overviewSection: some View {
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
    }

    // MARK: - Temperatures

    private var temperatureSection: some View {
        Section(String(localized: "temperature_readings")) {
            ForEach(record.temperatures.sorted(by: { $0.measuredAt > $1.measuredAt })) { temp in
                if editingTempID == temp.id {
                    // Inline editing
                    HStack {
                        Slider(value: $editingTempValue, in: 35...42, step: 0.1)
                            .tint(tempColor(editingTempValue))

                        Text(String(format: "%.1f°C", editingTempValue))
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(tempColor(editingTempValue))
                            .frame(width: 55)

                        Button {
                            saveEditedTemp(id: temp.id)
                        } label: {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        }

                        Button {
                            editingTempID = nil
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                    }
                } else {
                    // Display mode
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
                    .contentShape(Rectangle())
                    .onTapGesture {
                        editingTempID = temp.id
                        editingTempValue = temp.temperature
                    }
                }
            }
            .onDelete { indexSet in
                deleteTemperatures(at: indexSet)
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
    }

    // MARK: - Symptoms

    private var symptomSection: some View {
        Section(String(localized: "symptoms")) {
            ForEach(record.symptoms) { symptom in
                if editingSymptomID == symptom.id {
                    // Inline editing
                    VStack(spacing: 8) {
                        TextField(String(localized: "add_symptom"), text: $editingSymptomText)

                        HStack {
                            Picker("", selection: $editingSymptomSeverity) {
                                ForEach(SymptomSeverity.allCases) { sev in
                                    Text(sev.displayName).tag(sev)
                                }
                            }
                            .pickerStyle(.segmented)

                            Button {
                                saveEditedSymptom(id: symptom.id)
                            } label: {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                            }

                            Button {
                                editingSymptomID = nil
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                } else {
                    // Display mode
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
                    .contentShape(Rectangle())
                    .onTapGesture {
                        editingSymptomID = symptom.id
                        editingSymptomText = symptom.description
                        editingSymptomSeverity = symptom.severity
                    }
                }
            }
            .onDelete { indexSet in
                deleteSymptoms(at: indexSet)
            }

            // Add new symptom
            HStack {
                TextField(String(localized: "add_symptom"), text: $newSymptom)

                Picker("", selection: $newSymptomSeverity) {
                    ForEach(SymptomSeverity.allCases) { sev in
                        Text(sev.displayName).tag(sev)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 100)

                Button {
                    guard !newSymptom.isEmpty else { return }
                    var syms = record.symptoms
                    syms.append(Symptom(description: newSymptom, severity: newSymptomSeverity))
                    record.symptoms = syms
                    newSymptom = ""
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(.leonaPink)
                }
                .disabled(newSymptom.isEmpty)
            }
        }
    }

    // MARK: - Medications

    private var medicationSection: some View {
        Section(String(localized: "medications")) {
            ForEach(record.medications) { med in
                if editingMedID == med.id {
                    // Inline editing
                    VStack(spacing: 8) {
                        HStack {
                            TextField(String(localized: "medication_name"), text: $editingMedName)
                            TextField(String(localized: "dosage"), text: $editingMedDosage)
                                .frame(width: 80)
                        }

                        HStack {
                            Spacer()
                            Button {
                                saveEditedMed(id: med.id)
                            } label: {
                                Label(String(localized: "save"), systemImage: "checkmark.circle.fill")
                                    .font(.subheadline)
                                    .foregroundStyle(.green)
                            }

                            Button {
                                editingMedID = nil
                            } label: {
                                Label(String(localized: "cancel"), systemImage: "xmark.circle.fill")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                } else {
                    // Display mode
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
                    .contentShape(Rectangle())
                    .onTapGesture {
                        editingMedID = med.id
                        editingMedName = med.name
                        editingMedDosage = med.dosage
                    }
                }
            }
            .onDelete { indexSet in
                deleteMedications(at: indexSet)
            }

            // Add new medication
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
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(.leonaPink)
                }
                .disabled(newMedName.isEmpty)
            }
        }
    }

    // MARK: - Edit/Delete Helpers

    private func saveEditedTemp(id: UUID) {
        var temps = record.temperatures
        if let index = temps.firstIndex(where: { $0.id == id }) {
            temps[index].temperature = editingTempValue
            record.temperatures = temps
        }
        editingTempID = nil
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func deleteTemperatures(at offsets: IndexSet) {
        var temps = record.temperatures.sorted(by: { $0.measuredAt > $1.measuredAt })
        temps.remove(atOffsets: offsets)
        record.temperatures = temps
    }

    private func saveEditedSymptom(id: UUID) {
        guard !editingSymptomText.isEmpty else { return }
        var syms = record.symptoms
        if let index = syms.firstIndex(where: { $0.id == id }) {
            syms[index].description = editingSymptomText
            syms[index].severity = editingSymptomSeverity
            record.symptoms = syms
        }
        editingSymptomID = nil
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func deleteSymptoms(at offsets: IndexSet) {
        var syms = record.symptoms
        syms.remove(atOffsets: offsets)
        record.symptoms = syms
    }

    private func saveEditedMed(id: UUID) {
        guard !editingMedName.isEmpty else { return }
        var meds = record.medications
        if let index = meds.firstIndex(where: { $0.id == id }) {
            meds[index].name = editingMedName
            meds[index].dosage = editingMedDosage
            record.medications = meds
        }
        editingMedID = nil
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func deleteMedications(at offsets: IndexSet) {
        var meds = record.medications
        meds.remove(atOffsets: offsets)
        record.medications = meds
    }

    // MARK: - Helpers

    private func tempColor(_ temp: Double) -> Color {
        if temp >= 39.0 { return .red }
        if temp >= 38.0 { return .orange }
        if temp >= 37.5 { return .yellow }
        return .green
    }
}
