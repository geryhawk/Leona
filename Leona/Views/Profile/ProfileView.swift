import SwiftUI
import SwiftData
import CloudKit
import PhotosUI

/// The baby's page: identity, who is in the thread, preferences and the record.
struct ProfileView: View {
    let baby: Baby

    @Environment(AppSettings.self) private var settings
    @Environment(CloudKitManager.self) private var cloudKit
    @Environment(SharingManager.self) private var sharing
    @Environment(ThreadNavigator.self) private var navigator
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme

    @Query(sort: \Baby.createdAt) private var babies: [Baby]
    @Query private var allActivities: [Activity]
    @Query private var growthRecords: [GrowthRecord]
    @Query private var healthRecords: [HealthRecord]

    @State private var showEdit = false
    @State private var photoItem: PhotosPickerItem?

    init(baby: Baby) {
        self.baby = baby
    }

    var body: some View {
        VStack(spacing: 0) {
            SubScreenHeader(title: baby.displayName) { navigator.backToThread() }
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    headerCard
                    inThreadCard
                    if !otherBabies.isEmpty {
                        LeonaSectionLabel(String(localized: "profile_threads"))
                        threadsGroup
                    }
                    LeonaSectionLabel(String(localized: "profile_preferences"))
                    preferencesGroup
                    LeonaSectionLabel(String(localized: "profile_reminders"))
                    remindersGroup
                    LeonaSectionLabel(String(localized: "profile_tracks"))
                    tracksGroup
                    ProfileCloudSection()
                    ProfileRecordSection(baby: baby)
                    ProfileAboutSection()
                }
                .padding(.horizontal, 18)
                .padding(.top, 14)
                .padding(.bottom, 20)
            }
        }
        .leonaScreen()
        .sheet(isPresented: $showEdit) {
            BabyEditView(baby: baby)
        }
        .onChange(of: photoItem) { _, item in
            loadPhoto(item)
        }
        .task {
            if baby.isShared { await sharing.fetchShareInfo(for: baby) }
        }
    }

    // MARK: - Header

    private var headerCard: some View {
        PlumCard(padding: 17) {
            HStack(spacing: 14) {
                PhotosPicker(selection: $photoItem, matching: .images) {
                    BabyAvatar(
                        baby: baby,
                        size: 58,
                        radius: 18,
                        background: Color.white.opacity(0.14),
                        silhouette: Color.white.opacity(0.55)
                    )
                }
                .buttonStyle(.plain)

                Button {
                    HapticManager.impact(.light)
                    showEdit = true
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(baby.displayName)
                            .font(.leona(23, .bold))
                            .leonaTracking(-0.03, size: 23)
                            .foregroundStyle(.white)
                        Text(bornLine)
                            .font(.leona(13))
                            .foregroundStyle(Color.white.opacity(0.72))
                        Text(ageLine)
                            .font(.leona(12, .bold))
                            .foregroundStyle(.highlight)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var bornLine: String {
        let date = baby.dateOfBirth.formatted(.dateTime.day().month(.abbreviated).year())
        var parts = [String(localized: "profile_born \(date)")]
        if baby.gender != .unspecified {
            parts.append(baby.gender.displayName.lowercased())
        }
        let blood = baby.bloodType.trimmingCharacters(in: .whitespaces)
        if !blood.isEmpty { parts.append(blood) }
        return parts.joined(separator: " · ")
    }

    private var ageLine: String {
        let count = babyActivities.count
            + growthRecords.filter { $0.baby?.id == baby.id }.count
            + healthRecords.filter { $0.baby?.id == baby.id }.count
        return "\(baby.ageDescription) · \(String(localized: "profile_entries_kept \(count)"))"
    }

    private var babyActivities: [Activity] {
        allActivities.filter { $0.baby?.id == baby.id }
    }

    // MARK: - In this thread

    private var myName: String {
        let name = settings.userDisplayName.trimmingCharacters(in: .whitespaces)
        return name.isEmpty ? String(localized: "profile_you") : name
    }

    private var acceptedParticipants: [CKShare.Participant] {
        SharingView.others(for: baby, sharing: sharing).filter { $0.acceptanceStatus == .accepted }
    }

    private var namesLine: String {
        let names = [myName] + acceptedParticipants.map {
            SharingView.participantName($0, sharing: sharing, ownerName: baby.ownerName)
        }
        guard names.count > 1, let last = names.last else { return names.first ?? "" }
        let head = names.dropLast().joined(separator: ", ")
        return String(localized: "profile_names_and \(head) \(last)")
    }

    private var inThreadCard: some View {
        Button {
            navigator.go(.sharing)
        } label: {
            LeonaCard(padding: EdgeInsets(top: 16, leading: 18, bottom: 16, trailing: 18)) {
                VStack(alignment: .leading, spacing: 11) {
                    HStack {
                        LeonaSectionLabel(String(localized: "profile_in_this_thread"), size: 11, tracking: 0.12)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .heavy))
                            .foregroundStyle(.tMuted)
                    }
                    HStack(spacing: 10) {
                        PersonBadge(name: myName, color: .tMine)
                        ForEach(Array(acceptedParticipants.enumerated()), id: \.offset) { _, participant in
                            PersonBadge(
                                name: SharingView.participantName(participant, sharing: sharing, ownerName: baby.ownerName),
                                color: .vermilion
                            )
                        }
                        Text(namesLine)
                            .font(.leona(15, .bold))
                            .foregroundStyle(.tInk)
                            .lineLimit(1)
                        Spacer(minLength: 0)
                        if baby.isShared, let sync = cloudKit.lastSyncDate {
                            Text(String(localized: "profile_synced \(ThreadFormat.clock(sync))"))
                                .font(.leona(12, .semibold))
                                .foregroundStyle(.tMuted)
                        }
                    }
                }
            }
        }
        .buttonStyle(.leonaPress)
    }

    // MARK: - Other threads

    private var otherBabies: [Baby] {
        babies.filter { $0.id != baby.id }
    }

    private var threadsGroup: some View {
        LeonaGroup {
            ForEach(otherBabies) { other in
                Button {
                    HapticManager.impact(.medium)
                    settings.activeBabyID = other.id.uuidString
                    navigator.flash(String(localized: "profile_switch_toast \(other.displayName)"))
                } label: {
                    HStack(spacing: 12) {
                        BabyAvatar(baby: other, size: 31, radius: 10)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(other.displayName)
                                .font(.leona(15, .bold))
                                .foregroundStyle(.tInk)
                            Text(other.ageDescription)
                                .font(.leona(12))
                                .foregroundStyle(.tMuted)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .heavy))
                            .foregroundStyle(.tMuted)
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 17)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Preferences

    private func setting(_ keyPath: ReferenceWritableKeyPath<AppSettings, Bool>) -> Binding<Bool> {
        Binding(
            get: { settings[keyPath: keyPath] },
            set: { settings[keyPath: keyPath] = $0 }
        )
    }

    /// Reads the appearance actually on screen (system, auto-dusk or manual). Turning it off
    /// returns to "follow iOS", or forces light when iOS itself is dark so the switch has an effect.
    private var nightTheme: Binding<Bool> {
        Binding(
            get: { colorScheme == .dark },
            set: { on in
                settings.autoNightTheme = false
                settings.colorScheme = on ? .dark : (AppSettings.systemPrefersDark ? .light : .system)
            }
        )
    }

    private var metricUnits: Binding<Bool> {
        Binding(
            get: { settings.useMetric },
            set: { on in
                settings.useMetric = on
                settings.useCelsius = on
            }
        )
    }

    private var preferencesGroup: some View {
        LeonaGroup {
            LeonaToggleRow(
                title: String(localized: "profile_night_theme"),
                subtitle: colorScheme == .dark
                    ? String(localized: "profile_night_on")
                    : String(localized: "profile_night_off"),
                isOn: nightTheme
            )
            LeonaToggleRow(
                title: String(localized: "profile_auto_dusk"),
                subtitle: String(localized: "profile_auto_dusk_sub"),
                isOn: setting(\.autoNightTheme)
            )
            LeonaToggleRow(
                title: String(localized: "profile_leona_speak"),
                subtitle: String(localized: "profile_leona_speak_sub"),
                isOn: setting(\.leonaSuggestions)
            )
            LeonaToggleRow(
                title: String(localized: "profile_metric"),
                subtitle: settings.useMetric
                    ? String(localized: "profile_metric_on")
                    : String(localized: "profile_metric_off"),
                isOn: metricUnits
            )
        }
    }

    // MARK: - Reminders

    private var remindersGroup: some View {
        LeonaGroup {
            LeonaToggleRow(
                title: String(localized: "feeding_reminders"),
                isOn: setting(\.enableFeedingReminders)
            )
            if settings.enableFeedingReminders {
                intervalRow
            }
            LeonaToggleRow(
                title: String(localized: "bf_notifications"),
                isOn: setting(\.showBreastfeedingNotifications)
            )
        }
    }

    private static let intervals: [TimeInterval] = [7200, 9000, 10800, 12600, 14400]

    private func intervalTitle(_ seconds: TimeInterval) -> String {
        switch seconds {
        case 7200: return String(localized: "interval_2h")
        case 9000: return String(localized: "interval_2_5h")
        case 10800: return String(localized: "interval_3h")
        case 12600: return String(localized: "interval_3_5h")
        default: return String(localized: "interval_4h")
        }
    }

    private var intervalRow: some View {
        HStack(spacing: 12) {
            Text(String(localized: "reminder_interval"))
                .font(.leona(15, .bold))
                .foregroundStyle(.tInk)
            Spacer(minLength: 0)
            Menu {
                ForEach(Self.intervals, id: \.self) { seconds in
                    Button {
                        settings.feedingReminderInterval = seconds
                        HapticManager.selection()
                    } label: {
                        if settings.feedingReminderInterval == seconds {
                            Label(intervalTitle(seconds), systemImage: "checkmark")
                        } else {
                            Text(intervalTitle(seconds))
                        }
                    }
                }
            } label: {
                HStack(spacing: 5) {
                    Text(intervalTitle(settings.feedingReminderInterval))
                        .font(.leona(15, .bold))
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 11, weight: .bold))
                }
                .foregroundStyle(.vermilion)
            }
        }
        .padding(.vertical, 15)
        .padding(.horizontal, 17)
    }

    // MARK: - What Leona tracks

    private var tracksGroup: some View {
        LeonaGroup {
            LeonaToggleRow(title: String(localized: "profile_track_sleep"), isOn: setting(\.showSleepTracking))
            LeonaToggleRow(title: String(localized: "profile_track_breastfeeding"), isOn: setting(\.showBreastfeeding))
            LeonaToggleRow(title: String(localized: "profile_track_diapers"), isOn: setting(\.showDiaperTracking))
            LeonaToggleRow(title: String(localized: "profile_track_bottles"), isOn: setting(\.showFeedingTracking))
        }
    }

    // MARK: - Photo

    private func loadPhoto(_ item: PhotosPickerItem?) {
        guard let item else { return }
        Task {
            guard let data = try? await item.loadTransferable(type: Data.self) else { return }
            baby.profileImageData = data
            baby.updatedAt = Date()
            ActivityLogger.save(modelContext)
            HapticManager.success()
            navigator.flash(String(localized: "profile_photo_updated"))
            photoItem = nil
        }
    }
}
