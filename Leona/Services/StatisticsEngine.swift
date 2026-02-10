import Foundation
import SwiftData

/// Computes statistics and chart data from activity records
struct StatisticsEngine {
    
    // MARK: - Feeding Statistics
    
    static func feedingStats(
        activities: [Activity],
        period: TimePeriod
    ) -> FeedingStats {
        let start = period.startDate
        let filtered = activities.filter { $0.startTime >= start }
        
        let breastfeedings = filtered.filter { $0.type == .breastfeeding }
        let formulas = filtered.filter { $0.type == .formula }
        let momsMilk = filtered.filter { $0.type == .momsMilk }
        let solids = filtered.filter { $0.type == .solidFood }
        
        let totalFormulaMl = formulas.compactMap(\.volumeML).reduce(0, +)
        let totalMomsMilkMl = momsMilk.compactMap(\.volumeML).reduce(0, +)
        let totalBfDuration = breastfeedings.compactMap(\.duration).reduce(0, +)
        
        let avgFormulaPerDay = period.days > 0 ? totalFormulaMl / Double(period.days) : 0
        let avgBfPerDay = period.days > 0 ? Double(breastfeedings.count) / Double(period.days) : 0
        
        // Average interval between feedings
        let allFeedings = filtered
            .filter { $0.type.category == .feeding }
            .sorted { $0.startTime < $1.startTime }
        
        var avgInterval: TimeInterval = 0
        if allFeedings.count > 1 {
            var intervals: [TimeInterval] = []
            for i in 1..<allFeedings.count {
                intervals.append(allFeedings[i].startTime.timeIntervalSince(allFeedings[i-1].startTime))
            }
            avgInterval = intervals.reduce(0, +) / Double(intervals.count)
        }
        
        return FeedingStats(
            totalFeedings: filtered.filter { $0.type.category == .feeding }.count,
            breastfeedingCount: breastfeedings.count,
            formulaCount: formulas.count,
            momsMilkCount: momsMilk.count,
            solidFoodCount: solids.count,
            totalFormulaMl: totalFormulaMl,
            totalMomsMilkMl: totalMomsMilkMl,
            totalBreastfeedingDuration: totalBfDuration,
            averageFormulaPerDay: avgFormulaPerDay,
            averageBreastfeedingsPerDay: avgBfPerDay,
            averageInterval: avgInterval
        )
    }
    
    // MARK: - Sleep Statistics
    
    static func sleepStats(
        activities: [Activity],
        period: TimePeriod
    ) -> SleepStats {
        let start = period.startDate
        let sleeps = activities.filter { $0.type == .sleep && $0.startTime >= start && !$0.isOngoing }
        
        let totalDuration = sleeps.compactMap(\.duration).reduce(0, +)
        let avgPerDay = period.days > 0 ? totalDuration / Double(period.days) : 0
        
        // Day vs Night sleep
        let daySleeps = sleeps.filter {
            let hour = Calendar.current.component(.hour, from: $0.startTime)
            return hour >= 7 && hour < 19
        }
        let nightSleeps = sleeps.filter {
            let hour = Calendar.current.component(.hour, from: $0.startTime)
            return hour < 7 || hour >= 19
        }
        
        let dayDuration = daySleeps.compactMap(\.duration).reduce(0, +)
        let nightDuration = nightSleeps.compactMap(\.duration).reduce(0, +)
        
        let longestSleep = sleeps.compactMap(\.duration).max() ?? 0
        let shortestSleep = sleeps.compactMap(\.duration).min() ?? 0
        
        return SleepStats(
            totalSessions: sleeps.count,
            totalDuration: totalDuration,
            averageDurationPerDay: avgPerDay,
            dayDuration: dayDuration,
            nightDuration: nightDuration,
            longestSession: longestSleep,
            shortestSession: shortestSleep,
            averageSessionDuration: sleeps.isEmpty ? 0 : totalDuration / Double(sleeps.count)
        )
    }
    
    // MARK: - Diaper Statistics
    
    static func diaperStats(
        activities: [Activity],
        period: TimePeriod
    ) -> DiaperStats {
        let start = period.startDate
        let diapers = activities.filter { $0.type == .diaper && $0.startTime >= start }
        
        let pees = diapers.filter { $0.diaperType == .pee }.count
        let poops = diapers.filter { $0.diaperType == .poop }.count
        let boths = diapers.filter { $0.diaperType == .both }.count
        
        let avgPerDay = period.days > 0 ? Double(diapers.count) / Double(period.days) : 0
        
        return DiaperStats(
            totalChanges: diapers.count,
            peeCount: pees,
            poopCount: poops,
            bothCount: boths,
            averagePerDay: avgPerDay
        )
    }
    
    // MARK: - Chart Data Points
    
    static func feedingChartData(
        activities: [Activity],
        period: TimePeriod
    ) -> [ChartDataPoint] {
        let start = period.startDate
        let filtered = activities.filter { $0.startTime >= start && $0.type.category == .feeding }
        
        var points: [ChartDataPoint] = []
        let calendar = Calendar.current
        
        let grouped = Dictionary(grouping: filtered) { activity in
            calendar.startOfDay(for: activity.startTime)
        }
        
        for (date, activities) in grouped.sorted(by: { $0.key < $1.key }) {
            // Formula volume
            let formulaVol = activities
                .filter { $0.type == .formula }
                .compactMap(\.volumeML)
                .reduce(0, +)
            if formulaVol > 0 {
                points.append(ChartDataPoint(date: date, value: formulaVol, label: "Formula", category: "formula"))
            }
            
            // Mom's milk volume
            let momsVol = activities
                .filter { $0.type == .momsMilk }
                .compactMap(\.volumeML)
                .reduce(0, +)
            if momsVol > 0 {
                points.append(ChartDataPoint(date: date, value: momsVol, label: "Mom's Milk", category: "momsMilk"))
            }
            
            // Breastfeeding count
            let bfCount = activities.filter { $0.type == .breastfeeding }.count
            if bfCount > 0 {
                points.append(ChartDataPoint(date: date, value: Double(bfCount), label: "Breastfeeding", category: "breastfeeding"))
            }
            
            // Solid food count
            let solidCount = activities.filter { $0.type == .solidFood }.count
            if solidCount > 0 {
                points.append(ChartDataPoint(date: date, value: Double(solidCount), label: "Solid Food", category: "solidFood"))
            }
        }
        
        return points
    }
    
    static func sleepChartData(
        activities: [Activity],
        period: TimePeriod
    ) -> [ChartDataPoint] {
        let start = period.startDate
        let sleeps = activities.filter { $0.type == .sleep && $0.startTime >= start && !$0.isOngoing }
        
        var points: [ChartDataPoint] = []
        let calendar = Calendar.current
        
        let grouped = Dictionary(grouping: sleeps) { activity in
            calendar.startOfDay(for: activity.startTime)
        }
        
        for (date, dayActivities) in grouped.sorted(by: { $0.key < $1.key }) {
            let daySleepHours = dayActivities
                .filter {
                    let hour = calendar.component(.hour, from: $0.startTime)
                    return hour >= 7 && hour < 19
                }
                .compactMap(\.duration)
                .reduce(0, +) / 3600
            
            let nightSleepHours = dayActivities
                .filter {
                    let hour = calendar.component(.hour, from: $0.startTime)
                    return hour < 7 || hour >= 19
                }
                .compactMap(\.duration)
                .reduce(0, +) / 3600
            
            if daySleepHours > 0 {
                points.append(ChartDataPoint(date: date, value: daySleepHours, label: "Day", category: "day"))
            }
            if nightSleepHours > 0 {
                points.append(ChartDataPoint(date: date, value: nightSleepHours, label: "Night", category: "night"))
            }
        }
        
        return points
    }
    
    static func diaperChartData(
        activities: [Activity],
        period: TimePeriod
    ) -> [ChartDataPoint] {
        let start = period.startDate
        let diapers = activities.filter { $0.type == .diaper && $0.startTime >= start }
        
        var points: [ChartDataPoint] = []
        let calendar = Calendar.current
        
        let grouped = Dictionary(grouping: diapers) { activity in
            calendar.startOfDay(for: activity.startTime)
        }
        
        for (date, dayActivities) in grouped.sorted(by: { $0.key < $1.key }) {
            let pees = dayActivities.filter { $0.diaperType == .pee || $0.diaperType == .both }.count
            let poops = dayActivities.filter { $0.diaperType == .poop || $0.diaperType == .both }.count
            
            if pees > 0 {
                points.append(ChartDataPoint(date: date, value: Double(pees), label: "Pee", category: "pee"))
            }
            if poops > 0 {
                points.append(ChartDataPoint(date: date, value: Double(poops), label: "Poop", category: "poop"))
            }
        }
        
        return points
    }
}

// MARK: - Stats Models

struct FeedingStats {
    let totalFeedings: Int
    let breastfeedingCount: Int
    let formulaCount: Int
    let momsMilkCount: Int
    let solidFoodCount: Int
    let totalFormulaMl: Double
    let totalMomsMilkMl: Double
    let totalBreastfeedingDuration: TimeInterval
    let averageFormulaPerDay: Double
    let averageBreastfeedingsPerDay: Double
    let averageInterval: TimeInterval
    
    static let empty = FeedingStats(
        totalFeedings: 0, breastfeedingCount: 0, formulaCount: 0,
        momsMilkCount: 0, solidFoodCount: 0, totalFormulaMl: 0,
        totalMomsMilkMl: 0, totalBreastfeedingDuration: 0,
        averageFormulaPerDay: 0, averageBreastfeedingsPerDay: 0, averageInterval: 0
    )
}

struct SleepStats {
    let totalSessions: Int
    let totalDuration: TimeInterval
    let averageDurationPerDay: TimeInterval
    let dayDuration: TimeInterval
    let nightDuration: TimeInterval
    let longestSession: TimeInterval
    let shortestSession: TimeInterval
    let averageSessionDuration: TimeInterval
    
    static let empty = SleepStats(
        totalSessions: 0, totalDuration: 0, averageDurationPerDay: 0,
        dayDuration: 0, nightDuration: 0, longestSession: 0,
        shortestSession: 0, averageSessionDuration: 0
    )
}

struct DiaperStats {
    let totalChanges: Int
    let peeCount: Int
    let poopCount: Int
    let bothCount: Int
    let averagePerDay: Double
    
    static let empty = DiaperStats(
        totalChanges: 0, peeCount: 0, poopCount: 0, bothCount: 0, averagePerDay: 0
    )
}
