import SwiftUI
import CloudKit

/// "PEOPLE": the local parent first, then everyone else on the CloudKit share.
struct SharingPeopleSection: View {
    let baby: Baby
    @Binding var errorMessage: String?

    @Environment(AppSettings.self) private var settings
    @Environment(SharingManager.self) private var sharing
    @Environment(ThreadNavigator.self) private var navigator

    @State private var showRenameAlert = false
    @State private var draftName = ""
    @State private var showRemoveConfirm = false
    @State private var participantToRemove: CKShare.Participant?

    private var isOwner: Bool { sharing.isShareOwner(for: baby) }

    private var myName: String {
        let name = settings.userDisplayName.trimmingCharacters(in: .whitespaces)
        return name.isEmpty ? String(localized: "profile_you") : name
    }

    /// "Camille · you" when a name is set, plain "You" otherwise (never "You · you").
    private var meRowTitle: String {
        settings.userDisplayName.trimmingCharacters(in: .whitespaces).isEmpty
            ? String(localized: "author_you")
            : String(localized: "sharing_me_row \(myName)")
    }

    private var others: [CKShare.Participant] {
        SharingView.others(for: baby, sharing: sharing)
    }

    var body: some View {
        VStack(spacing: 12) {
            Button {
                draftName = settings.userDisplayName
                showRenameAlert = true
            } label: {
                meRow
            }
            .buttonStyle(.plain)

            ForEach(Array(others.enumerated()), id: \.offset) { _, participant in
                participantRow(participant)
                    .contextMenu {
                        if isOwner, participant.role != .owner {
                            Button(role: .destructive) {
                                participantToRemove = participant
                                showRemoveConfirm = true
                            } label: {
                                Label(String(localized: "sharing_remove_participant"), systemImage: "person.badge.minus")
                            }
                        }
                    }
            }
        }
        .alert(String(localized: "sharing_your_name_title"), isPresented: $showRenameAlert) {
            TextField(String(localized: "sharing_your_name_placeholder"), text: $draftName)
            Button(String(localized: "save")) {
                settings.userDisplayName = draftName.trimmingCharacters(in: .whitespacesAndNewlines)
                HapticManager.success()
                navigator.flash(String(localized: "sharing_name_saved"))
            }
            Button(String(localized: "cancel"), role: .cancel) {}
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
    }

    // MARK: - Rows

    private var meRow: some View {
        SharingPersonRow(
            badgeName: myName,
            badgeColor: .tMine,
            title: meRowTitle,
            subtitle: (isOwner || !baby.isShared)
                ? String(localized: "sharing_role_owner")
                : String(localized: "sharing_role_editor")
        ) {
            HStack(spacing: 6) {
                Circle()
                    .fill(Color.moss)
                    .frame(width: 6, height: 6)
                Text(String(localized: "sharing_here_now"))
                    .font(.leona(12, .bold))
                    .foregroundStyle(.moss)
            }
        }
    }

    private func participantRow(_ participant: CKShare.Participant) -> some View {
        let name = SharingView.participantName(participant, sharing: sharing, ownerName: baby.ownerName)
        return SharingPersonRow(
            badgeName: name,
            badgeColor: .vermilion,
            title: name,
            subtitle: participant.role == .owner
                ? String(localized: "sharing_role_owner")
                : String(localized: "sharing_role_editor")
        ) {
            Text(Self.statusText(participant))
                .font(.leona(12, .bold))
                .foregroundStyle(.tMuted)
        }
    }

    private static func statusText(_ participant: CKShare.Participant) -> String {
        switch participant.acceptanceStatus {
        case .accepted: return String(localized: "participant_accepted")
        case .pending: return String(localized: "participant_pending")
        case .removed: return String(localized: "participant_removed")
        default: return String(localized: "participant_unknown")
        }
    }

    // MARK: - Actions

    private func removeParticipant(_ participant: CKShare.Participant) {
        Task { @MainActor in
            do {
                try await sharing.removeParticipant(participant, for: baby)
                HapticManager.success()
            } catch {
                errorMessage = error.localizedDescription
            }
            participantToRemove = nil
        }
    }
}

// MARK: - Row chrome

private struct SharingPersonRow<Trailing: View>: View {
    let badgeName: String
    let badgeColor: Color
    let title: String
    let subtitle: String
    @ViewBuilder let trailing: Trailing

    var body: some View {
        HStack(spacing: 12) {
            PersonBadge(name: badgeName, color: badgeColor, size: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.leona(15, .bold))
                    .foregroundStyle(.tTheirsInk)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.leona(12))
                    .foregroundStyle(.tMuted)
            }
            Spacer(minLength: 8)
            trailing
        }
        .padding(.vertical, 15)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.tTheirs)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

// MARK: - Participant helpers shared by the Profile and Sharing screens

extension SharingView {
    /// Everyone on the active share except the person holding the phone.
    static func others(for baby: Baby, sharing: SharingManager) -> [CKShare.Participant] {
        guard baby.isShared, sharing.activeShareBabyID == baby.id, let share = sharing.activeShare else {
            return []
        }
        let me = share.currentUserParticipant
        let viewerOwns = sharing.isShareOwner(for: baby)
        return share.participants.filter { participant in
            if let me, participant == me { return false }
            if let mine = me?.userIdentity.userRecordID,
               let theirs = participant.userIdentity.userRecordID,
               mine == theirs {
                return false
            }
            if viewerOwns, participant.role == .owner { return false }
            return true
        }
    }

    /// Same resolution order as the previous sharing screen: CloudKit name, e-mail, phone,
    /// then the addresses we invited, then the owner's stored name, then "Partner".
    static func participantName(_ participant: CKShare.Participant, sharing: SharingManager, ownerName: String?) -> String {
        if let name = participant.userIdentity.nameComponents?.formatted(), !name.isEmpty {
            return name
        }
        if let email = participant.userIdentity.lookupInfo?.emailAddress, !email.isEmpty {
            return email
        }
        if let phone = participant.userIdentity.lookupInfo?.phoneNumber, !phone.isEmpty {
            return phone
        }
        if let recordID = participant.userIdentity.userRecordID,
           let email = sharing.invitedEmails[recordID.recordName], !email.isEmpty {
            return email
        }
        if participant.acceptanceStatus == .pending,
           let email = sharing.invitedEmails.values.first(where: { !$0.isEmpty }) {
            return email
        }
        if participant.role == .owner, let ownerName, !ownerName.isEmpty {
            return ownerName
        }
        return String(localized: "partner")
    }
}
