import SwiftUI

// MARK: - Palette helpers shared by the health screens

enum HealthTone {
    /// Thresholds are in °C because stored readings are °C.
    static func temperature(_ celsius: Double) -> Color {
        if celsius >= 38.0 { return .vermilion }
        if celsius >= 37.5 { return .tLeonaInk }
        return .moss
    }

    static func severity(_ severity: SymptomSeverity) -> Color {
        switch severity {
        case .mild: return .moss
        case .moderate: return .tLeonaInk
        case .severe: return .vermilion
        }
    }
}

/// Save · Delete · Cancel row shown under an item being edited.
private struct HealthEditActions: View {
    let onSave: () -> Void
    let onDelete: () -> Void
    let onCancel: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            LeonaSmallButton(title: String(localized: "save"), tone: .vermilion, fontSize: 12, vertical: 8, horizontal: 14, radius: 10, action: onSave)
            Button(action: onDelete) {
                Text(String(localized: "delete"))
                    .font(.leona(13, .bold))
                    .foregroundStyle(.vermilion)
            }
            .buttonStyle(.plain)
            Spacer(minLength: 0)
            Button(action: onCancel) {
                Text(String(localized: "cancel"))
                    .font(.leona(13, .bold))
                    .foregroundStyle(.tMuted)
            }
            .buttonStyle(.plain)
        }
    }
}

private let healthRowInsets = EdgeInsets(top: 13, leading: 17, bottom: 13, trailing: 17)

// MARK: - Temperatures

struct HealthTemperatureEditor: View {
    @Binding var temperatures: [TemperatureReading]

    @State private var newDisplay: Double = UnitConversion.displayTemp(37.0)
    @State private var editingID: UUID?
    @State private var editingDisplay: Double = UnitConversion.displayTemp(37.0)

    private var sorted: [TemperatureReading] { temperatures.sorted { $0.measuredAt > $1.measuredAt } }

    var body: some View {
        LeonaGroup {
            ForEach(sorted) { reading in
                if editingID == reading.id {
                    editRow(reading)
                } else {
                    displayRow(reading)
                }
            }
            addRow
        }
    }

    private func displayRow(_ reading: TemperatureReading) -> some View {
        Button {
            editingID = reading.id
            editingDisplay = UnitConversion.displayTemp(reading.temperature)
        } label: {
            HStack(spacing: 11) {
                Circle().fill(HealthTone.temperature(reading.temperature)).frame(width: 8, height: 8)
                Text(UnitConversion.formatTemp(reading.temperature))
                    .font(.leona(15, .bold))
                    .foregroundStyle(HealthTone.temperature(reading.temperature))
                Spacer(minLength: 8)
                Text(reading.measuredAt.smartDateTimeString)
                    .font(.leona(12))
                    .foregroundStyle(.tMuted)
            }
            .padding(healthRowInsets)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func editRow(_ reading: TemperatureReading) -> some View {
        VStack(spacing: 10) {
            sliderRow(value: $editingDisplay)
            HealthEditActions(
                onSave: {
                    if let index = temperatures.firstIndex(where: { $0.id == reading.id }) {
                        temperatures[index].temperature = UnitConversion.storageTemp(editingDisplay)
                    }
                    editingID = nil
                    HapticManager.impact(.light)
                },
                onDelete: {
                    temperatures.removeAll { $0.id == reading.id }
                    editingID = nil
                    HapticManager.impact(.light)
                },
                onCancel: { editingID = nil }
            )
        }
        .padding(healthRowInsets)
    }

    private var addRow: some View {
        HStack(spacing: 10) {
            sliderRow(value: $newDisplay)
            LeonaSmallButton(title: String(localized: "add_temperature"), tone: .plum, fontSize: 12, vertical: 8, horizontal: 13, radius: 10) {
                temperatures.append(TemperatureReading(temperature: UnitConversion.storageTemp(newDisplay)))
            }
        }
        .padding(healthRowInsets)
    }

    private func sliderRow(value: Binding<Double>) -> some View {
        HStack(spacing: 10) {
            Slider(value: value, in: UnitConversion.tempSliderMin...UnitConversion.tempSliderMax, step: UnitConversion.tempSliderStep)
                .tint(HealthTone.temperature(UnitConversion.storageTemp(value.wrappedValue)))
            Text(String(format: "%.1f%@", value.wrappedValue, UnitConversion.tempUnit))
                .font(.leona(14, .bold))
                .monospacedDigit()
                .foregroundStyle(HealthTone.temperature(UnitConversion.storageTemp(value.wrappedValue)))
                .frame(width: 58, alignment: .trailing)
        }
    }
}

// MARK: - Symptoms

struct HealthSymptomEditor: View {
    @Binding var symptoms: [Symptom]

    @State private var newText = ""
    @State private var newSeverity: SymptomSeverity = .moderate
    @State private var editingID: UUID?
    @State private var editingText = ""
    @State private var editingSeverity: SymptomSeverity = .moderate

    var body: some View {
        LeonaGroup {
            ForEach(symptoms) { symptom in
                if editingID == symptom.id {
                    editRow(symptom)
                } else {
                    displayRow(symptom)
                }
            }
            addRow
        }
    }

    private func displayRow(_ symptom: Symptom) -> some View {
        Button {
            editingID = symptom.id
            editingText = symptom.description
            editingSeverity = symptom.severity
        } label: {
            HStack(spacing: 11) {
                Circle().fill(HealthTone.severity(symptom.severity)).frame(width: 8, height: 8)
                Text(symptom.description)
                    .font(.leona(15, .semibold))
                    .foregroundStyle(.tInk)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 8)
                Text(symptom.severity.displayName)
                    .font(.leona(11, .heavy))
                    .foregroundStyle(HealthTone.severity(symptom.severity))
                    .padding(.vertical, 4)
                    .padding(.horizontal, 9)
                    .background(HealthTone.severity(symptom.severity).opacity(0.14))
                    .clipShape(Capsule())
            }
            .padding(healthRowInsets)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func editRow(_ symptom: Symptom) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            LeonaTextField(placeholder: String(localized: "symptom_placeholder"), text: $editingText, height: 40, radius: 12)
            severityPills(selection: $editingSeverity)
            HealthEditActions(
                onSave: {
                    let text = editingText.trimmingCharacters(in: .whitespaces)
                    guard !text.isEmpty else { return }
                    if let index = symptoms.firstIndex(where: { $0.id == symptom.id }) {
                        symptoms[index].description = text
                        symptoms[index].severity = editingSeverity
                    }
                    editingID = nil
                    HapticManager.impact(.light)
                },
                onDelete: {
                    symptoms.removeAll { $0.id == symptom.id }
                    editingID = nil
                    HapticManager.impact(.light)
                },
                onCancel: { editingID = nil }
            )
        }
        .padding(healthRowInsets)
    }

    private var addRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                LeonaTextField(placeholder: String(localized: "symptom_placeholder"), text: $newText, height: 40, radius: 12, submitLabel: .done, onSubmit: addSymptom)
                LeonaSmallButton(title: String(localized: "add_symptom"), tone: .plum, fontSize: 12, vertical: 8, horizontal: 13, radius: 10, action: addSymptom)
            }
            severityPills(selection: $newSeverity)
        }
        .padding(healthRowInsets)
    }

    private func severityPills(selection: Binding<SymptomSeverity>) -> some View {
        HStack(spacing: 7) {
            ForEach(SymptomSeverity.allCases) { severity in
                LeonaPill(title: severity.displayName, isOn: selection.wrappedValue == severity, fontSize: 11, vertical: 7, horizontal: 12, fill: false) {
                    selection.wrappedValue = severity
                }
            }
        }
    }

    private func addSymptom() {
        let text = newText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        symptoms.append(Symptom(description: text, severity: newSeverity))
        newText = ""
        HapticManager.impact(.light)
    }
}

// MARK: - Medications

struct HealthMedicationEditor: View {
    @Binding var medications: [Medication]

    @State private var newName = ""
    @State private var newDosage = ""
    @State private var editingID: UUID?
    @State private var editingName = ""
    @State private var editingDosage = ""

    var body: some View {
        LeonaGroup {
            ForEach(medications) { medication in
                if editingID == medication.id {
                    editRow(medication)
                } else {
                    displayRow(medication)
                }
            }
            addRow
        }
    }

    private func displayRow(_ medication: Medication) -> some View {
        Button {
            editingID = medication.id
            editingName = medication.name
            editingDosage = medication.dosage
        } label: {
            HStack(spacing: 11) {
                ColorTick(color: .lilac, height: 18)
                VStack(alignment: .leading, spacing: 1) {
                    Text(medication.name)
                        .font(.leona(15, .semibold))
                        .foregroundStyle(.tInk)
                    if !medication.dosage.isEmpty {
                        Text(medication.dosage)
                            .font(.leona(12))
                            .foregroundStyle(.tMuted)
                    }
                }
                Spacer(minLength: 8)
                Text(medication.administeredAt.smartDateTimeString)
                    .font(.leona(12))
                    .foregroundStyle(.tMuted)
            }
            .padding(healthRowInsets)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func editRow(_ medication: Medication) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                LeonaTextField(placeholder: String(localized: "medication_name"), text: $editingName, height: 40, radius: 12)
                LeonaTextField(placeholder: String(localized: "dosage"), text: $editingDosage, height: 40, radius: 12)
                    .frame(width: 96)
            }
            HealthEditActions(
                onSave: {
                    let name = editingName.trimmingCharacters(in: .whitespaces)
                    guard !name.isEmpty else { return }
                    if let index = medications.firstIndex(where: { $0.id == medication.id }) {
                        medications[index].name = name
                        medications[index].dosage = editingDosage
                    }
                    editingID = nil
                    HapticManager.impact(.light)
                },
                onDelete: {
                    medications.removeAll { $0.id == medication.id }
                    editingID = nil
                    HapticManager.impact(.light)
                },
                onCancel: { editingID = nil }
            )
        }
        .padding(healthRowInsets)
    }

    private var addRow: some View {
        HStack(spacing: 8) {
            LeonaTextField(placeholder: String(localized: "medication_name"), text: $newName, height: 40, radius: 12, submitLabel: .done, onSubmit: addMedication)
            LeonaTextField(placeholder: String(localized: "dosage"), text: $newDosage, height: 40, radius: 12, submitLabel: .done, onSubmit: addMedication)
                .frame(width: 84)
            LeonaSmallButton(title: "+", tone: .plum, fontSize: 15, vertical: 7, horizontal: 13, radius: 10, action: addMedication)
        }
        .padding(healthRowInsets)
    }

    private func addMedication() {
        let name = newName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        medications.append(Medication(name: name, dosage: newDosage.trimmingCharacters(in: .whitespaces)))
        newName = ""
        newDosage = ""
        HapticManager.impact(.light)
    }
}

// MARK: - Wrapping row of pills

struct HealthFlowLayout: Layout {
    var spacing: CGFloat = 7

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var widest: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > maxWidth {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            widest = max(widest, x - spacing)
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: maxWidth == .infinity ? widest : maxWidth, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
