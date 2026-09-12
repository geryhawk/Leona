import Foundation
import SwiftData
import SwiftUI

/// Every write to the thread goes through here so author stamping, saving,
/// sync nudges, reminders and haptics stay consistent across screens.
@MainActor
enum ActivityLogger {

    enum BottleKind { case formula, expressedMilk }

    // MARK: - One-shot entries

    @discardableResult
    static func logBottle(_ ml: Double, kind: BottleKind, at time: Date, note: String? = nil, baby: Baby, context: ModelContext) -> Activity {
        let activity = Activity(type: kind == .formula ? .formula : .momsMilk, startTime: time, baby: baby)
        activity.volumeML = ml
        activity.noteText = note?.isEmpty == false ? note : nil
        activity.sessionSlot = SessionSlot.current(for: time)
        insert(activity, context: context)
        scheduleFeedingReminder(baby: baby, lastFeedingTime: time)
        return activity
    }

    @discardableResult
    static func logBreastfeedManual(minutes: Int, side: BreastSide, endingAt end: Date, baby: Baby, context: ModelContext) -> Activity {
        let start = end.addingTimeInterval(-Double(minutes) * 60)
        let activity = Activity(type: .breastfeeding, startTime: start, endTime: end, baby: baby)
        activity.breastSide = side
        activity.sessionSlot = SessionSlot.current(for: start)
        activity.breastfeedingLaps = [BreastfeedingLap(side: side, startTime: start, endTime: end)]
        insert(activity, context: context)
        scheduleFeedingReminder(baby: baby, lastFeedingTime: end)
        return activity
    }

    @discardableResult
    static func logSolid(name: String, quantity: Double, unit: FoodUnit, at time: Date, baby: Baby, context: ModelContext) -> Activity {
        let activity = Activity(type: .solidFood, startTime: time, baby: baby)
        activity.foodName = name.isEmpty ? nil : name
        activity.foodQuantity = quantity
        activity.foodUnit = unit
        insert(activity, context: context)
        return activity
    }

    @discardableResult
    static func logDiaper(_ type: DiaperType, at time: Date, baby: Baby, context: ModelContext) -> Activity {
        let activity = Activity(type: .diaper, startTime: time, baby: baby)
        activity.diaperType = type
        insert(activity, context: context)
        return activity
    }

    @discardableResult
    static func logNote(_ text: String, at time: Date = Date(), baby: Baby, context: ModelContext) -> Activity {
        let activity = Activity(type: .note, startTime: time, baby: baby)
        activity.noteText = text
        insert(activity, context: context)
        return activity
    }

    @discardableResult
    static func logPastSleep(from start: Date, to end: Date, baby: Baby, context: ModelContext) -> Activity {
        let activity = Activity(type: .sleep, startTime: start, endTime: end, baby: baby)
        activity.sessionSlot = SessionSlot.current(for: start)
        insert(activity, context: context)
        return activity
    }

    // MARK: - Sleep session

    @discardableResult
    static func startSleep(baby: Baby, context: ModelContext) -> Activity {
        let activity = Activity(type: .sleep, isOngoing: true, baby: baby)
        activity.sessionSlot = SessionSlot.current()
        insert(activity, context: context)
        Task {
            await NotificationManager.shared.scheduleSleepCheckReminder(babyName: baby.displayName, sleepStartTime: Date())
        }
        return activity
    }

    static func endSleep(_ activity: Activity, context: ModelContext) {
        activity.endTime = Date()
        activity.isOngoing = false
        activity.updatedAt = Date()
        save(context)
        NotificationCenter.default.post(name: .shouldPushLocalChanges, object: nil)
        NotificationManager.shared.cancelNotification(identifier: "sleep-check")
        HapticManager.success()
    }

    static func updateStart(_ activity: Activity, to date: Date, context: ModelContext) {
        activity.startTime = date
        if let end = activity.endTime, end < date { activity.endTime = date }
        activity.updatedAt = Date()
        save(context)
    }

    // MARK: - Breastfeeding session

    @discardableResult
    static func startBreastfeeding(side: BreastSide, baby: Baby, context: ModelContext) -> Activity {
        let now = Date()
        let activity = Activity(type: .breastfeeding, startTime: now, isOngoing: true, baby: baby)
        activity.breastSide = side
        activity.sessionSlot = SessionSlot.current(for: now)
        activity.breastfeedingLaps = [BreastfeedingLap(side: side, startTime: now)]
        insert(activity, context: context)
        return activity
    }

    /// Closes the running lap (if any) and opens a new one on `side`.
    static func switchBreastSide(_ activity: Activity, to side: BreastSide, context: ModelContext) {
        var laps = activity.breastfeedingLaps
        let now = Date()
        if let last = laps.indices.last, laps[last].endTime == nil {
            if laps[last].side == side { return }
            laps[last].endTime = now
        }
        laps.append(BreastfeedingLap(side: side, startTime: now))
        activity.breastfeedingLaps = laps
        activity.breastSide = Set(laps.map(\.side)).count > 1 ? .both : side
        activity.updatedAt = now
        save(context)
        HapticManager.impact(.medium)
    }

    static func pauseBreastfeeding(_ activity: Activity, context: ModelContext) {
        var laps = activity.breastfeedingLaps
        if let last = laps.indices.last, laps[last].endTime == nil {
            laps[last].endTime = Date()
            activity.breastfeedingLaps = laps
            activity.updatedAt = Date()
            save(context)
        }
        HapticManager.impact(.light)
    }

    static func resumeBreastfeeding(_ activity: Activity, side: BreastSide, context: ModelContext) {
        var laps = activity.breastfeedingLaps
        laps.append(BreastfeedingLap(side: side, startTime: Date()))
        activity.breastfeedingLaps = laps
        activity.updatedAt = Date()
        save(context)
        HapticManager.impact(.medium)
    }

    static func finishBreastfeeding(_ activity: Activity, baby: Baby, context: ModelContext) {
        var laps = activity.breastfeedingLaps
        let now = Date()
        if let last = laps.indices.last, laps[last].endTime == nil { laps[last].endTime = now }
        activity.breastfeedingLaps = laps
        activity.endTime = now
        activity.isOngoing = false
        let sides = Set(laps.map(\.side))
        activity.breastSide = sides.count == 1 ? sides.first : .both
        activity.updatedAt = now
        save(context)
        NotificationCenter.default.post(name: .shouldPushLocalChanges, object: nil)
        scheduleFeedingReminder(baby: baby, lastFeedingTime: now)
        HapticManager.success()
    }

    // MARK: - Delete

    static func delete(_ activity: Activity, context: ModelContext) {
        let id = activity.id
        let baby = activity.baby
        context.delete(activity)
        save(context)
        if let baby, baby.isShared {
            Task {
                try? await SharingManager.shared.deleteRecord(recordID: id, recordType: Activity.ckRecordType, for: baby)
            }
        }
        HapticManager.impact(.light)
    }

    static func delete(_ record: GrowthRecord, context: ModelContext) {
        let id = record.id
        let baby = record.baby
        context.delete(record)
        save(context)
        if let baby, baby.isShared {
            Task { try? await SharingManager.shared.deleteRecord(recordID: id, recordType: GrowthRecord.ckRecordType, for: baby) }
        }
    }

    static func delete(_ record: HealthRecord, context: ModelContext) {
        let id = record.id
        let baby = record.baby
        context.delete(record)
        save(context)
        if let baby, baby.isShared {
            Task { try? await SharingManager.shared.deleteRecord(recordID: id, recordType: HealthRecord.ckRecordType, for: baby) }
        }
    }

    // MARK: - Plumbing

    private static func insert(_ activity: Activity, context: ModelContext) {
        activity.stampAuthor()
        context.insert(activity)
        save(context)
        HapticManager.success()
    }

    static func save(_ context: ModelContext) {
        try? context.save()
    }

    private static func scheduleFeedingReminder(baby: Baby, lastFeedingTime: Date) {
        let settings = AppSettings.shared
        guard settings.enableFeedingReminders else { return }
        Task {
            await NotificationManager.shared.scheduleFeedingReminder(
                babyName: baby.displayName,
                lastFeedingTime: lastFeedingTime,
                intervalMinutes: settings.feedingReminderInterval / 60
            )
        }
    }
}
