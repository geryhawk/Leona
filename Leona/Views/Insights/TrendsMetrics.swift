import Foundation

// MARK: - Period

enum TrendsPeriod: Int, CaseIterable, Identifiable {
    case threeDays = 3
    case sevenDays = 7
    case thirtyDays = 30

    var id: Int { rawValue }
    var days: Int { rawValue }
    var title: String { String(localized: "trends_days \(rawValue)") }
}

// MARK: - Per-day series

struct TrendsDay: Identifiable {
    let date: Date
    var milkML: Double = 0
    var nightSeconds: TimeInterval = 0
    var napSeconds: TimeInterval = 0
    var feeds = 0
    var diapers = 0
    /// True from the first day anything was ever logged; earlier days are not gaps, just silence.
    var isTracked = false

    var id: Date { date }
    var sleepSeconds: TimeInterval { nightSeconds + napSeconds }
}

struct TrendsWindow {
    let days: [TrendsDay]

    var tracked: [TrendsDay] { days.filter(\.isTracked) }
    var hasSleep: Bool { tracked.contains { $0.sleepSeconds > 0 } }
    var milkDays: [Double] { tracked.map(\.milkML).filter { $0 > 0 } }

    var milkPerDay: Double? { TrendsMath.mean(tracked.map(\.milkML)) }
    var nightSecondsPerDay: TimeInterval? { TrendsMath.mean(tracked.map(\.nightSeconds)) }
    var napSecondsPerDay: TimeInterval? { TrendsMath.mean(tracked.map(\.napSeconds)) }
    var sleepHoursPerDay: Double? { TrendsMath.mean(tracked.map { $0.sleepSeconds / 3600 }) }
    var feedsPerDay: Double? { TrendsMath.mean(tracked.map { Double($0.feeds) }) }
    var diapersPerDay: Double? { TrendsMath.mean(tracked.map { Double($0.diapers) }) }
}

enum TrendsMath {
    static func mean(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }

    /// Coefficient of variation: standard deviation over the mean.
    static func variation(_ values: [Double]) -> Double? {
        guard values.count >= 2, let mean = mean(values), mean > 0 else { return nil }
        let variance = values.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / Double(values.count)
        return variance.squareRoot() / mean
    }

    static func signed(_ seconds: TimeInterval) -> String {
        (seconds < 0 ? "−" : "+") + ThreadFormat.durShort(abs(seconds))
    }
}

// MARK: - What changed

struct TrendsChange: Identifiable {
    let id: String
    let delta: String
    let what: String
    let isGain: Bool
}

// MARK: - Metrics

/// Everything the Trends screen says is derived here from the thread, for the chosen period
/// and the period of the same length just before it.
struct TrendsMetrics {
    let period: TrendsPeriod
    let babyName: String
    let current: TrendsWindow
    let previous: TrendsWindow
    /// Weight change between the two most recent weighed records, in kilograms.
    let weightChange: (deltaKg: Double, since: Date)?

    init(activities: [Activity], growthRecords: [GrowthRecord], baby: Baby, period: TrendsPeriod, now: Date = Date()) {
        self.period = period
        self.babyName = baby.displayName

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        let finished = activities.filter { !$0.isOngoing }
        let firstLogDay = finished.map { calendar.startOfDay(for: $0.startTime) }.min()
        let currentStart = calendar.date(byAdding: .day, value: -(period.days - 1), to: today) ?? today
        let previousStart = calendar.date(byAdding: .day, value: -period.days, to: currentStart) ?? currentStart

        current = Self.window(finished, from: currentStart, days: period.days, firstLogDay: firstLogDay, calendar: calendar)
        previous = Self.window(finished, from: previousStart, days: period.days, firstLogDay: firstLogDay, calendar: calendar)

        let weighed = growthRecords
            .filter { $0.weightKg != nil }
            .sorted { $0.date > $1.date }
        if weighed.count >= 2, let latest = weighed[0].weightKg, let before = weighed[1].weightKg {
            weightChange = (latest - before, weighed[1].date)
        } else {
            weightChange = nil
        }
    }

    private static func window(_ activities: [Activity], from start: Date, days: Int, firstLogDay: Date?, calendar: Calendar) -> TrendsWindow {
        var byDay: [Date: TrendsDay] = [:]
        var order: [Date] = []
        for offset in 0..<days {
            guard let date = calendar.date(byAdding: .day, value: offset, to: start) else { continue }
            var day = TrendsDay(date: date)
            day.isTracked = firstLogDay.map { date >= $0 } ?? false
            byDay[date] = day
            order.append(date)
        }
        let end = calendar.date(byAdding: .day, value: days, to: start) ?? start

        for activity in activities where activity.startTime >= start && activity.startTime < end {
            let key = calendar.startOfDay(for: activity.startTime)
            guard var day = byDay[key] else { continue }
            switch activity.type {
            case .formula, .momsMilk:
                day.milkML += activity.volumeML ?? 0
                day.feeds += 1
            case .breastfeeding, .solidFood:
                day.feeds += 1
            case .sleep:
                let seconds = activity.duration ?? 0
                if activity.isNightSleep { day.nightSeconds += seconds } else { day.napSeconds += seconds }
            case .diaper:
                day.diapers += 1
            case .note:
                break
            }
            byDay[key] = day
        }
        return TrendsWindow(days: order.compactMap { byDay[$0] })
    }

    // MARK: Signals

    enum MilkSteadiness { case steady, varies, unknown }

    var milkSteadiness: MilkSteadiness {
        guard let cv = TrendsMath.variation(current.milkDays) else { return .unknown }
        return cv <= 0.2 ? .steady : .varies
    }

    enum NightTrend {
        case up(TimeInterval)
        case down(TimeInterval)
        case flat
        case onlyCurrent(TimeInterval)
        case unknown
    }

    /// Raw change in night sleep per night versus the previous period.
    var nightDelta: TimeInterval? {
        guard current.hasSleep, previous.hasSleep,
              let now = current.nightSecondsPerDay, let before = previous.nightSecondsPerDay else { return nil }
        return now - before
    }

    var napDelta: TimeInterval? {
        guard current.hasSleep, previous.hasSleep,
              let now = current.napSecondsPerDay, let before = previous.napSecondsPerDay else { return nil }
        return now - before
    }

    var nightTrend: NightTrend {
        guard current.hasSleep, let now = current.nightSecondsPerDay else { return .unknown }
        guard let delta = nightDelta else { return .onlyCurrent(now) }
        if delta >= 15 * 60 { return .up(delta) }
        if delta <= -15 * 60 { return .down(-delta) }
        return .flat
    }

    var feedsDelta: Double? {
        guard let now = current.feedsPerDay, let before = previous.feedsPerDay, before > 0 || now > 0,
              !previous.tracked.isEmpty else { return nil }
        return now - before
    }

    var diapersDelta: Double? {
        guard let now = current.diapersPerDay, let before = previous.diapersPerDay, before > 0 || now > 0,
              !previous.tracked.isEmpty else { return nil }
        return now - before
    }

    // MARK: Sentences

    var verdict: String {
        var parts: [String] = []
        switch milkSteadiness {
        case .steady: parts.append(String(localized: "trends_milk_steady"))
        case .varies: parts.append(String(localized: "trends_milk_varies"))
        case .unknown: break
        }
        switch nightTrend {
        case .up: parts.append(String(localized: "trends_night_up \(babyName)"))
        case .down: parts.append(String(localized: "trends_night_down \(babyName)"))
        case .flat: parts.append(String(localized: "trends_night_flat \(babyName)"))
        case .onlyCurrent(let seconds): parts.append(String(localized: "trends_night_only \(babyName) \(ThreadFormat.durShort(seconds))"))
        case .unknown: break
        }
        if parts.isEmpty { return String(localized: "trends_verdict_thin \(babyName)") }
        return parts.joined(separator: " ")
    }

    var why: String {
        var parts: [String] = []
        let milk = current.milkDays
        if milk.count >= 2, let low = milk.min(), let high = milk.max() {
            parts.append(String(localized: "trends_why_milk_band \(ThreadFormat.volume(high - low))"))
        }
        if let now = current.milkPerDay, now > 0, let before = previous.milkPerDay, before > 0 {
            let pct = Int((abs(now - before) / before * 100).rounded())
            parts.append(String(localized: "trends_why_milk_vs_prev \(pct) \(period.days)"))
        }
        switch nightTrend {
        case .up(let seconds): parts.append(String(localized: "trends_why_night_up \(ThreadFormat.durShort(seconds))"))
        case .down(let seconds): parts.append(String(localized: "trends_why_night_down \(ThreadFormat.durShort(seconds))"))
        case .flat: parts.append(String(localized: "trends_why_night_flat"))
        case .onlyCurrent, .unknown: break
        }
        if let naps = napDelta, abs(naps) >= 10 * 60 {
            parts.append(naps < 0
                ? String(localized: "trends_why_naps_shorter \(ThreadFormat.durShort(-naps))")
                : String(localized: "trends_why_naps_longer \(ThreadFormat.durShort(naps))"))
        }
        if parts.isEmpty { return String(localized: "trends_why_thin \(babyName)") }
        return parts.joined(separator: " ")
    }

    var changes: [TrendsChange] {
        var rows: [TrendsChange] = []
        if let delta = nightDelta, abs(delta) >= 5 * 60 {
            rows.append(TrendsChange(
                id: "nights",
                delta: TrendsMath.signed(delta),
                what: String(localized: delta > 0 ? "trends_change_nights_longer" : "trends_change_nights_shorter"),
                isGain: delta > 0
            ))
        }
        if let delta = napDelta, abs(delta) >= 5 * 60 {
            rows.append(TrendsChange(
                id: "naps",
                delta: TrendsMath.signed(delta),
                what: String(localized: delta > 0 ? "trends_change_naps_longer" : "trends_change_naps_shorter"),
                isGain: delta > 0
            ))
        }
        if let change = weightChange, abs(change.deltaKg) >= 0.05 {
            let display = UnitConversion.displayWeight(abs(change.deltaKg))
            let since = change.since.formatted(.dateTime.day().month(.abbreviated))
            rows.append(TrendsChange(
                id: "weight",
                delta: (change.deltaKg < 0 ? "−" : "+") + String(format: "%.1f", display) + UnitConversion.weightUnit,
                what: String(localized: change.deltaKg < 0 ? "trends_change_weight_lost \(since)" : "trends_change_weight_gained \(since)"),
                isGain: change.deltaKg > 0
            ))
        } else if let delta = feedsDelta, abs(delta) >= 0.5 {
            rows.append(TrendsChange(
                id: "feeds",
                delta: (delta < 0 ? "−" : "+") + String(format: "%.1f", abs(delta)),
                what: String(localized: delta > 0 ? "trends_change_feeds_more" : "trends_change_feeds_fewer"),
                isGain: delta > 0
            ))
        } else if let delta = diapersDelta, abs(delta) >= 0.5 {
            rows.append(TrendsChange(
                id: "diapers",
                delta: (delta < 0 ? "−" : "+") + String(format: "%.1f", abs(delta)),
                what: String(localized: delta > 0 ? "trends_change_diapers_more" : "trends_change_diapers_fewer"),
                isGain: delta > 0
            ))
        }
        return Array(rows.prefix(3))
    }

    // MARK: Chart helpers

    var milkAverageLabel: String {
        guard let avg = current.milkPerDay, avg > 0 else { return "—" }
        return String(localized: "trends_avg \(ThreadFormat.volume(avg))")
    }

    var sleepAverageLabel: String {
        guard let hours = current.sleepHoursPerDay, hours > 0 else { return "—" }
        return String(localized: "trends_avg \(String(localized: "trends_hours \(String(format: "%.1f", hours))"))")
    }

    func barLabel(for index: Int) -> String {
        let day = current.days[index]
        if period == .thirtyDays {
            let fromEnd = current.days.count - 1 - index
            return fromEnd % 5 == 0 ? day.date.formatted(.dateTime.day()) : ""
        }
        return day.date.formatted(.dateTime.weekday(.abbreviated))
    }
}
