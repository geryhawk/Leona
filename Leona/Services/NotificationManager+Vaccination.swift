import Foundation
import UserNotifications

extension NotificationManager {

    /// One reminder, a week before the next vaccination at 09:00.
    /// Replaces any pending vaccination reminder.
    func scheduleVaccinationReminder(babyName: String, date: Date) async {
        guard isAuthorized else { return }

        let identifier = "vaccination-reminder"
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [identifier])

        let content = UNMutableNotificationContent()
        content.title = String(localized: "notification_vaccination_title")
        content.body = String(localized: "notification_vaccination_body \(babyName)")
        content.sound = .default
        content.interruptionLevel = .timeSensitive

        let calendar = Calendar.current
        let weekBefore = calendar.date(byAdding: .day, value: -7, to: date) ?? date
        var components = calendar.dateComponents([.year, .month, .day], from: weekBefore)
        components.hour = 9
        components.minute = 0

        let trigger: UNNotificationTrigger
        if let fireDate = calendar.date(from: components), fireDate > Date() {
            trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        } else {
            // The week-before slot has already passed: deliver shortly instead of never.
            trigger = UNTimeIntervalNotificationTrigger(timeInterval: 60, repeats: false)
        }

        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        try? await center.add(request)
    }
}
