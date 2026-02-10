import SwiftUI
import SwiftData

struct SettingsView: View {
    let baby: Baby
    
    @Environment(AppSettings.self) private var settings
    @Environment(CloudKitManager.self) private var cloudKit
    @Environment(\.modelContext) private var modelContext
    
    @Query private var allActivities: [Activity]
    @Query(sort: \Baby.createdAt) private var babies: [Baby]
    @Query private var growthRecords: [GrowthRecord]
    @Query private var healthRecords: [HealthRecord]
    
    @State private var showExport = false
    @State private var showDeleteAllConfirm = false
    @State private var showBabySelector = false
    @State private var showShareSheet = false
    @State private var shareItems: [Any] = []
    @State private var isGeneratingShare = false
    @State private var shareError: String?
    @State private var showRestartAlert = false
    @State private var pendingCloudValue = false
    
    var body: some View {
        NavigationStack {
            List {
                // Baby profile header
                babyProfileSection
                
                // iCloud & Sharing
                icloudSection
                
                // Appearance
                appearanceSection
                
                // Language
                languageSection
                
                // Feature Toggles
                featureTogglesSection
                
                // Notifications
                notificationSection
                
                // Data Management
                dataSection
                
                // About
                aboutSection
            }
            .navigationTitle(String(localized: "settings"))
            .sheet(isPresented: $showExport) {
                DataExportView(baby: baby)
            }
            .sheet(isPresented: $showBabySelector) {
                BabySelectorView()
            }
            .sheet(isPresented: $showShareSheet) {
                if !shareItems.isEmpty {
                    ShareSheet(items: shareItems)
                }
            }
            .alert(String(localized: "icloud_sync_toggle"), isPresented: $showRestartAlert) {
                Button(String(localized: "ok")) {
                    settings.iCloudSyncEnabled = pendingCloudValue
                }
                Button(String(localized: "cancel"), role: .cancel) { }
            } message: {
                Text(String(localized: "icloud_restart_note"))
            }
        }
    }
    
    // MARK: - Baby Profile Section
    
    private var babyProfileSection: some View {
        Section {
            Button { showBabySelector = true } label: {
                HStack(spacing: 14) {
                    ZStack {
                        if let image = baby.profileImage {
                            image
                                .resizable()
                                .scaledToFill()
                        } else {
                            Image(systemName: "person.crop.circle.fill")
                                .resizable()
                                .foregroundStyle(baby.gender.color.opacity(0.6))
                        }
                    }
                    .frame(width: 56, height: 56)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.leonaPrimary.opacity(0.3), lineWidth: 2))
                    
                    VStack(alignment: .leading, spacing: 3) {
                        Text(baby.displayName)
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Text(baby.ageDescription)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    if babies.count > 1 {
                        Text("\(babies.count)")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(.tertiarySystemFill))
                            .clipShape(Capsule())
                    }
                    
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
                .padding(.vertical, 4)
            }
            .tint(.primary)
        }
    }
    
    // MARK: - iCloud & Sharing
    
    private var icloudSection: some View {
        Section {
            // iCloud toggle
            Toggle(isOn: Binding(
                get: { settings.iCloudSyncEnabled },
                set: { newValue in
                    pendingCloudValue = newValue
                    showRestartAlert = true
                }
            )) {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(String(localized: "icloud_sync_toggle"))
                        Text(settings.iCloudSyncEnabled
                             ? String(localized: "icloud_sync_enabled_desc")
                             : String(localized: "icloud_sync_disabled_desc"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: "icloud.fill")
                        .foregroundStyle(.blue)
                }
            }
            .tint(.blue)
            
            // iCloud account status
            if settings.iCloudSyncEnabled {
                HStack(spacing: 12) {
                    Image(systemName: cloudKit.syncStatus.icon)
                        .foregroundStyle(cloudKit.iCloudAvailable ? .green : .secondary)
                        .symbolEffect(.pulse, isActive: cloudKit.syncStatus == .syncing)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(String(localized: "icloud_account_status"))
                            .font(.subheadline)
                        Text(cloudKit.iCloudAvailable
                             ? String(localized: "icloud_available")
                             : String(localized: "icloud_unavailable"))
                            .font(.caption)
                            .foregroundStyle(cloudKit.iCloudAvailable ? .green : .orange)
                    }
                    
                    Spacer()
                    
                    if let lastSync = cloudKit.lastSyncDate {
                        Text(lastSync.timeAgo())
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                if !cloudKit.iCloudAvailable {
                    Label {
                        Text(String(localized: "icloud_status_desc"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } icon: {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
            }
            
            // Share with partner
            Button {
                shareBabyProfile()
            } label: {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(String(localized: "invite_partner"))
                        Text(String(localized: "invite_partner_desc"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    if isGeneratingShare {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "person.badge.plus")
                            .foregroundStyle(.leonaPrimary)
                    }
                }
            }
            .disabled(isGeneratingShare)
        } header: {
            Text(String(localized: "sync"))
        } footer: {
            if let error = shareError {
                Text(error)
                    .foregroundStyle(.red)
            }
        }
    }
    
    // MARK: - Appearance
    
    private var appearanceSection: some View {
        Section(String(localized: "appearance")) {
            // Theme picker - Apple-standard inline navigation picker
            Picker(String(localized: "theme"), selection: Binding(get: { settings.colorScheme }, set: { settings.colorScheme = $0 })) {
                ForEach(AppColorScheme.allCases) { scheme in
                    Label(scheme.displayName, systemImage: scheme.icon)
                        .tag(scheme)
                }
            }
            
            // Accent color selector
            VStack(alignment: .leading, spacing: 12) {
                Text(String(localized: "accent_color"))
                    .font(.body)
                
                HStack(spacing: 16) {
                    ForEach(AppAccentColor.allCases) { accent in
                        Button {
                            withAnimation(.spring(response: 0.3)) {
                                settings.accentColor = accent
                            }
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(accent.color.gradient)
                                    .frame(width: 36, height: 36)
                                    .shadow(color: accent.color.opacity(0.3), radius: settings.accentColor == accent ? 4 : 0, x: 0, y: 2)
                                
                                if settings.accentColor == accent {
                                    Circle()
                                        .strokeBorder(.white, lineWidth: 2.5)
                                        .frame(width: 36, height: 36)
                                    
                                    Image(systemName: "checkmark")
                                        .font(.caption.bold())
                                        .foregroundStyle(.white)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .scaleEffect(settings.accentColor == accent ? 1.15 : 1.0)
                        .animation(.spring(response: 0.3), value: settings.accentColor)
                    }
                    
                    Spacer()
                }
            }
            .padding(.vertical, 4)
            
            // Units
            Toggle(isOn: Binding(get: { settings.useCelsius }, set: { settings.useCelsius = $0 })) {
                Label(
                    settings.useCelsius ? String(localized: "unit_celsius") : String(localized: "unit_fahrenheit"),
                    systemImage: "thermometer"
                )
            }
            .tint(.leonaPrimary)
            
            Toggle(isOn: Binding(get: { settings.useMetric }, set: { settings.useMetric = $0 })) {
                Label(
                    settings.useMetric ? String(localized: "unit_metric") : String(localized: "unit_imperial"),
                    systemImage: "ruler"
                )
            }
            .tint(.leonaPrimary)
        }
    }
    
    // MARK: - Language
    
    private var languageSection: some View {
        Section(String(localized: "language")) {
            Picker(selection: Binding(get: { settings.language }, set: { settings.language = $0 })) {
                ForEach(AppLanguage.allCases) { lang in
                    Text("\(lang.flag) \(lang.displayName)")
                        .tag(lang)
                }
            } label: {
                Label(String(localized: "app_language"), systemImage: "globe")
            }
        }
    }
    
    // MARK: - Feature Toggles
    
    private var featureTogglesSection: some View {
        Section(String(localized: "tracking_features")) {
            Toggle(isOn: Binding(get: { settings.showSleepTracking }, set: { settings.showSleepTracking = $0 })) {
                Label(String(localized: "toggle_sleep"), systemImage: "moon.fill")
            }
            .tint(.indigo)
            
            Toggle(isOn: Binding(get: { settings.showFeedingTracking }, set: { settings.showFeedingTracking = $0 })) {
                Label(String(localized: "toggle_feeding"), systemImage: "fork.knife")
            }
            .tint(.orange)
            
            Toggle(isOn: Binding(get: { settings.showDiaperTracking }, set: { settings.showDiaperTracking = $0 })) {
                Label(String(localized: "toggle_diaper"), systemImage: "humidity.fill")
            }
            .tint(.cyan)
            
            Toggle(isOn: Binding(get: { settings.showBreastfeeding }, set: { settings.showBreastfeeding = $0 })) {
                Label(String(localized: "toggle_breastfeeding"), systemImage: "heart.fill")
            }
            .tint(.pink)
            
            Toggle(isOn: Binding(get: { settings.showOngoingStatus }, set: { settings.showOngoingStatus = $0 })) {
                Label(String(localized: "toggle_ongoing_status"), systemImage: "bell.badge.fill")
            }
            .tint(.leonaPrimary)
        }
    }
    
    // MARK: - Notifications
    
    private var notificationSection: some View {
        Section(String(localized: "notifications")) {
            Toggle(isOn: Binding(get: { settings.enableFeedingReminders }, set: { settings.enableFeedingReminders = $0 })) {
                Label(String(localized: "feeding_reminders"), systemImage: "bell.fill")
            }
            .tint(.leonaPrimary)
            
            if settings.enableFeedingReminders {
                Picker(String(localized: "reminder_interval"), selection: Binding(get: { settings.feedingReminderInterval }, set: { settings.feedingReminderInterval = $0 })) {
                    Text(String(localized: "interval_2h")).tag(TimeInterval(7200))
                    Text(String(localized: "interval_2_5h")).tag(TimeInterval(9000))
                    Text(String(localized: "interval_3h")).tag(TimeInterval(10800))
                    Text(String(localized: "interval_3_5h")).tag(TimeInterval(12600))
                    Text(String(localized: "interval_4h")).tag(TimeInterval(14400))
                }
            }
            
            Toggle(isOn: Binding(get: { settings.showBreastfeedingNotifications }, set: { settings.showBreastfeedingNotifications = $0 })) {
                Label(String(localized: "bf_notifications"), systemImage: "heart.text.clipboard")
            }
            .tint(.pink)
        }
    }
    
    // MARK: - Data
    
    private var dataSection: some View {
        Section(String(localized: "data")) {
            Button {
                showExport = true
            } label: {
                Label(String(localized: "export_data"), systemImage: "square.and.arrow.up")
            }
            
            Button(role: .destructive) {
                showDeleteAllConfirm = true
            } label: {
                Label(String(localized: "delete_all_data"), systemImage: "trash")
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
    }
    
    // MARK: - About
    
    private var aboutSection: some View {
        Section(String(localized: "about")) {
            HStack {
                Label(String(localized: "version"), systemImage: "info.circle")
                Spacer()
                Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0")
                    .foregroundStyle(.secondary)
            }
            
            HStack {
                Label(String(localized: "app_name"), systemImage: "heart.fill")
                Spacer()
                Text("Leona")
                    .foregroundStyle(.leonaPrimary)
                    .fontWeight(.semibold)
            }
        }
    }
    
    // MARK: - Actions
    
    private func shareBabyProfile() {
        isGeneratingShare = true
        shareError = nil
        
        let shareText = String(localized: "share_invitation_text \(baby.displayName)")
        
        if cloudKit.iCloudAvailable && settings.iCloudSyncEnabled {
            Task {
                do {
                    let share = try await cloudKit.shareBabyProfile(baby: baby)
                    await MainActor.run {
                        if let url = share.url {
                            // Format: invitation text + line break + iCloud share link
                            let fullMessage = shareText + "\n\n" + url.absoluteString
                            shareItems = [fullMessage]
                        } else {
                            shareError = String(localized: "share_url_unavailable")
                            shareItems = [shareText]
                        }
                        isGeneratingShare = false
                        showShareSheet = true
                    }
                } catch {
                    await MainActor.run {
                        shareError = error.localizedDescription
                        // Fall back to basic text sharing
                        shareItems = [shareText + "\n\n" + String(localized: "share_fallback_message")]
                        isGeneratingShare = false
                        showShareSheet = true
                    }
                }
            }
        } else {
            if !settings.iCloudSyncEnabled {
                shareError = String(localized: "share_icloud_disabled")
            } else if !cloudKit.iCloudAvailable {
                shareError = String(localized: "share_icloud_unavailable")
            }
            // Offline sharing - just share the invitation text
            shareItems = [shareText + "\n\n" + String(localized: "share_fallback_message")]
            isGeneratingShare = false
            showShareSheet = true
        }
    }
    
    private func deleteAllData() {
        let babyActivities = allActivities.filter { $0.baby?.id == baby.id }
        for activity in babyActivities {
            modelContext.delete(activity)
        }
        
        let babyGrowth = growthRecords.filter { $0.baby?.id == baby.id }
        for record in babyGrowth {
            modelContext.delete(record)
        }
        
        let babyHealth = healthRecords.filter { $0.baby?.id == baby.id }
        for record in babyHealth {
            modelContext.delete(record)
        }
    }
}

// MARK: - Share Sheet (UIKit wrapper)

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Data Export View

struct DataExportView: View {
    let baby: Baby
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var allActivities: [Activity]
    @Query private var growthRecords: [GrowthRecord]
    @Query private var healthRecords: [HealthRecord]
    
    @State private var exportFormat: ExportFormat = .csv
    @State private var exportContent: String = ""
    @State private var showShareSheet = false
    
    enum ExportFormat: String, CaseIterable, Identifiable {
        case csv, xml, report
        var id: String { rawValue }
        var displayName: String {
            switch self {
            case .csv: return "CSV"
            case .xml: return "XML"
            case .report: return String(localized: "full_report")
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 48))
                    .foregroundStyle(.leonaPrimary)
                    .padding(.top, 32)
                
                Text(String(localized: "export_title"))
                    .font(.title2.bold())
                
                Picker(String(localized: "format"), selection: $exportFormat) {
                    ForEach(ExportFormat.allCases) { format in
                        Text(format.displayName).tag(format)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                
                VStack(alignment: .leading, spacing: 8) {
                    let babyActs = allActivities.filter { $0.baby?.id == baby.id }
                    let babyGrowth = growthRecords.filter { $0.baby?.id == baby.id }
                    
                    Text(String(localized: "export_summary"))
                        .font(.headline)
                    
                    HStack {
                        Text(String(localized: "activities"))
                        Spacer()
                        Text("\(babyActs.count)")
                            .foregroundStyle(.secondary)
                    }
                    
                    HStack {
                        Text(String(localized: "growth_records"))
                        Spacer()
                        Text("\(babyGrowth.count)")
                            .foregroundStyle(.secondary)
                    }
                }
                .padding()
                .leonaCard()
                .padding(.horizontal)
                
                Button {
                    generateExport()
                } label: {
                    Label(String(localized: "generate_export"), systemImage: "doc.badge.arrow.up")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(LeonaButtonStyle(color: .leonaPrimary))
                .padding(.horizontal)
                
                if !exportContent.isEmpty {
                    ScrollView {
                        Text(exportContent)
                            .font(.caption.monospaced())
                            .padding()
                    }
                    .frame(maxHeight: 200)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)
                    
                    Button {
                        UIPasteboard.general.string = exportContent
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                    } label: {
                        Label(String(localized: "copy_to_clipboard"), systemImage: "doc.on.doc")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(LeonaSecondaryButtonStyle(color: .leonaPrimary))
                    .padding(.horizontal)
                }
                
                Spacer()
            }
            .navigationTitle(String(localized: "export_data"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "done")) { dismiss() }
                }
            }
        }
    }
    
    private func generateExport() {
        let babyActs = allActivities.filter { $0.baby?.id == baby.id }
        let babyGrowth = growthRecords.filter { $0.baby?.id == baby.id }
        let babyHealth = healthRecords.filter { $0.baby?.id == baby.id }
        
        switch exportFormat {
        case .csv:
            exportContent = ExportService.exportToCSV(baby: baby, activities: babyActs)
        case .xml:
            exportContent = ExportService.exportToXML(baby: baby, activities: babyActs)
        case .report:
            exportContent = ExportService.generateFullReport(
                baby: baby,
                activities: babyActs,
                growthRecords: babyGrowth,
                healthRecords: babyHealth
            )
        }
    }
}
