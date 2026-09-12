import SwiftUI
import SwiftData

// MARK: - iCloud

/// "ICLOUD" group: the sync toggle with the consent and restart alerts.
struct ProfileCloudSection: View {
    @Environment(AppSettings.self) private var settings
    @Environment(CloudKitManager.self) private var cloudKit

    @State private var showConsentAlert = false
    @State private var showRestartAlert = false
    @State private var pendingCloudValue = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            LeonaSectionLabel(String(localized: "profile_icloud"))
            LeonaGroup {
                LeonaToggleRow(
                    title: String(localized: "icloud_sync_toggle"),
                    subtitle: subtitle,
                    isOn: cloudBinding
                )
            }
        }
        .alert(String(localized: "icloud_sync_toggle"), isPresented: $showRestartAlert) {
            Button(String(localized: "ok")) {
                settings.iCloudSyncEnabled = pendingCloudValue
            }
            Button(String(localized: "cancel"), role: .cancel) {}
        } message: {
            Text(String(localized: "icloud_restart_note"))
        }
        .alert(String(localized: "icloud_consent_title"), isPresented: $showConsentAlert) {
            Button(String(localized: "icloud_consent_accept")) {
                settings.iCloudSyncEnabled = true
            }
            Button(String(localized: "cancel"), role: .cancel) {}
        } message: {
            Text(String(localized: "icloud_consent_message"))
        }
    }

    private var cloudBinding: Binding<Bool> {
        Binding(
            get: { settings.iCloudSyncEnabled },
            set: { newValue in
                pendingCloudValue = newValue
                if newValue {
                    showConsentAlert = true
                } else {
                    showRestartAlert = true
                }
            }
        )
    }

    private var subtitle: String {
        guard settings.iCloudSyncEnabled else {
            return String(localized: "icloud_sync_disabled_desc")
        }
        guard cloudKit.iCloudAvailable else {
            return String(localized: "icloud_status_desc")
        }
        if let sync = cloudKit.lastSyncDate {
            return "\(String(localized: "icloud_available")) · \(String(localized: "profile_icloud_last_sync \(sync.timeAgo())"))"
        }
        return String(localized: "icloud_sync_enabled_desc")
    }
}

// MARK: - The record

private struct ProfileShareFile: Identifiable {
    let url: URL
    var id: String { url.absoluteString }
}

/// "THE RECORD" group: keepsake PDF, CSV, a new thread, and wiping this one.
struct ProfileRecordSection: View {
    let baby: Baby

    @Environment(SharingManager.self) private var sharing
    @Environment(ThreadNavigator.self) private var navigator
    @Environment(\.modelContext) private var modelContext

    @Query private var allActivities: [Activity]
    @Query private var growthRecords: [GrowthRecord]
    @Query private var healthRecords: [HealthRecord]

    @State private var showDeleteAllConfirm = false
    @State private var shareFile: ProfileShareFile?

    private var babyActivities: [Activity] {
        allActivities
            .filter { $0.baby?.id == baby.id }
            .sorted { $0.startTime < $1.startTime }
    }

    private var babyGrowth: [GrowthRecord] {
        growthRecords.filter { $0.baby?.id == baby.id }.sorted { $0.date < $1.date }
    }

    private var babyHealth: [HealthRecord] {
        healthRecords.filter { $0.baby?.id == baby.id }.sorted { $0.startDate < $1.startDate }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            LeonaSectionLabel(String(localized: "profile_record"))
            LeonaGroup {
                LeonaRow(title: String(localized: "profile_print_book")) { exportPDF() }
                LeonaRow(title: String(localized: "profile_export_csv")) { exportCSV() }
                LeonaRow(title: String(localized: "profile_new_thread")) {
                    navigator.showWelcomeForNewBaby = true
                }
                LeonaRow(title: String(localized: "profile_delete_everything \(baby.displayName)"), destructive: true) {
                    showDeleteAllConfirm = true
                }
            }
        }
        .confirmationDialog(
            String(localized: "delete_all_confirm"),
            isPresented: $showDeleteAllConfirm,
            titleVisibility: .visible
        ) {
            Button(String(localized: "delete_everything"), role: .destructive) {
                deleteAllData()
            }
        } message: {
            Text(String(localized: "delete_all_warning"))
        }
        .sheet(item: $shareFile) { file in
            ShareActivityView(activityItems: [file.url]) {
                shareFile = nil
            }
        }
    }

    // MARK: - Exports

    private func exportPDF() {
        guard let url = ReportExporter.makeReportPDF(
            baby: baby,
            activities: babyActivities,
            growthRecords: babyGrowth,
            healthRecords: babyHealth
        ) else {
            navigator.flash(String(localized: "profile_export_failed"))
            return
        }
        shareFile = ProfileShareFile(url: url)
    }

    private func exportCSV() {
        guard let url = ReportExporter.makeCSV(baby: baby, activities: babyActivities) else {
            navigator.flash(String(localized: "profile_export_failed"))
            return
        }
        shareFile = ProfileShareFile(url: url)
    }

    // MARK: - Delete everything

    private func deleteAllData() {
        let activities = babyActivities
        let activityIDs = activities.map(\.id)
        for activity in activities {
            modelContext.delete(activity)
        }

        let growth = babyGrowth
        let growthIDs = growth.map(\.id)
        for record in growth {
            modelContext.delete(record)
        }

        let health = babyHealth
        let healthIDs = health.map(\.id)
        for record in health {
            modelContext.delete(record)
        }

        try? modelContext.save()
        HapticManager.success()
        navigator.flash(String(localized: "profile_thread_cleared"))

        guard baby.isShared else { return }
        let baby = baby
        let sharing = sharing
        Task {
            for recordID in activityIDs {
                try? await sharing.deleteRecord(recordID: recordID, recordType: Activity.ckRecordType, for: baby)
            }
            for recordID in growthIDs {
                try? await sharing.deleteRecord(recordID: recordID, recordType: GrowthRecord.ckRecordType, for: baby)
            }
            for recordID in healthIDs {
                try? await sharing.deleteRecord(recordID: recordID, recordType: HealthRecord.ckRecordType, for: baby)
            }
        }
    }
}

// MARK: - About

struct ProfileAboutSection: View {
    @Environment(\.openURL) private var openURL

    private static let privacyURL = URL(string: "https://geryhawk.github.io/Leona/privacy.html")!

    private var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            LeonaSectionLabel(String(localized: "profile_about"))
            LeonaGroup {
                HStack(spacing: 12) {
                    Text(String(localized: "version"))
                        .font(.leona(15, .bold))
                        .foregroundStyle(.tInk)
                    Spacer(minLength: 0)
                    Text(version)
                        .font(.leona(15))
                        .foregroundStyle(.tMuted)
                }
                .padding(.vertical, 15)
                .padding(.horizontal, 17)

                LeonaRow(title: String(localized: "privacy_policy"), showsChevron: true) {
                    openURL(Self.privacyURL)
                }
            }
        }
    }
}
