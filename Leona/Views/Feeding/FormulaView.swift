import SwiftUI
import SwiftData

struct FormulaView: View {
    let baby: Baby
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @Query private var allActivities: [Activity]
    
    @State private var volume: Double = 90
    @State private var dateTime: Date = Date()
    @State private var noteText = ""
    @State private var showTimePicker = false
    
    private var lastFormulaVolume: Double? {
        allActivities
            .filter { $0.baby?.id == baby.id && $0.type == .formula }
            .sorted { $0.startTime > $1.startTime }
            .first?.volumeML
    }
    
    private var suggestedVolume: Double {
        lastFormulaVolume ?? MealForecastEngine.forecast(
            from: allActivities.filter { $0.baby?.id == baby.id },
            babyAgeInDays: baby.ageInDays
        )?.estimatedVolumeML ?? 90
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    // Volume display
                    volumeDisplay
                    
                    // Volume slider
                    volumeSlider
                    
                    // Quick volumes
                    quickVolumeButtons
                    
                    // Date/Time
                    dateTimeSection
                    
                    // Note
                    noteSection
                    
                    // Save button
                    saveButton
                }
                .padding()
            }
            .background(
                LinearGradient(
                    colors: [.orange.opacity(0.08), .white],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .navigationTitle(String(localized: "formula"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "cancel")) { dismiss() }
                }
            }
            .onAppear {
                volume = suggestedVolume
            }
        }
    }
    
    // MARK: - Volume Display
    
    private var volumeDisplay: some View {
        VStack(spacing: 8) {
            Image(systemName: "cup.and.saucer.fill")
                .font(.system(size: 48))
                .foregroundStyle(.orange)
            
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(Int(volume))")
                    .font(.system(size: 64, weight: .bold, design: .rounded))
                    .contentTransition(.numericText())
                    .animation(.spring(response: 0.3), value: volume)
                
                Text("ml")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.top, 20)
    }
    
    // MARK: - Volume Slider
    
    private var volumeSlider: some View {
        VStack(spacing: 8) {
            Slider(value: $volume, in: 10...350, step: 5) {
                Text(String(localized: "volume"))
            }
            .tint(.orange)
            
            HStack {
                Text("10 ml")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("350 ml")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 4)
    }
    
    // MARK: - Quick Volumes
    
    private var quickVolumeButtons: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(String(localized: "quick_volume"))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach([30, 60, 90, 120, 150, 180, 210, 240], id: \.self) { vol in
                        Button {
                            withAnimation(.spring(response: 0.3)) {
                                volume = Double(vol)
                            }
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        } label: {
                            Text("\(vol)")
                                .font(.subheadline.weight(.medium).monospacedDigit())
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(Int(volume) == vol ? .orange.opacity(0.2) : Color(.systemGray6))
                                .clipShape(Capsule())
                                .overlay(
                                    Capsule().stroke(Int(volume) == vol ? .orange : .clear, lineWidth: 1.5)
                                )
                        }
                        .foregroundStyle(Int(volume) == vol ? .orange : .primary)
                    }
                }
            }
        }
    }
    
    // MARK: - Date/Time
    
    private var dateTimeSection: some View {
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
    }
    
    // MARK: - Note
    
    private var noteSection: some View {
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
    }
    
    // MARK: - Save
    
    private var saveButton: some View {
        Button {
            saveFormula()
        } label: {
            Label(String(localized: "save_formula"), systemImage: "checkmark.circle.fill")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(LeonaButtonStyle(color: .orange))
    }
    
    private func saveFormula() {
        let activity = Activity(type: .formula, startTime: dateTime, baby: baby)
        activity.volumeML = volume
        if !noteText.isEmpty {
            activity.noteText = noteText
        }
        modelContext.insert(activity)
        
        // Schedule next feeding reminder
        Task {
            await NotificationManager.shared.scheduleFeedingReminder(
                babyName: baby.displayName,
                lastFeedingTime: dateTime
            )
        }
        
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        dismiss()
    }
}
