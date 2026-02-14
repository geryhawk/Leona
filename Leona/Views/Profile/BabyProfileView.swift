import SwiftUI
import SwiftData
import PhotosUI

struct BabyProfileView: View {
    @Bindable var baby: Baby
    
    @Environment(\.dismiss) private var dismiss
    
    @State private var firstName: String
    @State private var lastName: String
    @State private var dateOfBirth: Date
    @State private var gender: BabyGender
    @State private var bloodType: String
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var showRemovePhotoConfirm = false
    
    private let bloodTypes = ["", "A+", "A-", "B+", "B-", "AB+", "AB-", "O+", "O-"]
    
    init(baby: Baby) {
        self.baby = baby
        self._firstName = State(initialValue: baby.firstName)
        self._lastName = State(initialValue: baby.lastName)
        self._dateOfBirth = State(initialValue: baby.dateOfBirth)
        self._gender = State(initialValue: baby.gender)
        self._bloodType = State(initialValue: baby.bloodType)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                // Profile picture
                Section {
                    VStack(spacing: 16) {
                        // Photo
                        Group {
                            if let image = baby.profileImage {
                                image
                                    .resizable()
                                    .scaledToFill()
                            } else {
                                Image(systemName: "person.crop.circle.fill")
                                    .resizable()
                                    .foregroundStyle(baby.gender.color.opacity(0.4))
                            }
                        }
                        .frame(width: 100, height: 100)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(.quaternary, lineWidth: 1))
                        
                        HStack(spacing: 16) {
                            PhotosPicker(selection: $selectedPhoto, matching: .images) {
                                Label(String(localized: "change_photo"), systemImage: "photo.on.rectangle")
                                    .font(.subheadline)
                            }
                            
                            if baby.profileImageData != nil {
                                Button(role: .destructive) {
                                    showRemovePhotoConfirm = true
                                } label: {
                                    Label(String(localized: "remove_photo"), systemImage: "trash")
                                        .font(.subheadline)
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
                }
                
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
                
                // Baby info
                Section(String(localized: "info")) {
                    HStack {
                        Text(String(localized: "age"))
                        Spacer()
                        Text(baby.ageDescription)
                            .foregroundStyle(.secondary)
                    }
                    
                    HStack {
                        Text(String(localized: "id"))
                        Spacer()
                        Text(baby.id.uuidString.prefix(8))
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle(String(localized: "edit_profile"))
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
            .onChange(of: selectedPhoto) { _, newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self) {
                        baby.profileImageData = data
                    }
                }
            }
            .confirmationDialog(
                String(localized: "remove_photo_confirm"),
                isPresented: $showRemovePhotoConfirm,
                titleVisibility: .visible
            ) {
                Button(String(localized: "remove"), role: .destructive) {
                    baby.profileImageData = nil
                }
            }
        }
    }
    
    private func save() {
        baby.firstName = firstName.trimmingCharacters(in: .whitespaces)
        baby.lastName = lastName.trimmingCharacters(in: .whitespaces)
        baby.dateOfBirth = dateOfBirth
        baby.gender = gender
        baby.bloodType = bloodType
        baby.updatedAt = Date()
        
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        dismiss()
    }
}
