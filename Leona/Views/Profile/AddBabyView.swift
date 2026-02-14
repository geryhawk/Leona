import SwiftUI
import SwiftData

struct AddBabyView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AppSettings.self) private var settings
    
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var dateOfBirth = Date()
    @State private var gender: BabyGender = .unspecified
    @State private var bloodType = ""
    
    private let bloodTypes = ["", "A+", "A-", "B+", "B-", "AB+", "AB-", "O+", "O-"]
    
    var body: some View {
        NavigationStack {
            Form {
                Section(String(localized: "basic_info")) {
                    TextField(String(localized: "first_name"), text: $firstName)
                    TextField(String(localized: "last_name"), text: $lastName)
                    
                    DatePicker(String(localized: "date_of_birth"), selection: $dateOfBirth, in: ...Date(), displayedComponents: .date)
                }
                
                Section(String(localized: "gender")) {
                    Picker(String(localized: "gender"), selection: $gender) {
                        ForEach(BabyGender.allCases) { g in
                            Label(g.displayName, systemImage: g.icon).tag(g)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
                Section(String(localized: "optional_info")) {
                    Picker(String(localized: "blood_type"), selection: $bloodType) {
                        ForEach(bloodTypes, id: \.self) { type in
                            Text(type.isEmpty ? String(localized: "not_specified") : type).tag(type)
                        }
                    }
                }
            }
            .navigationTitle(String(localized: "add_baby"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "save")) { save() }
                        .fontWeight(.semibold)
                        .disabled(firstName.isEmpty)
                }
            }
        }
    }
    
    private func save() {
        let baby = Baby(
            firstName: firstName.trimmingCharacters(in: .whitespaces),
            lastName: lastName.trimmingCharacters(in: .whitespaces),
            dateOfBirth: dateOfBirth,
            gender: gender,
            bloodType: bloodType
        )
        modelContext.insert(baby)
        settings.activeBabyID = baby.id.uuidString
        
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        dismiss()
    }
}
