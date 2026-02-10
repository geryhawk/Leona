import Foundation

/// Predicts next meal timing and volume based on historical patterns
struct MealForecastEngine {
    
    /// Generate a meal forecast based on recent feeding activities
    static func forecast(from activities: [Activity], babyAgeInDays: Int) -> MealForecast? {
        let feedings = activities
            .filter { $0.type.category == .feeding && !$0.isOngoing }
            .sorted { $0.startTime > $1.startTime }
        
        guard let lastFeeding = feedings.first else { return nil }
        
        // Use last 7 days of data for pattern analysis
        let recentFeedings = feedings.filter {
            $0.startTime > Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        }
        
        guard recentFeedings.count >= 2 else { return nil }
        
        // Calculate average interval between feedings
        let sortedByTime = recentFeedings.sorted { $0.startTime < $1.startTime }
        var intervals: [TimeInterval] = []
        for i in 1..<sortedByTime.count {
            let interval = sortedByTime[i].startTime.timeIntervalSince(sortedByTime[i-1].startTime)
            // Only consider reasonable intervals (30 min to 8 hours)
            if interval > 1800 && interval < 28800 {
                intervals.append(interval)
            }
        }
        
        guard !intervals.isEmpty else { return nil }
        
        let avgInterval = intervals.reduce(0, +) / Double(intervals.count)
        let avgIntervalMinutes = avgInterval / 60
        
        // Calculate average volume
        let volumes = recentFeedings
            .filter { $0.type == .formula || $0.type == .momsMilk }
            .compactMap(\.volumeML)
        let avgVolume = volumes.isEmpty ? estimatedVolumeForAge(days: babyAgeInDays) : volumes.reduce(0, +) / Double(volumes.count)
        
        // Adjust volume for breastfeeding offset
        let bfCount = recentFeedings.filter { $0.type == .breastfeeding }.count
        let totalFeedings = recentFeedings.count
        let bfRatio = totalFeedings > 0 ? Double(bfCount) / Double(totalFeedings) : 0
        let volumeWithBf = avgVolume * (1 - bfRatio * 0.3)
        
        // Calculate forecast times
        let nextIdealTime = lastFeeding.startTime.addingTimeInterval(avgInterval)
        let nextIfMissed = nextIdealTime.addingTimeInterval(avgInterval * 0.3)
        let maxDelay = lastFeeding.startTime.addingTimeInterval(avgInterval * 1.5)
        
        // Determine confidence
        let confidence: ForecastConfidence
        if recentFeedings.count >= 10 {
            let standardDeviation = calculateStdDev(intervals)
            confidence = standardDeviation < avgInterval * 0.3 ? .high : .medium
        } else if recentFeedings.count >= 5 {
            confidence = .medium
        } else {
            confidence = .low
        }
        
        return MealForecast(
            nextIdealMealTime: nextIdealTime,
            nextEstimatedIfMissed: nextIfMissed,
            maxDelayTime: maxDelay,
            estimatedVolumeML: avgVolume,
            estimatedVolumeWithBreastfeedingML: volumeWithBf,
            averageIntervalMinutes: avgIntervalMinutes,
            averageVolumeML: avgVolume,
            lastFeedingTime: lastFeeding.startTime,
            confidence: confidence
        )
    }
    
    // MARK: - Age-Based Volume Estimation
    
    private static func estimatedVolumeForAge(days: Int) -> Double {
        switch days {
        case 0...3: return 30      // Colostrum period
        case 4...7: return 50      // Early newborn
        case 8...14: return 70     // Second week
        case 15...30: return 90    // First month
        case 31...60: return 120   // 1-2 months
        case 61...120: return 150  // 2-4 months
        case 121...180: return 180 // 4-6 months
        case 181...270: return 200 // 6-9 months
        case 271...365: return 210 // 9-12 months
        default: return 200        // 12+ months
        }
    }
    
    // MARK: - Standard Deviation
    
    private static func calculateStdDev(_ values: [Double]) -> Double {
        let count = Double(values.count)
        guard count > 1 else { return 0 }
        let mean = values.reduce(0, +) / count
        let variance = values.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / (count - 1)
        return sqrt(variance)
    }
}
