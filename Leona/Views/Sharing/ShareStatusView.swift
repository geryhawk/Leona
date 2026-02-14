import SwiftUI
import CloudKit

struct ShareStatusView: View {
    let baby: Baby

    @Environment(SharingManager.self) private var sharing
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var isCreatingShare = false
    @State private var showShareSheet = false
    @State private var pendingShare: CKShare?
    @State private var showStopConfirm = false
    @State private var showRemoveConfirm = false
    @State private var participantToRemove: CKShare.Participant?
    @State private var errorMessage: String?
    @State private var isLoading = false

    var body: some View {
        List {
            if baby.isShared {
                sharedSection
            } else {
                notSharedSection
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
        .sheet(isPresented: $showShareSheet) {
            if let share = pendingShare {
                CloudSharingView(
                    share: share,
                    container: sharing.container,
                    baby: baby,
                    onDismiss: {
                        showShareSheet = false
                        // Refresh share info after the sharing controller closes
                        Task { await sharing.fetchShareInfo(for: baby) }
                    }
                )
            }
        }
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
        .task {
            if baby.isShared {
                isLoading = true
                await sharing.fetchShareInfo(for: baby)
                isLoading = false
            }
        }
    }

    // MARK: - Not Shared

    private var notSharedSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                Label {
                    Text(String(localized: "share_description"))
                        .font(.subheadline)
                } icon: {
                    Image(systemName: "person.2.fill")
                        .foregroundStyle(.leonaPrimary)
                }

                Text(String(localized: "share_explanation"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)

            Button {
                createAndShare()
            } label: {
                HStack {
                    Spacer()
                    if isCreatingShare {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Label(String(localized: "share_with_partner_button"), systemImage: "square.and.arrow.up")
                    }
                    Spacer()
                }
                .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .disabled(isCreatingShare)
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
        } header: {
            Text(String(localized: "partner_sharing"))
        }
    }

    // MARK: - Shared

    private var sharedSection: some View {
        Group {
            // Status
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

            // Participants
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

            // Add more / Re-share (owner only)
            if baby.ownerName == nil {
                Section {
                    Button {
                        reshare()
                    } label: {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(String(localized: "share_add_parent"))
                                    .font(.subheadline.weight(.medium))
                                Text(String(localized: "share_send_link_desc"))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: "person.badge.plus")
                                .font(.title2)
                                .foregroundStyle(.leonaPrimary)
                        }
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
                Text(participantStatusText(participant))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(participantBadge(participant))
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

    private func createAndShare() {
        isCreatingShare = true
        errorMessage = nil

        Task {
            do {
                let share = try await sharing.createShare(for: baby, in: modelContext)
                await MainActor.run {
                    pendingShare = share
                    showShareSheet = true
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

    private func reshare() {
        guard let share = sharing.activeShare else {
            // No active share in memory — fetch it first then show
            isCreatingShare = true
            Task {
                await sharing.fetchShareInfo(for: baby)
                await MainActor.run {
                    if let share = sharing.activeShare {
                        pendingShare = share
                        showShareSheet = true
                    } else {
                        errorMessage = String(localized: "share_fetch_error")
                    }
                    isCreatingShare = false
                }
            }
            return
        }

        pendingShare = share
        showShareSheet = true
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

    private func participantStatusText(_ participant: CKShare.Participant) -> String {
        switch participant.acceptanceStatus {
        case .accepted: return String(localized: "participant_accepted")
        case .pending: return String(localized: "participant_pending")
        case .removed: return String(localized: "participant_removed")
        default: return String(localized: "participant_unknown")
        }
    }

    private func participantBadge(_ participant: CKShare.Participant) -> String {
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
