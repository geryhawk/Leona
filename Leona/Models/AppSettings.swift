import Foundation
import SwiftUI

// MARK: - App Settings (UserDefaults backed, properly observable)
//
// CRITICAL: Properties are STORED (not computed) so that @Observable
// properly tracks mutations and triggers SwiftUI view updates.
// Each property syncs to UserDefaults via didSet.
// didSet is NOT called during init, so we manually read from UserDefaults there.

@Observable
final class AppSettings {
    static let shared = AppSettings()
    
    @ObservationIgnored private let defaults = UserDefaults.standard
    
    // MARK: - Feature Toggles
    
    var showSleepTracking: Bool {
        didSet { defaults.set(showSleepTracking, forKey: "showSleepTracking") }
    }
    
    var showFeedingTracking: Bool {
        didSet { defaults.set(showFeedingTracking, forKey: "showFeedingTracking") }
    }
    
    var showDiaperTracking: Bool {
        didSet { defaults.set(showDiaperTracking, forKey: "showDiaperTracking") }
    }
    
    var showBreastfeeding: Bool {
        didSet { defaults.set(showBreastfeeding, forKey: "showBreastfeeding") }
    }
    
    var showBreastfeedingNotifications: Bool {
        didSet { defaults.set(showBreastfeedingNotifications, forKey: "showBreastfeedingNotifications") }
    }
    
    var showOngoingStatus: Bool {
        didSet { defaults.set(showOngoingStatus, forKey: "showOngoingStatus") }
    }
    
    // MARK: - Menu Visibility (kept for existing installs; the thread shows everything)
    
    var showProfile: Bool {
        didSet { defaults.set(showProfile, forKey: "showProfile") }
    }
    
    var showGrowth: Bool {
        didSet { defaults.set(showGrowth, forKey: "showGrowth") }
    }
    
    var showHealth: Bool {
        didSet { defaults.set(showHealth, forKey: "showHealth") }
    }
    
    var showStats: Bool {
        didSet { defaults.set(showStats, forKey: "showStats") }
    }
    
    var showDataExport: Bool {
        didSet { defaults.set(showDataExport, forKey: "showDataExport") }
    }
    
    // MARK: - Active Baby
    
    var activeBabyID: String? {
        didSet { defaults.set(activeBabyID, forKey: "activeBabyID") }
    }
    
    // MARK: - Appearance
    
    var colorScheme: AppColorScheme {
        didSet { defaults.set(colorScheme.rawValue, forKey: "colorScheme") }
    }

    /// Night theme switches on by itself between 20:00 and 07:00.
    var autoNightTheme: Bool {
        didSet { defaults.set(autoNightTheme, forKey: "autoNightTheme") }
    }
    
    var accentColor: AppAccentColor {
        didSet { defaults.set(accentColor.rawValue, forKey: "accentColor") }
    }

    var customAccentColor: Color {
        get {
            let r = defaults.double(forKey: "customAccentR")
            let g = defaults.double(forKey: "customAccentG")
            let b = defaults.double(forKey: "customAccentB")
            if r == 0 && g == 0 && b == 0 { return Color(red: 0.863, green: 0.518, blue: 0.639) }
            return Color(red: r, green: g, blue: b)
        }
        set {
            let uiColor = UIColor(newValue)
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0
            uiColor.getRed(&r, green: &g, blue: &b, alpha: nil)
            defaults.set(Double(r), forKey: "customAccentR")
            defaults.set(Double(g), forKey: "customAccentG")
            defaults.set(Double(b), forKey: "customAccentB")
        }
    }
    
    var useCelsius: Bool {
        didSet { defaults.set(useCelsius, forKey: "useCelsius") }
    }
    
    var useMetric: Bool {
        didSet { defaults.set(useMetric, forKey: "useMetric") }
    }

    // MARK: - Leona (suggestions in the thread)

    var leonaSuggestions: Bool {
        didSet { defaults.set(leonaSuggestions, forKey: "leonaSuggestions") }
    }

    // MARK: - Who is logging on this device

    /// Stable per-install identity, used before the iCloud identity is known and as a fallback without iCloud.
    let authorID: String

    /// The iCloud user record name, identical on every device signed into the same account.
    var cloudUserID: String? {
        didSet { defaults.set(cloudUserID, forKey: "cloudUserID") }
    }

    /// The iCloud identity whose entries have already been re-stamped from the install id.
    var adoptedCloudUserID: String? {
        didSet { defaults.set(adoptedCloudUserID, forKey: "adoptedCloudUserID") }
    }

    /// What new entries are stamped with: the person when known, else this install.
    var effectiveAuthorID: String { cloudUserID ?? authorID }

    var userDisplayName: String {
        didSet { defaults.set(userDisplayName, forKey: "userDisplayName") }
    }
    
    // MARK: - Notification Preferences
    
    var feedingReminderInterval: TimeInterval {
        didSet { defaults.set(feedingReminderInterval, forKey: "feedingReminderInterval") }
    }
    
    var enableFeedingReminders: Bool {
        didSet { defaults.set(enableFeedingReminders, forKey: "enableFeedingReminders") }
    }
    
    // MARK: - iCloud
    
    var iCloudSyncEnabled: Bool {
        didSet { defaults.set(iCloudSyncEnabled, forKey: "iCloudSyncEnabled") }
    }
    
    // MARK: - Onboarding
    
    var hasCompletedOnboarding: Bool {
        didSet { defaults.set(hasCompletedOnboarding, forKey: "hasCompletedOnboarding") }
    }

    // MARK: - Per-baby device-local state

    func threadLastSeen(for babyID: UUID) -> Date? {
        defaults.object(forKey: "threadSeen-\(babyID.uuidString)") as? Date
    }

    func markThreadSeen(for babyID: UUID, at date: Date = Date()) {
        defaults.set(date, forKey: "threadSeen-\(babyID.uuidString)")
    }

    func nextVaccinationDate(for babyID: UUID) -> Date? {
        defaults.object(forKey: "nextVaccination-\(babyID.uuidString)") as? Date
    }

    func setNextVaccinationDate(_ date: Date?, for babyID: UUID) {
        defaults.set(date, forKey: "nextVaccination-\(babyID.uuidString)")
        vaccinationVersion += 1
    }

    /// Bumped whenever a per-baby stored value changes so views re-read it.
    var vaccinationVersion = 0

    // MARK: - Resolved appearance

    var resolvedColorScheme: ColorScheme? {
        if autoNightTheme {
            let hour = Calendar.current.component(.hour, from: Date())
            return (hour >= 20 || hour < 7) ? .dark : .light
        }
        return colorScheme.colorScheme
    }

    /// iOS's own appearance, independent of the app's override.
    static var systemPrefersDark: Bool {
        UIScreen.main.traitCollection.userInterfaceStyle == .dark
    }
    
    // MARK: - Init (read from UserDefaults; didSet is NOT called during init)
    
    private init() {
        // Feature toggles
        showSleepTracking = defaults.object(forKey: "showSleepTracking") as? Bool ?? true
        showFeedingTracking = defaults.object(forKey: "showFeedingTracking") as? Bool ?? true
        showDiaperTracking = defaults.object(forKey: "showDiaperTracking") as? Bool ?? true
        showBreastfeeding = defaults.object(forKey: "showBreastfeeding") as? Bool ?? true
        showBreastfeedingNotifications = defaults.object(forKey: "showBreastfeedingNotifications") as? Bool ?? true
        showOngoingStatus = defaults.object(forKey: "showOngoingStatus") as? Bool ?? true
        
        // Menu visibility
        showProfile = defaults.object(forKey: "showProfile") as? Bool ?? true
        showGrowth = defaults.object(forKey: "showGrowth") as? Bool ?? true
        showHealth = defaults.object(forKey: "showHealth") as? Bool ?? true
        showStats = defaults.object(forKey: "showStats") as? Bool ?? true
        showDataExport = defaults.object(forKey: "showDataExport") as? Bool ?? true
        
        // Active baby
        activeBabyID = defaults.string(forKey: "activeBabyID")
        
        // Appearance
        colorScheme = AppColorScheme(rawValue: defaults.string(forKey: "colorScheme") ?? "system") ?? .system
        autoNightTheme = defaults.object(forKey: "autoNightTheme") as? Bool ?? false
        accentColor = AppAccentColor(rawValue: defaults.string(forKey: "accentColor") ?? "rose") ?? .rose
        useCelsius = defaults.object(forKey: "useCelsius") as? Bool ?? true
        useMetric = defaults.object(forKey: "useMetric") as? Bool ?? true

        // Leona
        leonaSuggestions = defaults.object(forKey: "leonaSuggestions") as? Bool ?? true

        // Identity
        if let existing = defaults.string(forKey: "authorID") {
            authorID = existing
        } else {
            let fresh = UUID().uuidString
            defaults.set(fresh, forKey: "authorID")
            authorID = fresh
        }
        cloudUserID = defaults.string(forKey: "cloudUserID")
        adoptedCloudUserID = defaults.string(forKey: "adoptedCloudUserID")
        userDisplayName = defaults.string(forKey: "userDisplayName") ?? ""

        // Notifications
        feedingReminderInterval = defaults.object(forKey: "feedingReminderInterval") as? TimeInterval ?? 10800
        enableFeedingReminders = defaults.object(forKey: "enableFeedingReminders") as? Bool ?? true
        
        // iCloud
        iCloudSyncEnabled = defaults.object(forKey: "iCloudSyncEnabled") as? Bool ?? false
        
        // Onboarding
        hasCompletedOnboarding = defaults.bool(forKey: "hasCompletedOnboarding")

        // Clean up any leftover language override from previous versions
        defaults.removeObject(forKey: "AppleLanguages")
        defaults.removeObject(forKey: "appLanguage")
    }
}

// MARK: - Color Scheme

enum AppColorScheme: String, CaseIterable, Identifiable {
    case system
    case light
    case dark
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .system: return String(localized: "theme_system")
        case .light: return String(localized: "theme_light")
        case .dark: return String(localized: "theme_dark")
        }
    }
    
    var icon: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        }
    }
    
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

// MARK: - Accent Color (kept for stored settings of existing installs; the thread palette is fixed)

enum AppAccentColor: String, CaseIterable, Identifiable {
    case rose
    case bleu
    case violet
    case vert
    case orange
    case corail
    case ardoise
    case custom

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .rose: return String(localized: "accent_rose")
        case .bleu: return String(localized: "accent_blue")
        case .violet: return String(localized: "accent_purple")
        case .vert: return String(localized: "accent_green")
        case .orange: return String(localized: "accent_orange")
        case .corail: return String(localized: "accent_coral")
        case .ardoise: return String(localized: "accent_slate")
        case .custom: return String(localized: "accent_custom")
        }
    }

    var color: Color { .vermilion }
    var colorLight: Color { .vermilion.opacity(0.5) }
    var colorDark: Color { .vermilionDark }
}

// MARK: - Time Period for Stats

enum TimePeriod: String, CaseIterable, Identifiable {
    case today
    case threeDays
    case sevenDays
    case thirtyDays
    case sixMonths
    case twelveMonths
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .today: return String(localized: "period_today")
        case .threeDays: return String(localized: "period_3_days")
        case .sevenDays: return String(localized: "period_7_days")
        case .thirtyDays: return String(localized: "period_30_days")
        case .sixMonths: return String(localized: "period_6_months")
        case .twelveMonths: return String(localized: "period_12_months")
        }
    }
    
    var days: Int {
        switch self {
        case .today: return 1
        case .threeDays: return 3
        case .sevenDays: return 7
        case .thirtyDays: return 30
        case .sixMonths: return 180
        case .twelveMonths: return 365
        }
    }
    
    var startDate: Date {
        Calendar.current.date(byAdding: .day, value: -days, to: Calendar.current.startOfDay(for: Date())) ?? Date()
    }
}
