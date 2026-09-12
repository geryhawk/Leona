import SwiftUI
import SwiftData

/// The invite block: a share link over any app, a copy button, and the iCloud-email fallback.
struct SharingInviteSection: View {
    let baby: Baby
    let inviteTitle: String
    @Binding var errorMessage: String?

    @Environment(SharingManager.self) private var sharing
    @Environment(ThreadNavigator.self) private var navigator
    @Environment(\.modelContext) private var modelContext

    @State private var partnerEmail = ""
    @State private var isInviting = false
    @State private var inviteSuccess = false
    @State private var isGeneratingLink = false
    @State private var shareURL: URL?
    @State private var linkCopied = false
    @State private var showShareSheet = false

    var body: some View {
        VStack(spacing: 10) {
            LeonaPrimaryButton(title: inviteTitle, enabled: !isGeneratingLink, height: 50, radius: 18, fontSize: 16) {
                generateLink(thenShare: true)
            }
            .padding(.top, 6)

            Button { copyLink() } label: {
                Text(linkCopied ? String(localized: "share_link_copied") : String(localized: "share_copy_link"))
                    .font(.leona(13, .bold))
                    .foregroundStyle(linkCopied ? Color.moss : Color.vermilion)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
            }
            .buttonStyle(.plain)
            .disabled(isGeneratingLink)

            emailCard

            Text(String(localized: "sharing_link_caption"))
                .font(.leona(13))
                .foregroundStyle(.tMuted)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .frame(maxWidth: .infinity)
        }
        .sheet(isPresented: $showShareSheet) {
            if let url = shareURL {
                ShareActivityView(
                    activityItems: [String(localized: "share_link_message \(baby.displayName)"), url]
                ) {
                    showShareSheet = false
                }
            }
        }
        .onChange(of: baby.isShared) { _, shared in
            if !shared { shareURL = nil }
        }
        .onAppear {
            #if DEBUG
            if DemoDataGenerator.isDemoMode,
               DemoDataGenerator.requestedScreen == .sharing,
               partnerEmail.isEmpty {
                partnerEmail = "alex.parent@icloud.com"
            }
            #endif
        }
    }

    private var emailCard: some View {
        LeonaCard(padding: EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 10), radius: 18) {
            HStack(spacing: 10) {
                TextField(String(localized: "share_email_placeholder"), text: $partnerEmail)
                    .font(.leona(15))
                    .foregroundStyle(.tInk)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .submitLabel(.send)
                    .onSubmit { if isValidEmail(partnerEmail) { inviteByEmail() } }
                    .disabled(isInviting)
                if isInviting {
                    ProgressView()
                        .tint(.tMuted)
                        .frame(width: 44)
                } else {
                    LeonaSmallButton(
                        title: inviteSuccess ? String(localized: "sharing_sent") : String(localized: "sharing_send"),
                        tone: inviteSuccess ? .plum : .vermilion,
                        fontSize: 13,
                        vertical: 9,
                        horizontal: 14,
                        radius: 12
                    ) {
                        inviteByEmail()
                    }
                    .disabled(!isValidEmail(partnerEmail))
                    .opacity(isValidEmail(partnerEmail) ? 1 : 0.5)
                }
            }
        }
    }

    // MARK: - Share link

    private func generateLink(thenShare: Bool) {
        isGeneratingLink = true
        errorMessage = nil
        Task { @MainActor in
            do {
                let url = try await sharing.getShareURL(for: baby, in: modelContext)
                shareURL = url
                isGeneratingLink = false
                if thenShare {
                    HapticManager.success()
                    showShareSheet = true
                } else {
                    copyToPasteboard(url)
                }
            } catch {
                isGeneratingLink = false
                errorMessage = error.localizedDescription
                HapticManager.error()
            }
        }
    }

    private func copyLink() {
        if let shareURL {
            copyToPasteboard(shareURL)
        } else {
            generateLink(thenShare: false)
        }
    }

    private func copyToPasteboard(_ url: URL) {
        UIPasteboard.general.url = url
        HapticManager.success()
        withAnimation { linkCopied = true }
        navigator.flash(String(localized: "sharing_link_copied_toast"))
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2))
            withAnimation { linkCopied = false }
        }
    }

    // MARK: - Invite by iCloud e-mail

    private func inviteByEmail() {
        let email = partnerEmail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard isValidEmail(email) else {
            errorMessage = String(localized: "share_error_invalid_email")
            return
        }
        isInviting = true
        errorMessage = nil
        inviteSuccess = false
        Task { @MainActor in
            do {
                try await sharing.addParticipantByEmail(email, for: baby, in: modelContext)
                isInviting = false
                inviteSuccess = true
                HapticManager.success()
                navigator.flash(String(localized: "share_invite_success"))
                try? await Task.sleep(for: .seconds(3))
                inviteSuccess = false
                partnerEmail = ""
            } catch {
                isInviting = false
                errorMessage = error.localizedDescription
                HapticManager.error()
            }
        }
    }

    private func isValidEmail(_ email: String) -> Bool {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        let parts = trimmed.split(separator: "@")
        guard parts.count == 2 else { return false }
        let domain = parts[1]
        return domain.contains(".") && domain.count >= 3
    }
}
