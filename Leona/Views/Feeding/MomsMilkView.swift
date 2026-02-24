import SwiftUI
import SwiftData

struct MomsMilkView: View {
    let baby: Baby

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query private var allActivities: [Activity]

    /// Volume in display units (ml or oz depending on setting)
    @State private var displayVolume: Double = 90
    @State private var dateTime: Date = Date()
    @State private var noteText = ""

    private var settings: AppSettings { AppSettings.shared }

    private var lastMomsMilkVolume: Double? {
        allActivities
            .filter { $0.baby?.id == baby.id && $0.type == .momsMilk }
            .sorted { $0.startTime > $1.startTime }
            .first?.volumeML
    }

    private var suggestedVolumeMl: Double {
        lastMomsMilkVolume ?? MealForecastEngine.forecast(
            from: allActivities.filter { $0.baby?.id == baby.id },
            babyAgeInDays: baby.ageInDays
        )?.estimatedVolumeML ?? 90
    }

    /// Convert display value back to ml for storage
    private var storageMl: Double {
        UnitConversion.storageVolume(displayVolume)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    volumeDisplay
                    volumeSlider
                    quickVolumeButtons
                    dateTimeSection
                    noteSection
                    saveButton
                }
                .padding()
            }
            .background(
                LinearGradient(
                    colors: [.purple.opacity(0.08), Color(.systemBackground)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .navigationTitle(String(localized: "moms_milk"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "cancel")) { dismiss() }
                }
            }
            .onAppear {
                displayVolume = UnitConversion.displayVolume(suggestedVolumeMl)
            }
        }
    }

    // MARK: - Volume Display

    private var volumeDisplay: some View {
        VStack(spacing: 8) {
            Image(systemName: "drop.fill")
                .font(.system(size: 48))
                .foregroundStyle(.purple)

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(settings.useMetric ? "\(Int(displayVolume))" : String(format: "%.1f", displayVolume))
                    .font(.system(size: 64, weight: .bold, design: .rounded))
                    .contentTransition(.numericText())
                    .animation(.spring(response: 0.3), value: displayVolume)

                Text(UnitConversion.volumeUnit)
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.top, 20)
    }

    // MARK: - Volume Slider

    private var volumeSlider: some View {
        VStack(spacing: 8) {
            Slider(value: $displayVolume, in: UnitConversion.volumeSliderMin...UnitConversion.volumeSliderMax, step: UnitConversion.volumeSliderStep) {
                Text(String(localized: "volume"))
            }
            .tint(.purple)

            HStack {
                Text(settings.useMetric ? "\(Int(UnitConversion.volumeSliderMin)) \(UnitConversion.volumeUnit)" : String(format: "%.1f %@", UnitConversion.volumeSliderMin, UnitConversion.volumeUnit))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(settings.useMetric ? "\(Int(UnitConversion.volumeSliderMax)) \(UnitConversion.volumeUnit)" : String(format: "%.0f %@", UnitConversion.volumeSliderMax, UnitConversion.volumeUnit))
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
                    ForEach(UnitConversion.volumePresets, id: \.self) { presetMl in
                        let presetDisplay = UnitConversion.displayVolume(presetMl)
                        let isSelected = abs(displayVolume - presetDisplay) < 0.5
                        Button {
                            withAnimation(.spring(response: 0.3)) {
                                displayVolume = presetDisplay
                            }
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        } label: {
                            Text(UnitConversion.volumePresetLabel(presetMl))
                                .font(.subheadline.weight(.medium).monospacedDigit())
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(isSelected ? .purple.opacity(0.2) : Color(.systemGray6))
                                .clipShape(Capsule())
                                .overlay(
                                    Capsule().stroke(isSelected ? .purple : .clear, lineWidth: 1.5)
                                )
                        }
                        .foregroundStyle(isSelected ? .purple : .primary)
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
            saveMomsMilk()
        } label: {
            Label(String(localized: "save_moms_milk"), systemImage: "checkmark.circle.fill")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(LeonaButtonStyle(color: .purple))
    }

    private func saveMomsMilk() {
        let activity = Activity(type: .momsMilk, startTime: dateTime, baby: baby)
        activity.volumeML = storageMl
        if !noteText.isEmpty {
            activity.noteText = noteText
        }
        modelContext.insert(activity)

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
