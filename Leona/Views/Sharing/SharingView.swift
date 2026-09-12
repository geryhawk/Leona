import SwiftUI
import SwiftData
import CloudKit

/// Who is in the thread, how to invite someone, and who has been carrying the day.
struct SharingView: View {
    let baby: Baby

    @Environment(AppSettings.self) private var settings
    @Environment(CloudKitManager.self) private var cloudKit
    @Environment(SharingManager.self) private var sharing
    @Environment(ThreadNavigator.self) private var navigator
    @Environment(\.modelContext) private var modelContext

    @Query private var allActivities: [Activity]

    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showStopConfirm = false
    @State private var showConsentAlert = false
    @State private var showRestartAlert = false

    init(baby: Baby) {
        self.baby = baby
    }

    // MARK: - Derived data

    /// Finished entries for this baby, newest first.
    private var entries: [Activity] {
        allActivities
            .filter { $0.baby?.id == baby.id && !$0.isOngoing }
            .sorted { $0.sortTime > $1.sortTime }
    }

    private var todayEntries: [Activity] { entries.filter { $0.sortTime.isToday } }
    private var myTodayCount: Int { todayEntries.filter(\.isMine).count }
    private var othersTodayCount: Int { todayEntries.count - myTodayCount }

    private var isOwner: Bool { sharing.isShareOwner(for: baby) }
    private var canInvite: Bool { !baby.isShared || isOwner }
    private var cloudReady: Bool { settings.iCloudSyncEnabled && cloudKit.iCloudAvailable }

    private var myName: String {
        let name = settings.userDisplayName.trimmingCharacters(in: .whitespaces)
        return name.isEmpty ? String(localized: "profile_you") : name
    }

    private var others: [CKShare.Participant] {
        SharingView.others(for: baby, sharing: sharing)
    }

    /// The other side of the thread: the one partner's name when there is exactly one, otherwise a neutral label.
    private var othersLabel: String {
        let accepted = others.filter { $0.acceptanceStatus == .accepted }
        if accepted.count == 1 {
            return SharingView.participantName(accepted[0], sharing: sharing, ownerName: baby.ownerName)
        }
        if accepted.isEmpty, let theirs = entries.first(where: { !$0.isMine }) {
            return theirs.authorDisplayName
        }
        return String(localized: "sharing_everyone_else")
    }

    private var inviteTitle: String {
        others.isEmpty
            ? String(localized: "sharing_invite_partner")
            : String(localized: "sharing_invite_someone_else")
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            SubScreenHeader(title: String(localized: "sharing_title")) { navigator.backToThread() }
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if cloudReady {
                        sharingContent
                    } else {
                        cloudGate
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 14)
                .padding(.bottom, 20)
            }
            .refreshable { await refreshShareState() }
        }
        .leonaScreen()
        .alert(String(localized: "stop_sharing_title"), isPresented: $showStopConfirm) {
            Button(String(localized: "stop_sharing"), role: .destructive) { stopSharing() }
            Button(String(localized: "cancel"), role: .cancel) {}
        } message: {
            Text(String(localized: "stop_sharing_message"))
        }
        .alert(String(localized: "icloud_consent_title"), isPresented: $showConsentAlert) {
            Button(String(localized: "icloud_consent_accept")) {
                settings.iCloudSyncEnabled = true
                showRestartAlert = true
            }
            Button(String(localized: "cancel"), role: .cancel) {}
        } message: {
            Text(String(localized: "icloud_consent_message"))
        }
        .alert(String(localized: "icloud_sync_toggle"), isPresented: $showRestartAlert) {
            Button(String(localized: "ok")) {}
        } message: {
            Text(String(localized: "icloud_restart_note"))
        }
        .task { await initialLoad() }
    }

    @ViewBuilder
    private var sharingContent: some View {
        leonaBubble

        LeonaSectionLabel(String(localized: "sharing_people"))
            .padding(.top, 4)
        if isLoading {
            HStack {
                Spacer()
                ProgressView().tint(.tMuted)
                Spacer()
            }
            .padding(.vertical, 6)
        }
        SharingPeopleSection(baby: baby, errorMessage: $errorMessage)

        if canInvite {
            SharingInviteSection(baby: baby, inviteTitle: inviteTitle, errorMessage: $errorMessage)
        }

        if let errorMessage {
            Text(errorMessage)
                .font(.leona(13, .semibold))
                .foregroundStyle(.vermilion)
                .frame(maxWidth: .infinity, alignment: .leading)
        }

        if baby.isShared {
            LeonaSectionLabel(String(localized: "sharing_who_logged_today"))
                .padding(.top, 8)
            HStack(spacing: 10) {
                SharingCountCard(label: myName, count: myTodayCount)
                SharingCountCard(label: othersLabel, count: othersTodayCount)
            }
            balanceCard
            if isOwner {
                LeonaGroup {
                    LeonaRow(title: String(localized: "stop_sharing"), destructive: true) {
                        showStopConfirm = true
                    }
                }
                .padding(.top, 4)
            }
        }
    }

    // MARK: - iCloud gate

    @ViewBuilder
    private var cloudGate: some View {
        LeonaTintCard(padding: EdgeInsets(top: 15, leading: 17, bottom: 15, trailing: 17), asBubble: true) {
            VStack(alignment: .leading, spacing: 7) {
                LeonaCardHeader(name: baby.displayName)
                Text(String(localized: "sharing_needs_icloud \(baby.displayName)"))
                    .font(.leona(16, .semibold))
                    .foregroundStyle(.tInk)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.trailing, 28)

        if !settings.iCloudSyncEnabled {
            LeonaPrimaryButton(title: String(localized: "sharing_turn_on_icloud"), height: 50, radius: 18, fontSize: 16) {
                showConsentAlert = true
            }
            .padding(.top, 6)
        } else {
            Text(String(localized: "icloud_status_desc"))
                .font(.leona(13))
                .foregroundStyle(.tMuted)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.top, 6)
        }
    }

    // MARK: - Leona's line

    private var leonaBubble: some View {
        LeonaTintCard(padding: EdgeInsets(top: 15, leading: 17, bottom: 15, trailing: 17), asBubble: true) {
            VStack(alignment: .leading, spacing: 7) {
                LeonaCardHeader(name: baby.displayName)
                Text(handoffLine)
                    .font(.leona(16, .semibold))
                    .foregroundStyle(.tInk)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.trailing, 28)
    }

    private var handoffLine: String {
        guard baby.isShared else {
            return String(localized: "sharing_invite_line \(baby.displayName)")
        }
        var streak: [Activity] = []
        for entry in entries {
            if entry.isMine { break }
            streak.append(entry)
        }
        guard let latest = streak.first, latest.sortTime.isToday, let oldest = streak.last else {
            return String(localized: "sharing_quiet_line \(baby.displayName)")
        }
        let partner = latest.authorDisplayName
        let since = entries.first(where: \.isMine)?.sortTime ?? oldest.sortTime
        let sinceText = since.isToday
            ? ThreadFormat.clock(since)
            : since.formatted(date: .abbreviated, time: .shortened)
        if streak.count == 1 {
            return String(localized: "sharing_handoff_one \(partner) \(sinceText)")
        }
        return String(localized: "sharing_handoff \(partner) \(streak.count) \(sinceText)")
    }

    // MARK: - Balance

    private var balanceWindow: [Activity] { Array(entries.prefix(20)) }
    private var theirsInWindow: Int { balanceWindow.filter { !$0.isMine }.count }

    private var myShare: Double {
        guard !balanceWindow.isEmpty else { return 1 }
        return Double(balanceWindow.count - theirsInWindow) / Double(balanceWindow.count)
    }

    private var balanceLine: String {
        guard !balanceWindow.isEmpty else { return String(localized: "sharing_balance_empty") }
        return String(localized: "sharing_balance \(othersLabel) \(theirsInWindow) \(balanceWindow.count)")
    }

    private var balanceCard: some View {
        LeonaCard(padding: EdgeInsets(top: 15, leading: 17, bottom: 15, trailing: 17), radius: 18) {
            VStack(alignment: .leading, spacing: 0) {
                LeonaSectionLabel(String(localized: "sharing_off_duty_balance"), size: 11, tracking: 0.1)
                GeometryReader { geo in
                    HStack(spacing: 0) {
                        Rectangle()
                            .fill(Color.tMine)
                            .frame(width: geo.size.width * myShare)
                        Rectangle()
                            .fill(Color.vermilion)
                    }
                }
                .frame(height: 10)
                .clipShape(Capsule())
                .padding(.top, 10)
                Text(balanceLine)
                    .font(.leona(13))
                    .foregroundStyle(.tMuted)
                    .lineSpacing(3)
                    .padding(.top, 9)
            }
        }
    }

    // MARK: - Loading

    private func initialLoad() async {
        #if DEBUG
        if DemoDataGenerator.isDemoMode { return }
        #endif
        guard baby.isShared else { return }
        isLoading = true
        await sharing.fetchShareInfo(for: baby)
        isLoading = false
    }

    private func refreshShareState() async {
        guard baby.isShared else { return }
        await SyncEngine.shared.forcePullSharedBabies(context: modelContext)
        await sharing.fetchShareInfo(for: baby)
    }

    // MARK: - Stop sharing

    private func stopSharing() {
        Task { @MainActor in
            do {
                try await sharing.stopSharing(for: baby, in: modelContext)
                HapticManager.success()
                navigator.flash(String(localized: "sharing_stopped_toast"))
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

// MARK: - Count card

private struct SharingCountCard: View {
    let label: String
    let count: Int

    var body: some View {
        LeonaCard(padding: EdgeInsets(top: 15, leading: 17, bottom: 15, trailing: 17), radius: 18) {
            VStack(alignment: .leading, spacing: 2) {
                LeonaSectionLabel(label, size: 11, tracking: 0.1)
                    .lineLimit(1)
                Text("\(count)")
                    .font(.leona(28, .bold))
                    .leonaTracking(-0.035, size: 28)
                    .foregroundStyle(.tInk)
            }
        }
    }
}
