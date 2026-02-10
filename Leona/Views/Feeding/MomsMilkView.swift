import SwiftUI
import SwiftData

struct MomsMilkView: View {
    let baby: Baby
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @State private var volume: Double = 90
    @State private var dateTime: Date = Date()
    @State private var noteText = ""
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    // Volume display
                    VStack(spacing: 8) {
                        Image(systemName: "drop.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(.purple)
                        
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
                    
                    // Volume slider
                    VStack(spacing: 8) {
                        Slider(value: $volume, in: 10...350, step: 5) {
                            Text(String(localized: "volume"))
                        }
                        .tint(.purple)
                        
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
                    
                    // Quick volumes
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach([30, 60, 90, 120, 150, 180, 210], id: \.self) { vol in
                                Button {
                                    withAnimation(.spring(response: 0.3)) { volume = Double(vol) }
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                } label: {
                                    Text("\(vol)")
                                        .font(.subheadline.weight(.medium).monospacedDigit())
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 8)
                                        .background(Int(volume) == vol ? .purple.opacity(0.2) : Color(.systemGray6))
                                        .clipShape(Capsule())
                                        .overlay(Capsule().stroke(Int(volume) == vol ? .purple : .clear, lineWidth: 1.5))
                                }
                                .foregroundStyle(Int(volume) == vol ? .purple : .primary)
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
                        saveMomsMilk()
                    } label: {
                        Label(String(localized: "save_moms_milk"), systemImage: "checkmark.circle.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(LeonaButtonStyle(color: .purple))
                }
                .padding()
            }
            .background(
                LinearGradient(
                    colors: [.purple.opacity(0.08), .white],
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
        }
    }
    
    private func saveMomsMilk() {
        let activity = Activity(type: .momsMilk, startTime: dateTime, baby: baby)
        activity.volumeML = volume
        if !noteText.isEmpty { activity.noteText = noteText }
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
