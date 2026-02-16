import SwiftUI
import CloudKit

struct ShareStatusView: View {
    let baby: Baby

    @Environment(SharingManager.self) private var sharing
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    // Email invitation state
    @State private var partnerEmail = ""
    @State private var isInviting = false
    @State private var inviteSuccess = false

    // Link sharing state
    @State private var isGeneratingLink = false
    @State private var shareURL: URL?
    @State private var linkCopied = false
    @State private var showShareSheet = false

    // General state
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showStopConfirm = false
    @State private var showRemoveConfirm = false
    @State private var participantToRemove: CKShare.Participant?


    /// Whether we have a confirmed active share (not just stale local flag)
    private var hasActiveShare: Bool {
        baby.isShared && sharing.activeShare != nil
    }

    var body: some View {
        List {
            if isLoading {
                Section {
                    HStack {
                        Spacer()
                        ProgressView()
                            .padding()
                        Spacer()
                    }
                }
            } else if hasActiveShare {
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
        .alert(String(localized: "remove_participant_title"), isPresented: $showRemoveConfirm) {
            Button(String(localized: "remove"), role: .destructive) {
                if let participant = participantToRemove {
                    removeParticipant(participant)
                }
            }
            Button(String(localized: "cancel"), role: .cancel) {
                participantToRemove = nil
            }
        } message: {
            Text(String(localized: "remove_participant_message"))
        }
        .sheet(isPresented: $showShareSheet) {
            if let url = shareURL {
                ShareActivityView(
                    activityItems: [
                        String(localized: "share_link_message \(baby.displayName)"),
                        url
                    ],
                    onDismiss: {
                        showShareSheet = false
                    }
                )
            }
        }
        .task {
            if baby.isShared {
                isLoading = true
                await sharing.fetchShareInfo(for: baby)
                // If fetchShareInfo didn't find a share, the baby's isShared is stale
                // getOrCreateShare will clean it up on next action
                isLoading = false
            }
        }
    }

    // MARK: - Not Shared — Invite

    private var inviteSection: some View {
        Group {
            // Description header
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
                VStack(spacing: 12) {
                    HStack(spacing: 10) {
                        Image(systemName: "envelope.fill")
                            .foregroundStyle(.leonaPrimary)
                            .frame(width: 24)

                        TextField(String(localized: "share_email_placeholder"), text: $partnerEmail)
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .disabled(isInviting)
                    }

                    Button {
                        inviteByEmail()
                    } label: {
                        HStack {
                            Spacer()
                            if isInviting {
                                ProgressView()
                                    .tint(.white)
                                Text(String(localized: "share_invite_sending"))
                                    .font(.subheadline.weight(.semibold))
                            } else if inviteSuccess {
                                Image(systemName: "checkmark.circle.fill")
                                Text(String(localized: "share_invite_success"))
                                    .font(.subheadline.weight(.semibold))
                            } else {
                                Image(systemName: "paperplane.fill")
                                Text(String(localized: "share_invite_by_email"))
                                    .font(.subheadline.weight(.semibold))
                            }
                            Spacer()
                        }
                        .padding(.vertical, 10)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(inviteSuccess ? .green : .leonaPrimary)
                    .disabled(isInviting || !isValidEmail(partnerEmail))
                }
            } header: {
                Label(String(localized: "share_invite_header"), systemImage: "person.badge.plus")
            } footer: {
                Text(String(localized: "share_invite_footer"))
            }

            // Or share a link
            Section {
                Button {
                    generateAndShareLink()
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
                        if isGeneratingLink {
                            ProgressView()
                        } else {
                            Image(systemName: "link.badge.plus")
                                .font(.title2)
                                .foregroundStyle(.leonaPrimary)
                        }
                    }
                }
                .disabled(isGeneratingLink)
            } header: {
                Label(String(localized: "share_or"), systemImage: "arrow.left.arrow.right")
            }

            // Show share URL if generated
            if let url = shareURL {
                Section {
                    VStack(alignment: .leading, spacing: 10) {
                        Label(String(localized: "share_link_ready"), systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.subheadline.weight(.semibold))

                        Text(url.absoluteString)
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                            .textSelection(.enabled)

                        HStack(spacing: 12) {
                            Button {
                                UIPasteboard.general.url = url
                                withAnimation {
                                    linkCopied = true
                                }
                                UINotificationFeedbackGenerator().notificationOccurred(.success)
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                    withAnimation { linkCopied = false }
                                }
                            } label: {
                                Label(
                                    linkCopied ? String(localized: "share_link_copied") : String(localized: "share_copy_link"),
                                    systemImage: linkCopied ? "checkmark" : "doc.on.doc"
                                )
                                .font(.caption.weight(.medium))
                            }
                            .buttonStyle(.bordered)
                            .tint(linkCopied ? .green : .leonaPrimary)

                            Button {
                                showShareSheet = true
                            } label: {
                                Label(String(localized: "share_send_link"), systemImage: "square.and.arrow.up")
                                    .font(.caption.weight(.medium))
                            }
                            .buttonStyle(.bordered)
                            .tint(.leonaPrimary)
                        }
                    }
                    .padding(.vertical, 4)
                } footer: {
                    Text(String(localized: "share_link_explanation"))
                }
            }
        }
    }

    // MARK: - Shared State

    private var sharedSection: some View {
        Group {
            // Status banner
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

            // Participants list
            Section {
                if isLoading {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                } else if sharing.participants.isEmpty {
                    HStack(spacing: 12) {
                        Image(systemName: "person.slash")
                            .foregroundStyle(.secondary)
                        Text(String(localized: "no_participants_yet"))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    ForEach(sharing.participants, id: \.userIdentity.userRecordID) { participant in
                        participantRow(participant)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                if baby.ownerName == nil {
                                    Button(role: .destructive) {
                                        participantToRemove = participant
                                        showRemoveConfirm = true
                                    } label: {
                                        Label(String(localized: "remove"), systemImage: "trash")
                                    }
                                }
                            }
                    }
                }
            } header: {
                HStack {
                    Text(String(localized: "share_participants"))
                    Spacer()
                    if !sharing.participants.isEmpty {
                        Text("\(sharing.participants.count)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            // Add more parents (owner only)
            if baby.ownerName == nil {
                // Invite by email
                Section {
                    VStack(spacing: 12) {
                        HStack(spacing: 10) {
                            Image(systemName: "envelope.fill")
                                .foregroundStyle(.leonaPrimary)
                                .frame(width: 24)

                            TextField(String(localized: "share_email_placeholder"), text: $partnerEmail)
                                .textContentType(.emailAddress)
                                .keyboardType(.emailAddress)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                                .disabled(isInviting)
                        }

                        Button {
                            inviteByEmail()
                        } label: {
                            HStack {
                                Spacer()
                                if isInviting {
                                    ProgressView()
                                        .tint(.white)
                                    Text(String(localized: "share_invite_sending"))
                                        .font(.subheadline.weight(.semibold))
                                } else if inviteSuccess {
                                    Image(systemName: "checkmark.circle.fill")
                                    Text(String(localized: "share_invite_success"))
                                        .font(.subheadline.weight(.semibold))
                                } else {
                                    Image(systemName: "paperplane.fill")
                                    Text(String(localized: "share_invite_by_email"))
                                        .font(.subheadline.weight(.semibold))
                                }
                                Spacer()
                            }
                            .padding(.vertical, 8)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(inviteSuccess ? .green : .leonaPrimary)
                        .disabled(isInviting || !isValidEmail(partnerEmail))
                    }
                } header: {
                    Label(String(localized: "share_add_parent"), systemImage: "person.badge.plus")
                } footer: {
                    Text(String(localized: "share_invite_footer"))
                }

                // Share link
                Section {
                    Button {
                        generateAndShareLink()
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
                            if isGeneratingLink {
                                ProgressView()
                            } else {
                                Image(systemName: "link.badge.plus")
                                    .font(.title2)
                                    .foregroundStyle(.leonaPrimary)
                            }
                        }
                    }
                    .disabled(isGeneratingLink)
                }

                // Show share URL if generated
                if let url = shareURL {
                    Section {
                        VStack(alignment: .leading, spacing: 10) {
                            Label(String(localized: "share_link_ready"), systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                                .font(.subheadline.weight(.semibold))

                            Text(url.absoluteString)
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                                .textSelection(.enabled)

                            HStack(spacing: 12) {
                                Button {
                                    UIPasteboard.general.url = url
                                    withAnimation { linkCopied = true }
                                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                        withAnimation { linkCopied = false }
                                    }
                                } label: {
                                    Label(
                                        linkCopied ? String(localized: "share_link_copied") : String(localized: "share_copy_link"),
                                        systemImage: linkCopied ? "checkmark" : "doc.on.doc"
                                    )
                                    .font(.caption.weight(.medium))
                                }
                                .buttonStyle(.bordered)
                                .tint(linkCopied ? .green : .leonaPrimary)

                                Button {
                                    showShareSheet = true
                                } label: {
                                    Label(String(localized: "share_send_link"), systemImage: "square.and.arrow.up")
                                        .font(.caption.weight(.medium))
                                }
                                .buttonStyle(.bordered)
                                .tint(.leonaPrimary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                // Stop sharing
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

    // MARK: - Participant Row

    private func participantRow(_ participant: CKShare.Participant) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(participantColor(participant).opacity(0.15))
                    .frame(width: 40, height: 40)
                Image(systemName: "person.fill")
                    .font(.subheadline)
                    .foregroundStyle(participantColor(participant))
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(participantName(participant))
                    .font(.subheadline.weight(.medium))
                Text(participantStatus(participant))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(participantRoleLabel(participant))
                .font(.caption2.weight(.medium))
                .foregroundStyle(participantColor(participant))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(participantColor(participant).opacity(0.12))
                .clipShape(Capsule())
        }
        .padding(.vertical, 2)
    }

    // MARK: - Actions

    /// Invites a partner by their iCloud email address
    private func inviteByEmail() {
        let email = partnerEmail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        guard isValidEmail(email) else {
            errorMessage = String(localized: "share_error_invalid_email")
            return
        }

        isInviting = true
        errorMessage = nil
        inviteSuccess = false

        Task {
            do {
                try await sharing.addParticipantByEmail(email, for: baby, in: modelContext)

                await MainActor.run {
                    isInviting = false
                    inviteSuccess = true
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                }

                // Reset success state after a delay
                try? await Task.sleep(for: .seconds(3))
                await MainActor.run {
                    inviteSuccess = false
                    partnerEmail = ""
                }
            } catch {
                await MainActor.run {
                    isInviting = false
                    errorMessage = error.localizedDescription
                    UINotificationFeedbackGenerator().notificationOccurred(.error)
                }
            }
        }
    }

    /// Generates a share link and opens the system share sheet
    private func generateAndShareLink() {
        isGeneratingLink = true
        errorMessage = nil

        Task {
            do {
                let url = try await sharing.getShareURL(for: baby, in: modelContext)

                await MainActor.run {
                    shareURL = url
                    isGeneratingLink = false
                    showShareSheet = true
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                }
            } catch {
                await MainActor.run {
                    isGeneratingLink = false
                    errorMessage = error.localizedDescription
                    UINotificationFeedbackGenerator().notificationOccurred(.error)
                }
            }
        }
    }

    private func removeParticipant(_ participant: CKShare.Participant) {
        Task {
            do {
                try await sharing.removeParticipant(participant, for: baby)
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                }
            }
            participantToRemove = nil
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

    // MARK: - Validation

    private func isValidEmail(_ email: String) -> Bool {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        // Simple but effective email validation
        let parts = trimmed.split(separator: "@")
        guard parts.count == 2 else { return false }
        let domain = parts[1]
        return domain.contains(".") && domain.count >= 3
    }

    // MARK: - Helpers

    private func participantName(_ participant: CKShare.Participant) -> String {
        if let name = participant.userIdentity.nameComponents?.formatted() {
            return name
        }
        if let email = participant.userIdentity.lookupInfo?.emailAddress {
            return email
        }
        return String(localized: "partner")
    }

    private func participantStatus(_ participant: CKShare.Participant) -> String {
        switch participant.acceptanceStatus {
        case .accepted: return String(localized: "participant_accepted")
        case .pending: return String(localized: "participant_pending")
        case .removed: return String(localized: "participant_removed")
        default: return String(localized: "participant_unknown")
        }
    }

    private func participantRoleLabel(_ participant: CKShare.Participant) -> String {
        switch participant.acceptanceStatus {
        case .accepted: return String(localized: "role_active")
        case .pending: return String(localized: "role_invited")
        case .removed: return String(localized: "role_removed")
        default: return String(localized: "participant_unknown")
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
