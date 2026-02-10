import Foundation

extension Date {
    
    var isToday: Bool {
        Calendar.current.isDateInToday(self)
    }
    
    var isYesterday: Bool {
        Calendar.current.isDateInYesterday(self)
    }
    
    var isTomorrow: Bool {
        Calendar.current.isDateInTomorrow(self)
    }
    
    var isInPast: Bool {
        self < Date()
    }
    
    var isInFuture: Bool {
        self > Date()
    }
    
    var startOfDay: Date {
        Calendar.current.startOfDay(for: self)
    }
    
    var endOfDay: Date {
        Calendar.current.date(bySettingHour: 23, minute: 59, second: 59, of: self) ?? self
    }
    
    var timeString: String {
        formatted(date: .omitted, time: .shortened)
    }
    
    var dateString: String {
        formatted(date: .abbreviated, time: .omitted)
    }
    
    var dateTimeString: String {
        formatted(date: .abbreviated, time: .shortened)
    }
    
    var relativeString: String {
        if isToday {
            return String(localized: "date_today")
        } else if isYesterday {
            return String(localized: "date_yesterday")
        } else if isTomorrow {
            return String(localized: "date_tomorrow")
        } else {
            return dateString
        }
    }
    
    var smartDateTimeString: String {
        if isToday {
            return String(localized: "date_today_at \(timeString)")
        } else if isYesterday {
            return String(localized: "date_yesterday_at \(timeString)")
        } else {
            return dateTimeString
        }
    }
    
    func timeAgo() -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: self, relativeTo: Date())
    }
    
    var isDaytime: Bool {
        let hour = Calendar.current.component(.hour, from: self)
        return hour >= 7 && hour < 19
    }
    
    var sessionSlot: SessionSlot {
        SessionSlot.current(for: self)
    }
}

// MARK: - TimeInterval Formatting

extension TimeInterval {
    
    var hoursMinutesFormatted: String {
        let hours = Int(self) / 3600
        let minutes = (Int(self) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }
    
    var hoursMinutesSecondsFormatted: String {
        let hours = Int(self) / 3600
        let minutes = (Int(self) % 3600) / 60
        let seconds = Int(self) % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    var compactFormatted: String {
        let hours = Int(self) / 3600
        let minutes = (Int(self) % 3600) / 60
        if hours > 0 {
            return minutes > 0 ? "\(hours)h\(minutes)m" : "\(hours)h"
        }
        return "\(minutes)m"
    }
}
