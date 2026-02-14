import SwiftUI
import CloudKit

struct ShareStatusView: View {
    let baby: Baby

    @Environment(SharingManager.self) private var sharing
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var isCreatingShare = false
    @State private var showStopConfirm = false
    @State private var errorMessage: String?
    @State private var inviteEmail = ""
    @State private var showShareLink = false
    @State private var pendingShare: CKShare?

    var body: some View {
        List {
            if baby.isShared {
                sharedSection
            } else {
                inviteSection
            }

            if let error = errorMessage {
                Section {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                        .font(.caption)
                }
            }
        }
        .navigationTitle(String(localized: "partner_sharing"))
        .navigationBarTitleDisplayMode(.inline)
        .alert(String(localized: "stop_sharing_title"), isPresented: $showStopConfirm) {
            Button(String(localized: "stop_sharing"), role: .destructive) {
                stopSharing()
            }
            Button(String(localized: "cancel"), role: .cancel) {}
        } message: {
            Text(String(localized: "stop_sharing_message"))
        }
        .sheet(isPresented: $showShareLink) {
            if let share = pendingShare, let url = share.url {
                ShareLinkSheet(url: url, babyName: baby.displayName)
            }
        }
        .task {
            if baby.isShared {
                await sharing.fetchShareInfo(for: baby)
            }
        }
    }

    // MARK: - Not Shared — Invite

    private var inviteSection: some View {
        Group {
            Section {
                VStack(spacing: 16) {
                    Image(systemName: "person.2.circle.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.leonaPrimary)

                    Text(String(localized: "share_description"))
                        .font(.subheadline)
                        .multilineTextAlignment(.center)

                    Text(String(localized: "share_explanation"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .listRowBackground(Color.clear)
            }

            // Invite by email
            Section {
                HStack(spacing: 12) {
                    Image(systemName: "envelope.fill")
                        .foregroundStyle(.leonaPrimary)
                    TextField(String(localized: "share_email_placeholder"), text: $inviteEmail)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }

                Button {
                    inviteByEmail()
                } label: {
                    HStack {
                        Spacer()
                        if isCreatingShare {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Label(String(localized: "share_invite_by_email"), systemImage: "paperplane.fill")
                        }
                        Spacer()
                    }
                    .padding(.vertical, 4)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isCreatingShare || !isValidEmail(inviteEmail))
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            } header: {
                Text(String(localized: "share_invite_header"))
            } footer: {
                Text(String(localized: "share_invite_footer"))
            }

            // Or share link
            Section {
                Button {
                    shareViaLink()
                } label: {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(String(localized: "share_send_link"))
                                .font(.subheadline.weight(.medium))
                            Text(String(localized: "share_send_link_desc"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "link.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.leonaPrimary)
                    }
                }
                .disabled(isCreatingShare)
            } header: {
                Text(String(localized: "share_or"))
            }
        }
    }

    // MARK: - Shared State

    private var sharedSection: some View {
        Group {
            Section {
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.green)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(String(localized: "sharing_active_label"))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.green)
                        if let owner = baby.ownerName {
                            Text(String(localized: "shared_by \(owner)"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            Text(String(localized: "you_are_sharing"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            if !sharing.participants.isEmpty {
                Section(String(localized: "share_participants")) {
                    ForEach(sharing.participants, id: \.userIdentity.userRecordID) { participant in
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(participantColor(participant).opacity(0.15))
                                    .frame(width: 36, height: 36)
                                Image(systemName: "person.fill")
                                    .foregroundStyle(participantColor(participant))
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text(participant.userIdentity.nameComponents?.formatted() ?? String(localized: "partner"))
                                    .font(.subheadline.weight(.medium))
                                Text(participantStatus(participant))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Image(systemName: participantIcon(participant))
                                .foregroundStyle(participantColor(participant))
                        }
                    }
                }
            }

            // Re-share link (owner only)
            if baby.ownerName == nil {
                Section {
                    Button {
                        shareViaLink()
                    } label: {
                        Label(String(localized: "share_send_link"), systemImage: "link.circle.fill")
                    }
                    .disabled(isCreatingShare)
                }

                Section {
                    Button(role: .destructive) {
                        showStopConfirm = true
                    } label: {
                        Label(String(localized: "stop_sharing"), systemImage: "xmark.circle")
                    }
                }
            }
        }
    }

    // MARK: - Actions

    private func inviteByEmail() {
        isCreatingShare = true
        errorMessage = nil

        Task {
            do {
                let share: CKShare
                if baby.isShared, let existing = sharing.activeShare {
                    share = existing
                } else {
                    share = try await sharing.createShare(for: baby, in: modelContext)
                }

                // Look up and add participant by email
                let lookupInfo = CKUserIdentity.LookupInfo(emailAddress: inviteEmail)
                let identities = try await sharing.container.userIdentities(matching: [lookupInfo])

                if let identity = identities.first?.1 {
                    let participant = CKShare.Participant()
                    share.addParticipant(participant)
                    try await sharing.container.privateCloudDatabase.modifyRecords(
                        saving: [share],
                        deleting: [],
                        savePolicy: .changedKeys
                    )
                }

                await MainActor.run {
                    pendingShare = share
                    showShareLink = true
                    isCreatingShare = false
                    inviteEmail = ""
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isCreatingShare = false
                }
            }
        }
    }

    private func shareViaLink() {
        isCreatingShare = true
        errorMessage = nil

        Task {
            do {
                let share: CKShare
                if baby.isShared, let existing = sharing.activeShare {
                    share = existing
                } else {
                    share = try await sharing.createShare(for: baby, in: modelContext)
                }

                await MainActor.run {
                    pendingShare = share
                    showShareLink = true
                    isCreatingShare = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isCreatingShare = false
                }
            }
        }
    }

    private func stopSharing() {
        Task {
            do {
                try await sharing.stopSharing(for: baby, in: modelContext)
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    // MARK: - Helpers

    private func isValidEmail(_ email: String) -> Bool {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        return trimmed.contains("@") && trimmed.contains(".")
    }

    private func participantStatus(_ participant: CKShare.Participant) -> String {
        switch participant.acceptanceStatus {
        case .accepted: return String(localized: "participant_accepted")
        case .pending: return String(localized: "participant_pending")
        case .removed: return String(localized: "participant_removed")
        default: return String(localized: "participant_unknown")
        }
    }

    private func participantIcon(_ participant: CKShare.Participant) -> String {
        switch participant.acceptanceStatus {
        case .accepted: return "checkmark.circle.fill"
        case .pending: return "clock.fill"
        case .removed: return "xmark.circle.fill"
        default: return "questionmark.circle"
        }
    }

    private func participantColor(_ participant: CKShare.Participant) -> Color {
        switch participant.acceptanceStatus {
        case .accepted: return .green
        case .pending: return .orange
        case .removed: return .red
        default: return .secondary
        }
    }
}

// MARK: - Share Link Sheet

struct ShareLinkSheet: View {
    let url: URL
    let babyName: String

    @Environment(\.dismiss) private var dismiss
    @State private var copied = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                Image(systemName: "link.circle.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.leonaPrimary)

                VStack(spacing: 8) {
                    Text(String(localized: "share_link_ready"))
                        .font(.title3.bold())
                    Text(String(localized: "share_link_explanation"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                // Link preview
                HStack {
                    Image(systemName: "link")
                        .foregroundStyle(.secondary)
                    Text(url.absoluteString)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                .padding()
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)

                // Share button
                ShareLink(
                    item: url,
                    subject: Text("Leona"),
                    message: Text(String(localized: "share_link_message \(babyName)"))
                ) {
                    HStack {
                        Spacer()
                        Label(String(localized: "share_send_link"), systemImage: "square.and.arrow.up")
                            .font(.headline)
                        Spacer()
                    }
                    .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal)

                // Copy link
                Button {
                    UIPasteboard.general.url = url
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    copied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) { copied = false }
                } label: {
                    Label(
                        copied ? String(localized: "share_link_copied") : String(localized: "share_copy_link"),
                        systemImage: copied ? "checkmark" : "doc.on.doc"
                    )
                    .font(.subheadline)
                    .animation(.easeInOut, value: copied)
                }

                Spacer()
            }
            .navigationTitle(String(localized: "partner_sharing"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "done")) { dismiss() }
                }
            }
        }
    }
}
