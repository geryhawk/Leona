import SwiftUI
import SwiftData

struct DiaperEntryView: View {
    let baby: Baby
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @State private var selectedType: DiaperType = .pee
    @State private var dateTime: Date = Date()
    @State private var noteText = ""
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    // Icon
                    Image(systemName: "humidity.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(.cyan)
                        .padding(.top, 24)
                    
                    // Diaper type selection
                    VStack(alignment: .leading, spacing: 12) {
                        Text(String(localized: "diaper_type"))
                            .font(.headline)
                        
                        HStack(spacing: 12) {
                            ForEach(DiaperType.allCases) { type in
                                Button {
                                    withAnimation(.spring(response: 0.3)) {
                                        selectedType = type
                                    }
                                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                } label: {
                                    VStack(spacing: 10) {
                                        ZStack {
                                            Circle()
                                                .fill(selectedType == type ? type.color.opacity(0.2) : Color(.systemGray6))
                                                .frame(width: 64, height: 64)
                                            
                                            Image(systemName: type.icon)
                                                .font(.title2)
                                                .foregroundStyle(selectedType == type ? type.color : .secondary)
                                        }
                                        
                                        Text(type.displayName)
                                            .font(.subheadline.weight(.medium))
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background(
                                        selectedType == type
                                            ? type.color.opacity(0.08)
                                            : Color.clear
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(
                                                selectedType == type ? type.color : Color(.systemGray4),
                                                lineWidth: selectedType == type ? 2 : 1
                                            )
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                                }
                                .foregroundStyle(selectedType == type ? type.color : .primary)
                            }
                        }
                    }
                    
                    // Date/Time
                    VStack(alignment: .leading, spacing: 8) {
                        Text(String(localized: "date_time"))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                        
                        DatePicker(String(localized: "date_time"), selection: $dateTime)
                            .labelsHidden()
                            .padding()
                            .background(.ultraThinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    
                    // Note
                    VStack(alignment: .leading, spacing: 8) {
                        Text(String(localized: "note_optional"))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                        
                        TextField(String(localized: "note_placeholder"), text: $noteText, axis: .vertical)
                            .lineLimit(2...4)
                            .padding()
                            .background(.ultraThinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    
                    // Save
                    Button {
                        saveDiaper()
                    } label: {
                        Label(String(localized: "save_diaper"), systemImage: "checkmark.circle.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(LeonaButtonStyle(color: .cyan))
                }
                .padding()
            }
            .background(
                LinearGradient(
                    colors: [.cyan.opacity(0.08), .white],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .navigationTitle(String(localized: "diaper_change"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "cancel")) { dismiss() }
                }
            }
        }
    }
    
    private func saveDiaper() {
        let activity = Activity(type: .diaper, startTime: dateTime, baby: baby)
        activity.diaperType = selectedType
        if !noteText.isEmpty { activity.noteText = noteText }
        modelContext.insert(activity)
        
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        dismiss()
    }
}
