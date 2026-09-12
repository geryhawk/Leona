import SwiftUI
import SwiftData
import PhotosUI

/// Sheet that edits the baby's identity, photo, and can delete the whole thread.
struct BabyEditView: View {
    let baby: Baby

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AppSettings.self) private var settings
    @Environment(SharingManager.self) private var sharing

    @Query(sort: \Baby.createdAt) private var babies: [Baby]

    @State private var firstName: String
    @State private var lastName: String
    @State private var dateOfBirth: Date
    @State private var gender: BabyGender
    @State private var bloodType: String
    @State private var photoItem: PhotosPickerItem?
    @State private var showRemovePhotoConfirm = false
    @State private var showDeleteConfirm = false
    @State private var showDeleteLastConfirm = false
    @State private var isDeleting = false

    private static let bloodTypes = ["", "A+", "A-", "B+", "B-", "AB+", "AB-", "O+", "O-"]

    init(baby: Baby) {
        self.baby = baby
        _firstName = State(initialValue: baby.firstName)
        _lastName = State(initialValue: baby.lastName)
        _dateOfBirth = State(initialValue: baby.dateOfBirth)
        _gender = State(initialValue: baby.gender)
        _bloodType = State(initialValue: baby.bloodType)
    }

    private var canSave: Bool {
        !firstName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    photoBlock
                    LeonaGroup {
                        textRow(String(localized: "first_name"), text: $firstName, placeholder: String(localized: "baby_name_placeholder"))
                        textRow(String(localized: "last_name"), text: $lastName, placeholder: String(localized: "last_name_placeholder"))
                        dateRow
                        genderRow
                        bloodRow
                    }
                    LeonaGroup {
                        LeonaRow(title: String(localized: "profile_delete_thread \(baby.displayName)"), destructive: true) {
                            confirmDelete()
                        }
                    }
                }
                .padding(18)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .background(Color.tCanvas.ignoresSafeArea())
        .onChange(of: photoItem) { _, item in
            loadPhoto(item)
        }
        .confirmationDialog(
            String(localized: "remove_photo_confirm"),
            isPresented: $showRemovePhotoConfirm,
            titleVisibility: .visible
        ) {
            Button(String(localized: "remove"), role: .destructive) { removePhoto() }
        }
        .confirmationDialog(
            String(localized: "profile_delete_thread_confirm \(baby.displayName)"),
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button(String(localized: "delete"), role: .destructive) { deleteThread() }
        } message: {
            Text(String(localized: "profile_delete_thread_warning"))
        }
        .alert(String(localized: "profile_delete_last_title"), isPresented: $showDeleteLastConfirm) {
            Button(String(localized: "profile_delete_and_reset"), role: .destructive) { deleteThread() }
            Button(String(localized: "cancel"), role: .cancel) {}
        } message: {
            Text(String(localized: "profile_delete_last_message"))
        }
    }

    // MARK: - Header

    private var header: some View {
        ZStack {
            Text(String(localized: "edit_profile"))
                .font(.leona(16, .bold))
                .foregroundStyle(.tInk)
            HStack {
                Button { dismiss() } label: {
                    Text(String(localized: "cancel"))
                        .font(.leona(15, .semibold))
                        .foregroundStyle(.tMuted)
                }
                .buttonStyle(.plain)
                Spacer()
                Button { save() } label: {
                    Text(String(localized: "save"))
                        .font(.leona(15, .bold))
                        .foregroundStyle(canSave ? Color.vermilion : Color.tDisabled)
                }
                .buttonStyle(.plain)
                .disabled(!canSave)
            }
        }
        .padding(.horizontal, 18)
        .frame(height: 54)
        .overlay(alignment: .bottom) { Rectangle().fill(Color.tLine).frame(height: 1) }
    }

    // MARK: - Photo

    private var photoBlock: some View {
        VStack(spacing: 12) {
            BabyAvatar(baby: baby, size: 100, radius: 30)
            HStack(spacing: 18) {
                PhotosPicker(selection: $photoItem, matching: .images) {
                    Text(String(localized: "change_photo"))
                        .font(.leona(13, .bold))
                        .foregroundStyle(.vermilion)
                }
                .buttonStyle(.plain)
                if baby.profileImageData != nil {
                    Button { showRemovePhotoConfirm = true } label: {
                        Text(String(localized: "remove_photo"))
                            .font(.leona(13, .bold))
                            .foregroundStyle(.tMuted)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
    }

    private func loadPhoto(_ item: PhotosPickerItem?) {
        guard let item else { return }
        Task {
            guard let data = try? await item.loadTransferable(type: Data.self) else { return }
            baby.profileImageData = data
            baby.updatedAt = Date()
            ActivityLogger.save(modelContext)
            HapticManager.success()
            photoItem = nil
        }
    }

    private func removePhoto() {
        baby.profileImageData = nil
        baby.updatedAt = Date()
        ActivityLogger.save(modelContext)
        HapticManager.impact(.light)
    }

    // MARK: - Rows

    private func textRow(_ label: String, text: Binding<String>, placeholder: String) -> some View {
        HStack(spacing: 12) {
            Text(label)
                .font(.leona(14))
                .foregroundStyle(.tMuted)
            TextField(placeholder, text: text)
                .font(.leona(15, .bold))
                .foregroundStyle(.tInk)
                .multilineTextAlignment(.trailing)
                .submitLabel(.done)
        }
        .padding(.vertical, 15)
        .padding(.horizontal, 17)
    }

    private var dateRow: some View {
        HStack(spacing: 12) {
            Text(String(localized: "date_of_birth"))
                .font(.leona(14))
                .foregroundStyle(.tMuted)
            Spacer(minLength: 0)
            DatePicker("", selection: $dateOfBirth, in: ...Date(), displayedComponents: .date)
                .labelsHidden()
                .tint(.vermilion)
        }
        .padding(.vertical, 11)
        .padding(.horizontal, 17)
    }

    private var genderRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(String(localized: "gender"))
                .font(.leona(14))
                .foregroundStyle(.tMuted)
            HStack(spacing: 7) {
                ForEach(BabyGender.allCases) { option in
                    LeonaPill(title: option.displayName, isOn: gender == option, tone: .plum, fontSize: 13, vertical: 9) {
                        gender = option
                    }
                }
            }
        }
        .padding(.vertical, 15)
        .padding(.horizontal, 17)
    }

    private var bloodRow: some View {
        HStack(spacing: 12) {
            Text(String(localized: "blood_type"))
                .font(.leona(14))
                .foregroundStyle(.tMuted)
            Spacer(minLength: 0)
            Menu {
                ForEach(Self.bloodTypes, id: \.self) { type in
                    Button {
                        bloodType = type
                        HapticManager.selection()
                    } label: {
                        let title = type.isEmpty ? String(localized: "not_specified") : type
                        if bloodType == type {
                            Label(title, systemImage: "checkmark")
                        } else {
                            Text(title)
                        }
                    }
                }
            } label: {
                HStack(spacing: 5) {
                    Text(bloodType.isEmpty ? String(localized: "not_specified") : bloodType)
                        .font(.leona(15, .bold))
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 11, weight: .bold))
                }
                .foregroundStyle(bloodType.isEmpty ? Color.tMuted : Color.tInk)
            }
        }
        .padding(.vertical, 15)
        .padding(.horizontal, 17)
    }

    // MARK: - Save

    private func save() {
        baby.firstName = firstName.trimmingCharacters(in: .whitespaces)
        baby.lastName = lastName.trimmingCharacters(in: .whitespaces)
        baby.dateOfBirth = dateOfBirth
        baby.gender = gender
        baby.bloodType = bloodType
        baby.updatedAt = Date()
        ActivityLogger.save(modelContext)
        HapticManager.success()
        dismiss()
    }

    // MARK: - Delete the thread

    private func confirmDelete() {
        if babies.count <= 1 {
            showDeleteLastConfirm = true
        } else {
            showDeleteConfirm = true
        }
    }

    /// Ports the old selector's deleteBaby / deleteLastBaby: stop sharing, cascade, switch or clear the active baby.
    private func deleteThread() {
        guard !isDeleting else { return }
        isDeleting = true

        let doomed = baby
        let replacement = babies.first { $0.id != doomed.id }
        let context = modelContext
        let sharing = sharing
        let settings = settings

        Task { @MainActor in
            if doomed.isShared {
                try? await sharing.stopSharing(for: doomed, in: context)
            }
            for activity in doomed.activities ?? [] {
                context.delete(activity)
            }
            for record in doomed.growthRecords ?? [] {
                context.delete(record)
            }
            for record in doomed.healthRecords ?? [] {
                context.delete(record)
            }
            context.delete(doomed)
            try? context.save()

            settings.activeBabyID = replacement?.id.uuidString
            HapticManager.success()
            dismiss()
        }
    }
}
