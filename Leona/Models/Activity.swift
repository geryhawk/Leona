import Foundation
import SwiftData
import SwiftUI

@Model
final class Activity {
    var id: UUID = UUID()
    var type: ActivityType = ActivityType.note
    var startTime: Date = Date()
    var endTime: Date?
    var isOngoing: Bool = false
    
    // Feeding
    var volumeML: Double?
    var breastSide: BreastSide?
    var sessionSlot: SessionSlot?
    
    // Solid food
    var foodName: String?
    var foodQuantity: Double?
    var foodUnit: FoodUnit?
    
    // Diaper
    var diaperType: DiaperType?
    
    // Note
    var noteText: String?
    
    // Relationship
    var baby: Baby?

    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    // CloudKit sharing metadata
    var ckRecordName: String?
    var ckChangeTag: String?
    
    init(
        type: ActivityType,
        startTime: Date = Date(),
        endTime: Date? = nil,
        isOngoing: Bool = false,
        baby: Baby? = nil
    ) {
        self.id = UUID()
        self.type = type
        self.startTime = startTime
        self.endTime = endTime
        self.isOngoing = isOngoing
        self.baby = baby
        self.createdAt = Date()
        self.updatedAt = Date()
    }
    
    var duration: TimeInterval? {
        guard let end = endTime else {
            return isOngoing ? Date().timeIntervalSince(startTime) : nil
        }
        return end.timeIntervalSince(startTime)
    }
    
    var durationFormatted: String {
        guard let duration = duration else { return "--" }
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        if hours > 0 {
            return String(localized: "duration_hours_minutes \(hours) \(minutes)")
        }
        return String(localized: "duration_minutes \(minutes)")
    }
    
    var sortTime: Date {
        endTime ?? startTime
    }
    
    var summaryText: String {
        switch type {
        case .breastfeeding:
            let side = breastSide?.displayName ?? ""
            let dur = durationFormatted
            return "\(side) · \(dur)"
            
        case .formula:
            let vol = Int(volumeML ?? 0)
            return String(localized: "formula_summary \(vol)")
            
        case .momsMilk:
            let vol = Int(volumeML ?? 0)
            return String(localized: "moms_milk_summary \(vol)")
            
        case .solidFood:
            let name = foodName ?? ""
            let qty = foodQuantity ?? 0
            let unit = foodUnit?.symbol ?? ""
            return "\(name) · \(String(format: "%.0f", qty))\(unit)"
            
        case .sleep:
            return durationFormatted
            
        case .diaper:
            return diaperType?.displayName ?? ""
            
        case .note:
            return noteText ?? ""
        }
    }
}

// MARK: - Activity Type

enum ActivityType: String, Codable, CaseIterable, Identifiable {
    case breastfeeding
    case formula
    case momsMilk
    case solidFood
    case sleep
    case diaper
    case note
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .breastfeeding: return String(localized: "activity_breastfeeding")
        case .formula: return String(localized: "activity_formula")
        case .momsMilk: return String(localized: "activity_moms_milk")
        case .solidFood: return String(localized: "activity_solid_food")
        case .sleep: return String(localized: "activity_sleep")
        case .diaper: return String(localized: "activity_diaper")
        case .note: return String(localized: "activity_note")
        }
    }
    
    var icon: String {
        switch self {
        case .breastfeeding: return "heart.fill"
        case .formula: return "cup.and.saucer.fill"
        case .momsMilk: return "drop.fill"
        case .solidFood: return "fork.knife"
        case .sleep: return "moon.fill"
        case .diaper: return "humidity.fill"
        case .note: return "note.text"
        }
    }
    
    var color: Color {
        switch self {
        case .breastfeeding: return .pink
        case .formula: return .orange
        case .momsMilk: return .purple
        case .solidFood: return .green
        case .sleep: return .indigo
        case .diaper: return .cyan
        case .note: return .gray
        }
    }
    
    var category: ActivityCategory {
        switch self {
        case .breastfeeding, .formula, .momsMilk, .solidFood:
            return .feeding
        case .sleep:
            return .sleep
        case .diaper:
            return .diaper
        case .note:
            return .note
        }
    }
    
    static var feedingTypes: [ActivityType] {
        [.breastfeeding, .formula, .momsMilk, .solidFood]
    }
}

enum ActivityCategory: String, CaseIterable, Identifiable {
    case feeding
    case sleep
    case diaper
    case note
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .feeding: return String(localized: "category_feeding")
        case .sleep: return String(localized: "category_sleep")
        case .diaper: return String(localized: "category_diaper")
        case .note: return String(localized: "category_notes")
        }
    }
}

// MARK: - Breast Side

enum BreastSide: String, Codable, CaseIterable, Identifiable {
    case left
    case right
    case both
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .left: return String(localized: "breast_left")
        case .right: return String(localized: "breast_right")
        case .both: return String(localized: "breast_both")
        }
    }
    
    var shortName: String {
        switch self {
        case .left: return "L"
        case .right: return "R"
        case .both: return "L+R"
        }
    }
    
    var icon: String {
        switch self {
        case .left: return "arrow.left.circle.fill"
        case .right: return "arrow.right.circle.fill"
        case .both: return "arrow.left.arrow.right.circle.fill"
        }
    }
}

// MARK: - Session Slot

enum SessionSlot: String, Codable, CaseIterable, Identifiable {
    case morning
    case day
    case evening
    case night
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .morning: return String(localized: "slot_morning")
        case .day: return String(localized: "slot_day")
        case .evening: return String(localized: "slot_evening")
        case .night: return String(localized: "slot_night")
        }
    }
    
    var icon: String {
        switch self {
        case .morning: return "sunrise.fill"
        case .day: return "sun.max.fill"
        case .evening: return "sunset.fill"
        case .night: return "moon.stars.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .morning: return .orange
        case .day: return .yellow
        case .evening: return .purple
        case .night: return .indigo
        }
    }
    
    static func current(for date: Date = Date()) -> SessionSlot {
        let hour = Calendar.current.component(.hour, from: date)
        switch hour {
        case 5..<11: return .morning
        case 11..<17: return .day
        case 17..<21: return .evening
        default: return .night
        }
    }
}

// MARK: - Diaper Type

enum DiaperType: String, Codable, CaseIterable, Identifiable {
    case pee
    case poop
    case both
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .pee: return String(localized: "diaper_pee")
        case .poop: return String(localized: "diaper_poop")
        case .both: return String(localized: "diaper_both")
        }
    }
    
    var icon: String {
        switch self {
        case .pee: return "drop.fill"
        case .poop: return "leaf.fill"
        case .both: return "sparkles"
        }
    }
    
    var color: Color {
        switch self {
        case .pee: return .yellow
        case .poop: return .brown
        case .both: return .orange
        }
    }
}

// MARK: - Food Unit

enum FoodUnit: String, Codable, CaseIterable, Identifiable {
    case grams
    case milliliters
    case pieces
    case tablespoons
    case teaspoons
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .grams: return String(localized: "unit_grams")
        case .milliliters: return String(localized: "unit_ml")
        case .pieces: return String(localized: "unit_pieces")
        case .tablespoons: return String(localized: "unit_tbsp")
        case .teaspoons: return String(localized: "unit_tsp")
        }
    }
    
    var symbol: String {
        switch self {
        case .grams: return "g"
        case .milliliters: return "ml"
        case .pieces: return "pcs"
        case .tablespoons: return "tbsp"
        case .teaspoons: return "tsp"
        }
    }
}
