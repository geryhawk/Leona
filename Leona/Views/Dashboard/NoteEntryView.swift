import SwiftUI
import SwiftData

struct NoteEntryView: View {
    let baby: Baby
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @State private var noteText = ""
    @State private var dateTime = Date()
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    Image(systemName: "note.text")
                        .font(.system(size: 48))
                        .foregroundStyle(.gray)
                        .padding(.top, 24)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text(String(localized: "note"))
                            .font(.headline)
                        
                        TextEditor(text: $noteText)
                            .frame(minHeight: 150)
                            .padding(8)
                            .background(.ultraThinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(.quaternary)
                            )
                    }
                    
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
                    
                    Button {
                        saveNote()
                    } label: {
                        Label(String(localized: "save_note"), systemImage: "checkmark.circle.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(LeonaButtonStyle(color: .gray))
                    .disabled(noteText.isEmpty)
                    .opacity(noteText.isEmpty ? 0.6 : 1)
                }
                .padding()
            }
            .navigationTitle(String(localized: "add_note"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "cancel")) { dismiss() }
                }
            }
        }
    }
    
    private func saveNote() {
        let activity = Activity(type: .note, startTime: dateTime, baby: baby)
        activity.noteText = noteText
        modelContext.insert(activity)
        
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        dismiss()
    }
}
