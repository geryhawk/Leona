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
    
    // MARK: - Menu Visibility
    
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
    
    var accentColor: AppAccentColor {
        didSet { defaults.set(accentColor.rawValue, forKey: "accentColor") }
    }
    
    var useCelsius: Bool {
        didSet { defaults.set(useCelsius, forKey: "useCelsius") }
    }
    
    var useMetric: Bool {
        didSet { defaults.set(useMetric, forKey: "useMetric") }
    }
    
    // MARK: - Language
    
    var language: AppLanguage {
        didSet {
            defaults.set(language.rawValue, forKey: "appLanguage")
            // Apply language change immediately via bundle swizzle
            switch language {
            case .system: Bundle.setLanguage(nil)
            case .english: Bundle.setLanguage("en")
            case .french: Bundle.setLanguage("fr")
            case .finnish: Bundle.setLanguage("fi")
            }
        }
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
        accentColor = AppAccentColor(rawValue: defaults.string(forKey: "accentColor") ?? "rose") ?? .rose
        useCelsius = defaults.object(forKey: "useCelsius") as? Bool ?? true
        useMetric = defaults.object(forKey: "useMetric") as? Bool ?? true
        
        // Language
        language = AppLanguage(rawValue: defaults.string(forKey: "appLanguage") ?? "system") ?? .system
        
        // Notifications
        feedingReminderInterval = defaults.object(forKey: "feedingReminderInterval") as? TimeInterval ?? 10800
        enableFeedingReminders = defaults.object(forKey: "enableFeedingReminders") as? Bool ?? true
        
        // iCloud
        iCloudSyncEnabled = defaults.object(forKey: "iCloudSyncEnabled") as? Bool ?? true
        
        // Onboarding
        hasCompletedOnboarding = defaults.bool(forKey: "hasCompletedOnboarding")
        
        // Apply saved language on startup (didSet won't fire during init)
        switch language {
        case .system: Bundle.setLanguage(nil)
        case .english: Bundle.setLanguage("en")
        case .french: Bundle.setLanguage("fr")
        case .finnish: Bundle.setLanguage("fi")
        }
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

// MARK: - Accent Color

enum AppAccentColor: String, CaseIterable, Identifiable {
    case rose
    case bleu
    case violet
    case vert
    case orange
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .rose: return String(localized: "accent_rose")
        case .bleu: return String(localized: "accent_blue")
        case .violet: return String(localized: "accent_purple")
        case .vert: return String(localized: "accent_green")
        case .orange: return String(localized: "accent_orange")
        }
    }
    
    var color: Color {
        switch self {
        case .rose: return Color(red: 0.863, green: 0.518, blue: 0.639)
        case .bleu: return Color(red: 0.4, green: 0.6, blue: 0.85)
        case .violet: return Color(red: 0.6, green: 0.4, blue: 0.8)
        case .vert: return Color(red: 0.34, green: 0.7, blue: 0.53)
        case .orange: return Color(red: 0.95, green: 0.6, blue: 0.3)
        }
    }
    
    var colorLight: Color {
        switch self {
        case .rose: return Color(red: 0.949, green: 0.784, blue: 0.847)
        case .bleu: return Color(red: 0.7, green: 0.82, blue: 0.95)
        case .violet: return Color(red: 0.8, green: 0.7, blue: 0.93)
        case .vert: return Color(red: 0.7, green: 0.9, blue: 0.78)
        case .orange: return Color(red: 0.98, green: 0.82, blue: 0.6)
        }
    }
    
    var colorDark: Color {
        switch self {
        case .rose: return Color(red: 0.694, green: 0.361, blue: 0.478)
        case .bleu: return Color(red: 0.2, green: 0.3, blue: 0.55)
        case .violet: return Color(red: 0.4, green: 0.25, blue: 0.6)
        case .vert: return Color(red: 0.2, green: 0.5, blue: 0.35)
        case .orange: return Color(red: 0.75, green: 0.4, blue: 0.15)
        }
    }
}

// MARK: - Language

enum AppLanguage: String, CaseIterable, Identifiable {
    case system
    case english = "en"
    case french = "fr"
    case finnish = "fi"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .system: return String(localized: "language_system")
        case .english: return "English"
        case .french: return "Français"
        case .finnish: return "Suomi"
        }
    }
    
    var flag: String {
        switch self {
        case .system: return "🌐"
        case .english: return "🇬🇧"
        case .french: return "🇫🇷"
        case .finnish: return "🇫🇮"
        }
    }
    
    var locale: Locale? {
        switch self {
        case .system: return nil
        case .english: return Locale(identifier: "en")
        case .french: return Locale(identifier: "fr")
        case .finnish: return Locale(identifier: "fi")
        }
    }
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
