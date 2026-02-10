import Foundation
import SwiftUI

// MARK: - App Settings (UserDefaults backed)

@Observable
final class AppSettings {
    static let shared = AppSettings()
    
    private let defaults = UserDefaults.standard
    
    // MARK: - Feature Toggles
    
    var showSleepTracking: Bool {
        get { defaults.object(forKey: "showSleepTracking") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "showSleepTracking") }
    }
    
    var showFeedingTracking: Bool {
        get { defaults.object(forKey: "showFeedingTracking") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "showFeedingTracking") }
    }
    
    var showDiaperTracking: Bool {
        get { defaults.object(forKey: "showDiaperTracking") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "showDiaperTracking") }
    }
    
    var showBreastfeeding: Bool {
        get { defaults.object(forKey: "showBreastfeeding") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "showBreastfeeding") }
    }
    
    var showBreastfeedingNotifications: Bool {
        get { defaults.object(forKey: "showBreastfeedingNotifications") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "showBreastfeedingNotifications") }
    }
    
    var showOngoingStatus: Bool {
        get { defaults.object(forKey: "showOngoingStatus") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "showOngoingStatus") }
    }
    
    // MARK: - Menu Visibility
    
    var showProfile: Bool {
        get { defaults.object(forKey: "showProfile") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "showProfile") }
    }
    
    var showGrowth: Bool {
        get { defaults.object(forKey: "showGrowth") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "showGrowth") }
    }
    
    var showHealth: Bool {
        get { defaults.object(forKey: "showHealth") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "showHealth") }
    }
    
    var showStats: Bool {
        get { defaults.object(forKey: "showStats") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "showStats") }
    }
    
    var showDataExport: Bool {
        get { defaults.object(forKey: "showDataExport") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "showDataExport") }
    }
    
    // MARK: - Active Baby
    
    var activeBabyID: String? {
        get { defaults.string(forKey: "activeBabyID") }
        set { defaults.set(newValue, forKey: "activeBabyID") }
    }
    
    // MARK: - Appearance
    
    var colorScheme: AppColorScheme {
        get {
            let raw = defaults.string(forKey: "colorScheme") ?? "system"
            return AppColorScheme(rawValue: raw) ?? .system
        }
        set { defaults.set(newValue.rawValue, forKey: "colorScheme") }
    }
    
    var useCelsius: Bool {
        get { defaults.object(forKey: "useCelsius") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "useCelsius") }
    }
    
    var useMetric: Bool {
        get { defaults.object(forKey: "useMetric") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "useMetric") }
    }
    
    // MARK: - Language
    
    var language: AppLanguage {
        get {
            let raw = defaults.string(forKey: "appLanguage") ?? "system"
            return AppLanguage(rawValue: raw) ?? .system
        }
        set { defaults.set(newValue.rawValue, forKey: "appLanguage") }
    }
    
    // MARK: - Notification Preferences
    
    var feedingReminderInterval: TimeInterval {
        get { defaults.object(forKey: "feedingReminderInterval") as? TimeInterval ?? 10800 } // 3 hours
        set { defaults.set(newValue, forKey: "feedingReminderInterval") }
    }
    
    var enableFeedingReminders: Bool {
        get { defaults.object(forKey: "enableFeedingReminders") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "enableFeedingReminders") }
    }
    
    // MARK: - Onboarding
    
    var hasCompletedOnboarding: Bool {
        get { defaults.bool(forKey: "hasCompletedOnboarding") }
        set { defaults.set(newValue, forKey: "hasCompletedOnboarding") }
    }
    
    private init() {}
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
    
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
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
