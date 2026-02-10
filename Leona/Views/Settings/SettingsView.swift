import SwiftUI
import SwiftData

struct SettingsView: View {
    let baby: Baby
    
    @Environment(AppSettings.self) private var settings
    @Environment(CloudKitManager.self) private var cloudKit
    @Environment(\.modelContext) private var modelContext
    
    @Query private var allActivities: [Activity]
    @Query private var growthRecords: [GrowthRecord]
    @Query private var healthRecords: [HealthRecord]
    
    @State private var showExport = false
    @State private var showDeleteAllConfirm = false
    @State private var showShareSheet = false
    @State private var exportURL: URL?
    
    var body: some View {
        NavigationStack {
            List {
                // iCloud Status
                icloudSection
                
                // Feature Toggles
                featureTogglesSection
                
                // Appearance
                appearanceSection
                
                // Language
                languageSection
                
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
        }
    }
    
    // MARK: - iCloud
    
    @ViewBuilder
    private var icloudSection: some View {
        Section {
            HStack(spacing: 12) {
                Image(systemName: cloudKit.syncStatus.icon)
                    .foregroundStyle(cloudKit.iCloudAvailable ? .blue : .secondary)
                    .symbolEffect(.pulse, isActive: cloudKit.syncStatus == .syncing)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("iCloud")
                        .font(.subheadline.weight(.medium))
                    Text(cloudKit.syncStatus.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                if cloudKit.iCloudAvailable {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                } else {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.red)
                }
            }
            
            if let lastSync = cloudKit.lastSyncDate {
                HStack {
                    Text(String(localized: "last_sync"))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(lastSync.timeAgo())
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
            }
        } header: {
            Text(String(localized: "sync"))
        }
    }
    
    // MARK: - Feature Toggles
    
    @ViewBuilder
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
            .tint(.leonaPink)
        }
    }
    
    // MARK: - Appearance
    
    @ViewBuilder
    private var appearanceSection: some View {
        Section(String(localized: "appearance")) {
            Picker(String(localized: "theme"), selection: Binding(get: { settings.colorScheme }, set: { settings.colorScheme = $0 })) {
                ForEach(AppColorScheme.allCases) { scheme in
                    Text(scheme.displayName).tag(scheme)
                }
            }
            
            Toggle(isOn: Binding(get: { settings.useCelsius }, set: { settings.useCelsius = $0 })) {
                Label(
                    settings.useCelsius ? String(localized: "unit_celsius") : String(localized: "unit_fahrenheit"),
                    systemImage: "thermometer"
                )
            }
            .tint(.leonaPink)
            
            Toggle(isOn: Binding(get: { settings.useMetric }, set: { settings.useMetric = $0 })) {
                Label(
                    settings.useMetric ? String(localized: "unit_metric") : String(localized: "unit_imperial"),
                    systemImage: "ruler"
                )
            }
            .tint(.leonaPink)
        }
    }
    
    // MARK: - Language
    
    @ViewBuilder
    private var languageSection: some View {
        Section(String(localized: "language")) {
            Picker(String(localized: "app_language"), selection: Binding(get: { settings.language }, set: { settings.language = $0 })) {
                ForEach(AppLanguage.allCases) { lang in
                    HStack {
                        Text(lang.flag)
                        Text(lang.displayName)
                    }
                    .tag(lang)
                }
            }
        }
    }
    
    // MARK: - Notifications
    
    @ViewBuilder
    private var notificationSection: some View {
        Section(String(localized: "notifications")) {
            Toggle(isOn: Binding(get: { settings.enableFeedingReminders }, set: { settings.enableFeedingReminders = $0 })) {
                Label(String(localized: "feeding_reminders"), systemImage: "bell.fill")
            }
            .tint(.leonaPink)
            
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
    
    @ViewBuilder
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
                Text(String(localized: "version"))
                Spacer()
                Text("1.0.0")
                    .foregroundStyle(.secondary)
            }
            
            HStack {
                Text(String(localized: "app_name"))
                Spacer()
                Text("Leona")
                    .foregroundStyle(.leonaPink)
                    .fontWeight(.semibold)
            }
            
            Link(destination: URL(string: "https://github.com/leona-app")!) {
                HStack {
                    Text(String(localized: "source_code"))
                    Spacer()
                    Image(systemName: "arrow.up.right.square")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
    
    // MARK: - Data Management
    
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
                    .foregroundStyle(.leonaPink)
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
                .buttonStyle(LeonaButtonStyle(color: .leonaPink))
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
                    .buttonStyle(LeonaSecondaryButtonStyle(color: .leonaPink))
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
