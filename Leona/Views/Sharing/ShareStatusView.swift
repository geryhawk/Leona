import SwiftUI
import CloudKit

extension CKShare: @retroactive Identifiable {
    public var id: String { recordID.recordName }
}

struct ShareStatusView: View {
    let baby: Baby

    @Environment(SharingManager.self) private var sharing
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var isCreatingShare = false
    @State private var showStopConfirm = false
    @State private var showRemoveConfirm = false
    @State private var participantToRemove: CKShare.Participant?
    @State private var errorMessage: String?
    @State private var pendingShare: CKShare?
    @State private var isLoading = false

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
        .sheet(item: $pendingShare) { share in
            CloudSharingView(
                share: share,
                container: sharing.container,
                baby: baby,
                onDismiss: {
                    pendingShare = nil
                    // Refresh share info after dismissing
                    Task {
                        await sharing.fetchShareInfo(for: baby)
                    }
                }
            )
        }
        .task {
            if baby.isShared {
                isLoading = true
                await sharing.fetchShareInfo(for: baby)
                isLoading = false
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

            // Share button — opens Apple's UICloudSharingController
            Section {
                Button {
                    startSharing()
                } label: {
                    HStack {
                        Spacer()
                        if isCreatingShare {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Label(String(localized: "share_with_partner"), systemImage: "person.badge.plus")
                                .font(.headline)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isCreatingShare)
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            } footer: {
                Text(String(localized: "share_invite_footer"))
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

            // Add more parents / manage sharing (owner only)
            if baby.ownerName == nil {
                Section(String(localized: "share_add_parent")) {
                    Button {
                        startSharing()
                    } label: {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(String(localized: "share_with_partner"))
                                    .font(.subheadline.weight(.medium))
                                Text(String(localized: "share_send_link_desc"))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            if isCreatingShare {
                                ProgressView()
                            } else {
                                Image(systemName: "person.badge.plus")
                                    .font(.title2)
                                    .foregroundStyle(.leonaPrimary)
                            }
                        }
                    }
                    .disabled(isCreatingShare)
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

    /// Creates or fetches CKShare and presents UICloudSharingController
    private func startSharing() {
        isCreatingShare = true
        errorMessage = nil

        Task {
            do {
                let share = try await sharing.getOrCreateShare(for: baby, in: modelContext)

                await MainActor.run {
                    pendingShare = share
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
