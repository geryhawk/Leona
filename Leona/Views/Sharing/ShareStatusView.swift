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
    @State private var errorMessage: String?

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
        .navigationTitle(String(localized: "invite_partner"))
        .sheet(isPresented: $showShareSheet) {
            if let share = pendingShare {
                CloudSharingView(
                    share: share,
                    container: sharing.container,
                    baby: baby,
                    onDismiss: {
                        showShareSheet = false
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
        .task {
            if baby.isShared {
                await sharing.fetchShareInfo(for: baby)
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
            Section {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(String(localized: "sharing_active_label"))
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
                } icon: {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }

                if !sharing.participants.isEmpty {
                    ForEach(sharing.participants, id: \.userIdentity.userRecordID) { participant in
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(participant.userIdentity.nameComponents?.formatted() ?? String(localized: "partner"))
                                Text(participantStatus(participant))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: "person.fill")
                                .foregroundStyle(.leonaPrimary)
                        }
                    }
                }
            } header: {
                Text(String(localized: "partner_sharing"))
            }

            // Only show stop sharing if we're the owner
            if baby.ownerName == nil {
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

    private func participantStatus(_ participant: CKShare.Participant) -> String {
        switch participant.acceptanceStatus {
        case .accepted: return String(localized: "participant_accepted")
        case .pending: return String(localized: "participant_pending")
        case .removed: return String(localized: "participant_removed")
        default: return String(localized: "participant_unknown")
        }
    }
}
