import Foundation
import UserNotifications
import SwiftUI

@Observable
final class NotificationManager {
    static let shared = NotificationManager()
    
    var isAuthorized = false
    
    private let center = UNUserNotificationCenter.current()
    
    private init() {}
    
    // MARK: - Authorization
    
    func requestAuthorization() async -> Bool {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            await MainActor.run {
                self.isAuthorized = granted
            }
            return granted
        } catch {
            return false
        }
    }
    
    func checkAuthorization() async {
        let settings = await center.notificationSettings()
        await MainActor.run {
            self.isAuthorized = settings.authorizationStatus == .authorized
        }
    }
    
    // MARK: - Feeding Reminders
    
    func scheduleFeedingReminder(
        babyName: String,
        lastFeedingTime: Date,
        intervalMinutes: Double = 180
    ) async {
        guard isAuthorized else { return }
        
        // Remove existing feeding reminders
        center.removePendingNotificationRequests(withIdentifiers: ["feeding-reminder"])
        
        let content = UNMutableNotificationContent()
        content.title = String(localized: "notification_feeding_title")
        content.body = String(localized: "notification_feeding_body \(babyName)")
        content.sound = .default
        content.categoryIdentifier = "FEEDING_REMINDER"
        content.interruptionLevel = .timeSensitive
        
        let triggerDate = lastFeedingTime.addingTimeInterval(intervalMinutes * 60)
        let timeInterval = max(triggerDate.timeIntervalSinceNow, 60)
        
        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: timeInterval,
            repeats: false
        )
        
        let request = UNNotificationRequest(
            identifier: "feeding-reminder",
            content: content,
            trigger: trigger
        )
        
        try? await center.add(request)
    }
    
    // MARK: - Sleep Reminder
    
    func scheduleSleepCheckReminder(babyName: String, sleepStartTime: Date) async {
        guard isAuthorized else { return }
        
        center.removePendingNotificationRequests(withIdentifiers: ["sleep-check"])
        
        let content = UNMutableNotificationContent()
        content.title = String(localized: "notification_sleep_title")
        content.body = String(localized: "notification_sleep_body \(babyName)")
        content.sound = .default
        content.categoryIdentifier = "SLEEP_CHECK"
        
        // Remind after 2 hours of sleep
        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: max(sleepStartTime.addingTimeInterval(7200).timeIntervalSinceNow, 60),
            repeats: false
        )
        
        let request = UNNotificationRequest(
            identifier: "sleep-check",
            content: content,
            trigger: trigger
        )
        
        try? await center.add(request)
    }
    
    // MARK: - Breastfeeding Session Reminders
    
    func scheduleBreastfeedingReminder(
        babyName: String,
        sessionSlot: SessionSlot,
        scheduledTime: Date
    ) async {
        guard isAuthorized else { return }
        
        let identifier = "bf-\(sessionSlot.rawValue)"
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        
        let content = UNMutableNotificationContent()
        content.title = String(localized: "notification_bf_title")
        content.body = String(localized: "notification_bf_body \(babyName) \(sessionSlot.displayName)")
        content.sound = .default
        content.categoryIdentifier = "BREASTFEEDING_REMINDER"
        content.interruptionLevel = .timeSensitive
        
        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: max(scheduledTime.timeIntervalSinceNow, 60),
            repeats: false
        )
        
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        )
        
        try? await center.add(request)
    }
    
    // MARK: - Milestone Notifications
    
    func scheduleMilestoneNotification(
        babyName: String,
        milestone: String,
        date: Date
    ) async {
        guard isAuthorized else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "🎉 \(String(localized: "notification_milestone_title"))"
        content.body = String(localized: "notification_milestone_body \(babyName) \(milestone)")
        content.sound = .default
        
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        
        let request = UNNotificationRequest(
            identifier: "milestone-\(milestone)",
            content: content,
            trigger: trigger
        )
        
        try? await center.add(request)
    }
    
    // MARK: - Cancel
    
    func cancelAllNotifications() {
        center.removeAllPendingNotificationRequests()
    }
    
    func cancelNotification(identifier: String) {
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
    }
    
    // MARK: - Snooze
    
    func snoozeNotification(identifier: String, minutes: Double = 30) async {
        // Remove the current notification
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        
        let content = UNMutableNotificationContent()
        content.title = String(localized: "notification_snoozed_title")
        content.body = String(localized: "notification_snoozed_body")
        content.sound = .default
        
        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: minutes * 60,
            repeats: false
        )
        
        let request = UNNotificationRequest(
            identifier: "\(identifier)-snoozed",
            content: content,
            trigger: trigger
        )
        
        try? await center.add(request)
    }
    
    // MARK: - Setup Categories
    
    func setupNotificationCategories() {
        let snoozeAction = UNNotificationAction(
            identifier: "SNOOZE_ACTION",
            title: String(localized: "notification_action_snooze"),
            options: []
        )
        
        let dismissAction = UNNotificationAction(
            identifier: "DISMISS_ACTION",
            title: String(localized: "notification_action_dismiss"),
            options: .destructive
        )
        
        let feedingCategory = UNNotificationCategory(
            identifier: "FEEDING_REMINDER",
            actions: [snoozeAction, dismissAction],
            intentIdentifiers: []
        )
        
        let bfCategory = UNNotificationCategory(
            identifier: "BREASTFEEDING_REMINDER",
            actions: [snoozeAction, dismissAction],
            intentIdentifiers: []
        )
        
        let sleepCategory = UNNotificationCategory(
            identifier: "SLEEP_CHECK",
            actions: [dismissAction],
            intentIdentifiers: []
        )
        
        center.setNotificationCategories([feedingCategory, bfCategory, sleepCategory])
    }
}
