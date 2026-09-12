import Foundation
import SwiftUI

// MARK: - Activity helpers for the thread

extension Activity {
    /// True when this entry was logged by this person: same iCloud user on any device, or this
    /// install before the iCloud identity was known (or predates author stamping on an unshared thread).
    var isMine: Bool {
        if let authorID {
            let settings = AppSettings.shared
            return authorID == settings.authorID || authorID == settings.cloudUserID
        }
        guard let baby, baby.isShared else { return true }
        // Legacy entries on a thread we joined belong to the owner.
        return baby.ownerName == nil
    }

    /// Name shown in the bubble meta line.
    var authorDisplayName: String {
        if isMine {
            let mine = AppSettings.shared.userDisplayName.trimmingCharacters(in: .whitespaces)
            return mine.isEmpty ? String(localized: "author_you") : mine
        }
        if let authorName, !authorName.isEmpty { return authorName }
        if let owner = baby?.ownerName, !owner.isEmpty { return owner }
        return String(localized: "partner")
    }

    var isFeed: Bool { type.category == .feeding }

    /// Sleep that starts in the evening or night counts as night sleep; the rest are naps.
    var isNightSleep: Bool {
        let hour = Calendar.current.component(.hour, from: startTime)
        return hour < 7 || hour >= 19
    }

    /// Seconds actually spent feeding in a breastfeeding session (laps only, breaks excluded).
    var breastfeedingSeconds: TimeInterval {
        let laps = breastfeedingLaps
        if laps.isEmpty { return duration ?? 0 }
        return laps.reduce(0) { $0 + ((($1.endTime ?? (isOngoing ? Date() : $1.startTime))).timeIntervalSince($1.startTime)) }
    }

    /// Stamp the entry with this person's identity (iCloud user when known, else this install). Call on every creation.
    func stampAuthor() {
        let settings = AppSettings.shared
        authorID = settings.effectiveAuthorID
        let name = settings.userDisplayName.trimmingCharacters(in: .whitespaces)
        authorName = name.isEmpty ? nil : name
    }
}

// MARK: - Formatting

enum ThreadFormat {
    static func clock(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }

    /// "1h05" / "45m"
    static func durShort(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds.rounded()))
        let h = total / 3600
        let m = (total % 3600) / 60
        return h > 0 ? String(format: "%dh%02d", h, m) : "\(m)m"
    }

    /// "1h 05m" / "45m" through the localized duration strings
    static func dur(_ seconds: TimeInterval) -> String {
        seconds.compactFormatted
    }

    /// "0:04:12" style live timer
    static func timer(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds))
        return String(format: "%d:%02d:%02d", total / 3600, (total % 3600) / 60, total % 60)
    }

    /// "4:12" style session timer
    static func mmss(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds))
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    static func volume(_ ml: Double) -> String {
        UnitConversion.formatVolume(ml)
    }

    static func dayDivider(for date: Date) -> String {
        let stamp = date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))
        if date.isToday { return String(localized: "thread_today_divider \(stamp)") }
        if date.isYesterday { return String(localized: "thread_yesterday_divider \(stamp)") }
        return stamp
    }

    /// Title line of a bubble, e.g. "Bottle · 180 ml formula".
    static func title(for activity: Activity) -> String {
        switch activity.type {
        case .formula:
            return String(localized: "thread_bottle_formula \(volume(activity.volumeML ?? 0))")
        case .momsMilk:
            return String(localized: "thread_bottle_milk \(volume(activity.volumeML ?? 0))")
        case .breastfeeding:
            let side = activity.breastSide ?? .left
            let minutes = max(1, Int((activity.breastfeedingSeconds / 60).rounded()))
            return String(localized: "thread_breastfed \(sideLabel(side)) \(minutes)")
        case .solidFood:
            let name = activity.foodName ?? ""
            let qty = activity.foodQuantity ?? 0
            let unit = activity.foodUnit?.symbol ?? ""
            let amount = String(format: "%.0f", qty) + " " + unit
            return name.isEmpty
                ? String(localized: "thread_solid_no_name \(amount)")
                : String(localized: "thread_solid \(name) \(amount)")
        case .diaper:
            return String(localized: "thread_diaper \(diaperLabel(activity.diaperType ?? .pee))")
        case .note:
            return activity.noteText ?? ""
        case .sleep:
            let end = activity.endTime ?? Date()
            return String(localized: "thread_slept \(clock(activity.startTime)) \(clock(end))")
        }
    }

    static func subtitle(for activity: Activity) -> String? {
        switch activity.type {
        case .sleep:
            return dur(activity.duration ?? 0)
        case .formula, .momsMilk, .solidFood, .diaper, .breastfeeding:
            if let note = activity.noteText, !note.isEmpty { return note }
            return nil
        case .note:
            return nil
        }
    }

    static func meta(for activity: Activity) -> String {
        "\(activity.authorDisplayName) · \(clock(activity.sortTime))"
    }

    static func color(for activity: Activity) -> Color {
        switch activity.type {
        case .sleep: return .lilac
        case .diaper: return .moss
        case .note: return .noteGrey
        default: return .vermilion
        }
    }

    static func kindLabel(for activity: Activity) -> String {
        switch activity.type {
        case .sleep: return String(localized: "record_kind_sleep")
        case .diaper: return String(localized: "record_kind_diaper")
        case .note: return String(localized: "record_kind_note")
        default: return String(localized: "record_kind_feed")
        }
    }

    static func sideLabel(_ side: BreastSide) -> String {
        switch side {
        case .left: return String(localized: "side_left_lower")
        case .right: return String(localized: "side_right_lower")
        case .both: return String(localized: "side_both_lower")
        }
    }

    static func diaperLabel(_ type: DiaperType) -> String {
        type.displayName.lowercased()
    }
}

// MARK: - Thread rows

struct ThreadRow: Identifiable {
    enum Kind {
        case divider(String)
        case unread(String)
        case entry(Activity)
        case runningSleep(Activity)
        case runningBreast(Activity)
        case leona(LeonaRemark)
    }

    let id: String
    let kind: Kind
}

// MARK: - Leona's remarks (what she said, kept in the flow of the conversation)

/// A suggestion the parent answered, kept as a message in the thread. Local to this
/// phone and pruned after a day: never an Activity, never synced, never exported.
struct LeonaRemark: Codable, Identifiable, Equatable {
    enum Outcome: String, Codable {
        case snoozed
        case logged
    }

    var id: UUID = UUID()
    /// One remark per occasion: answering the same suggestion again updates it.
    let occasion: String
    var date: Date
    let line: String
    var outcome: Outcome
    var until: Date?

    var metaText: String {
        switch outcome {
        case .snoozed:
            if let until { return String(localized: "leona_remark_snoozed_meta \(ThreadFormat.clock(until))") }
            return String(localized: "leona_snooze_not_yet")
        case .logged:
            return String(localized: "leona_remark_logged_meta")
        }
    }
}

enum LeonaRemarkStore {
    private static let keep: TimeInterval = 24 * 60 * 60

    private static func key(_ babyID: UUID) -> String { "leonaRemarks-\(babyID.uuidString)" }

    static func load(for babyID: UUID, now: Date = Date()) -> [LeonaRemark] {
        guard let data = UserDefaults.standard.data(forKey: key(babyID)),
              let remarks = try? JSONDecoder().decode([LeonaRemark].self, from: data) else { return [] }
        return remarks.filter { now.timeIntervalSince($0.date) < keep }
    }

    static func save(_ remarks: [LeonaRemark], for babyID: UUID) {
        if let data = try? JSONEncoder().encode(remarks) {
            UserDefaults.standard.set(data, forKey: key(babyID))
        }
    }
}

enum ThreadBuilder {
    private enum Item {
        case activity(Activity)
        case remark(LeonaRemark)

        var date: Date {
            switch self {
            case .activity(let a): return a.sortTime
            case .remark(let r): return r.date
            }
        }
    }

    /// Builds the chronological thread: day dividers, an unread marker for the partner's
    /// entries since the thread was last seen, one row per entry with Leona's remarks
    /// in between, running sessions last.
    static func rows(activities: [Activity], lastSeen: Date?, remarks: [LeonaRemark] = []) -> [ThreadRow] {
        let finished = activities.filter { !$0.isOngoing }
        let items = (finished.map(Item.activity) + remarks.map(Item.remark))
            .sorted { $0.date < $1.date }
        var rows: [ThreadRow] = []
        var currentDay: Date?
        var markerDone = false
        let unreadCount = lastSeen.map { seen in
            finished.filter { !$0.isMine && $0.createdAt > seen }.count
        } ?? 0

        for item in items {
            let day = item.date.startOfDay
            if currentDay != day {
                currentDay = day
                rows.append(ThreadRow(id: "day-\(day.timeIntervalSince1970)", kind: .divider(ThreadFormat.dayDivider(for: day))))
            }
            switch item {
            case .activity(let activity):
                if !markerDone, unreadCount > 0, let seen = lastSeen, !activity.isMine, activity.createdAt > seen {
                    let text = String(localized: "thread_unread \(unreadCount) \(activity.authorDisplayName)")
                    rows.append(ThreadRow(id: "unread", kind: .unread(text)))
                    markerDone = true
                }
                rows.append(ThreadRow(id: activity.id.uuidString, kind: .entry(activity)))
            case .remark(let remark):
                rows.append(ThreadRow(id: "leona-\(remark.id.uuidString)", kind: .leona(remark)))
            }
        }

        if rows.isEmpty {
            rows.append(ThreadRow(id: "day-today", kind: .divider(ThreadFormat.dayDivider(for: Date()))))
        }

        if let sleep = activities.first(where: { $0.type == .sleep && $0.isOngoing }) {
            rows.append(ThreadRow(id: "running-sleep", kind: .runningSleep(sleep)))
        }
        if let breast = activities.first(where: { $0.type == .breastfeeding && $0.isOngoing }) {
            rows.append(ThreadRow(id: "running-breast", kind: .runningBreast(breast)))
        }
        return rows
    }
}

// MARK: - Totals strip

struct ThreadTotals {
    let feeds: Int
    let slept: TimeInterval
    let diapers: Int
    let lastFeed: Date?
    let forecast: MealForecast?
    let predictedVolumeML: Double

    var nextFeed: Date? { forecast?.nextIdealMealTime }

    static func compute(activities: [Activity], baby: Baby, now: Date = Date()) -> ThreadTotals {
        let today = activities.filter { $0.sortTime.isToday || ($0.isOngoing && $0.startTime.isToday) }
        let feeds = today.filter { $0.isFeed && !$0.isOngoing }.count
        var slept = today.filter { $0.type == .sleep && !$0.isOngoing }.compactMap(\.duration).reduce(0, +)
        if let ongoing = activities.first(where: { $0.type == .sleep && $0.isOngoing }) {
            slept += now.timeIntervalSince(ongoing.startTime)
        }
        let diapers = today.filter { $0.type == .diaper }.count
        let lastFeed = activities.filter { $0.isFeed && !$0.isOngoing }.map(\.startTime).max()
        let forecast = MealForecastEngine.forecast(from: activities, babyAgeInDays: baby.ageInDays)
        return ThreadTotals(
            feeds: feeds,
            slept: slept,
            diapers: diapers,
            lastFeed: lastFeed,
            forecast: forecast,
            predictedVolumeML: predictedVolume(activities: activities, forecast: forecast, baby: baby)
        )
    }

    /// Average of the last three bottles, rounded to 10 ml and clamped to the tray range;
    /// falls back to the forecast, then to an age-based estimate.
    static func predictedVolume(activities: [Activity], forecast: MealForecast?, baby: Baby) -> Double {
        let bottles = activities
            .filter { ($0.type == .formula || $0.type == .momsMilk) && ($0.volumeML ?? 0) > 0 }
            .sorted { $0.startTime > $1.startTime }
            .prefix(3)
        if !bottles.isEmpty {
            let avg = bottles.compactMap(\.volumeML).reduce(0, +) / Double(bottles.count)
            return min(300, max(30, (avg / 10).rounded() * 10))
        }
        if let forecast { return min(300, max(30, (forecast.estimatedVolumeML / 10).rounded() * 10)) }
        switch baby.ageInDays {
        case 0...7: return 40
        case 8...30: return 80
        case 31...90: return 120
        case 91...180: return 150
        default: return 180
        }
    }

    /// "next 14:05" / "45m overdue" / "asleep now"
    func nextLabel(asleep: Bool, now: Date = Date()) -> String {
        if asleep { return String(localized: "thread_asleep_now") }
        guard let next = nextFeed else { return "" }
        let delta = next.timeIntervalSince(now)
        if delta >= 0 { return String(localized: "thread_next \(ThreadFormat.clock(next))") }
        return String(localized: "thread_overdue \(ThreadFormat.dur(-delta))")
    }
}

// MARK: - Leona's suggestion

struct LeonaAdvice {
    enum Action { case logBottle, openSleep, openBottleTray, none }
    enum Secondary { case snooze, fixSleepStart, none }

    let line: String
    let cta: String
    let secondaryTitle: String
    let action: Action
    let secondary: Secondary
    /// Identifies the situation the advice is about, so a repeated answer updates one remark.
    let occasion: String
}

enum LeonaAdvisor {
    /// How far ahead a predicted feed is worth a card. Beyond that the thread stays quiet.
    static let dueWindow: TimeInterval = 30 * 60

    /// The card to show at the bottom of the thread, or nil when there is nothing worth saying:
    /// suggestions off, snoozed, or the next feed still far away.
    static func advice(
        totals: ThreadTotals,
        ongoingSleep: Activity?,
        snoozedUntil: Date?,
        enabled: Bool,
        babyName: String,
        now: Date = Date()
    ) -> LeonaAdvice? {
        guard enabled else { return nil }
        let vol = ThreadFormat.volume(totals.predictedVolumeML)
        if let sleep = ongoingSleep {
            return LeonaAdvice(
                line: String(localized: "leona_asleep \(babyName) \(ThreadFormat.clock(sleep.startTime))"),
                cta: String(localized: "leona_cta_open_session"),
                secondaryTitle: String(localized: "leona_snooze_fix_start"),
                action: .openSleep, secondary: .fixSleepStart,
                occasion: "asleep-\(sleep.id.uuidString)"
            )
        }
        guard let next = totals.nextFeed else {
            return LeonaAdvice(
                line: String(localized: "leona_no_data \(babyName)"),
                cta: String(localized: "leona_cta_log_bottle"),
                secondaryTitle: String(localized: "leona_snooze_not_now"),
                action: .openBottleTray, secondary: .snooze,
                occasion: "nodata-\(Int(now.startOfDay.timeIntervalSince1970))"
            )
        }
        if let until = snoozedUntil, until > now {
            return nil
        }
        let delta = next.timeIntervalSince(now)
        var window = dueWindow
        #if DEBUG
        // Screenshot runs capture at an arbitrary clock time; keep the card visible.
        if DemoDataGenerator.isDemoMode { window = .infinity }
        #endif
        if delta > window {
            return nil
        }
        let line = delta >= 0
            ? String(localized: "leona_due \(babyName) \(ThreadFormat.clock(next)) \(vol)")
            : String(localized: "leona_overdue \(babyName) \(ThreadFormat.dur(-delta)) \(vol)")
        return LeonaAdvice(
            line: line,
            cta: String(localized: "leona_cta_log \(vol)"),
            secondaryTitle: String(localized: "leona_snooze_not_yet"),
            action: .logBottle, secondary: .snooze,
            occasion: "feed-\(Int(next.timeIntervalSince1970 / 60))"
        )
    }
}
