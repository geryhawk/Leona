import Foundation

struct MealForecast {
    let nextIdealMealTime: Date
    let nextEstimatedIfMissed: Date
    let maxDelayTime: Date
    let estimatedVolumeML: Double
    let estimatedVolumeWithBreastfeedingML: Double
    let averageIntervalMinutes: Double
    let averageVolumeML: Double
    let lastFeedingTime: Date?
    let confidence: ForecastConfidence
    
    var timeUntilNextMeal: TimeInterval {
        nextIdealMealTime.timeIntervalSince(Date())
    }
    
    var isOverdue: Bool {
        timeUntilNextMeal < 0
    }
    
    var nextMealFormatted: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: nextIdealMealTime, relativeTo: Date())
    }
}

enum ForecastConfidence: String, Codable {
    case high
    case medium
    case low
    
    var displayName: String {
        switch self {
        case .high: return String(localized: "confidence_high")
        case .medium: return String(localized: "confidence_medium")
        case .low: return String(localized: "confidence_low")
        }
    }
}

// MARK: - Chart Data Points

struct ChartDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
    let label: String
    let category: String
}

struct GrowthChartPoint: Identifiable {
    let id = UUID()
    let ageInMonths: Double
    let value: Double
    let percentile: String?
}

struct WHOPercentilePoint: Identifiable {
    let id = UUID()
    let ageInMonths: Double
    let p3: Double
    let p15: Double
    let p50: Double
    let p85: Double
    let p97: Double
}
