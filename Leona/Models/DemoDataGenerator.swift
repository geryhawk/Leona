import Foundation
import SwiftData

/// Generates rich demo data for App Store screenshots.
/// Activated by launching with `-demo` argument.
struct DemoDataGenerator {

    static var isDemoMode: Bool {
        CommandLine.arguments.contains("-demo")
    }

    /// Returns the tab name to select, if `-tab <name>` was passed.
    static var requestedTab: String? {
        guard let idx = CommandLine.arguments.firstIndex(of: "-tab"),
              idx + 1 < CommandLine.arguments.count else { return nil }
        return CommandLine.arguments[idx + 1]
    }

    /// When `-onboarding` is passed, show the onboarding screen instead of main app
    static var showOnboarding: Bool {
        CommandLine.arguments.contains("-onboarding")
    }

    @MainActor
    static func populate(context: ModelContext) {
        // Note: @MainActor is needed for AppSettings access
        // Delete all existing data first
        try? context.delete(model: Activity.self)
        try? context.delete(model: GrowthRecord.self)
        try? context.delete(model: HealthRecord.self)
        try? context.delete(model: Baby.self)
        try? context.save()

        // If onboarding mode, just reset and show onboarding
        if showOnboarding {
            AppSettings.shared.hasCompletedOnboarding = false
            AppSettings.shared.activeBabyID = nil
            return
        }

        let cal = Calendar.current
        let now = Date()

        // Create baby: Emma, 3 months old, girl
        let baby = Baby(
            firstName: "Emma",
            lastName: "Johnson",
            dateOfBirth: cal.date(byAdding: .month, value: -3, to: now)!,
            gender: .girl
        )
        context.insert(baby)

        // Set as active baby
        AppSettings.shared.activeBabyID = baby.id.uuidString
        AppSettings.shared.hasCompletedOnboarding = true

        // ── Today's activities (rich & varied) ──

        // Breastfeeding - 15 min, left breast, this morning
        let bf1 = Activity(type: .breastfeeding, startTime: todayAt(10, 30), endTime: todayAt(10, 45), baby: baby)
        bf1.breastSide = .left
        bf1.sessionSlot = .morning
        context.insert(bf1)

        // Formula - 120ml, 9:15 AM
        let f1 = Activity(type: .formula, startTime: todayAt(9, 15), baby: baby)
        f1.volumeML = 120
        f1.sessionSlot = .morning
        context.insert(f1)

        // Sleep - 2h 10m nap, ended at 9:00
        let s1 = Activity(type: .sleep, startTime: todayAt(6, 50), endTime: todayAt(9, 0), baby: baby)
        s1.sessionSlot = .morning
        context.insert(s1)

        // Diaper - pee + poop, 6:45
        let d1 = Activity(type: .diaper, startTime: todayAt(6, 45), baby: baby)
        d1.diaperType = .both
        context.insert(d1)

        // Mom's Milk - 90ml, 5:30
        let mm1 = Activity(type: .momsMilk, startTime: todayAt(5, 30), baby: baby)
        mm1.volumeML = 90
        mm1.sessionSlot = .night
        context.insert(mm1)

        // Solid food - banana, 45g, 4:00
        let sf1 = Activity(type: .solidFood, startTime: todayAt(8, 0), baby: baby)
        sf1.foodName = "Banana"
        sf1.foodQuantity = 45
        sf1.foodUnit = .grams
        context.insert(sf1)

        // Note
        let n1 = Activity(type: .note, startTime: todayAt(7, 30), baby: baby)
        n1.noteText = "First smile today! \u{2764}\u{FE0F}"
        context.insert(n1)

        // Night sleep (last night) - ongoing from 9:26 PM to 5:00 AM
        let nightSleep = Activity(type: .sleep, startTime: yesterdayAt(21, 26), endTime: todayAt(5, 0), baby: baby)
        nightSleep.sessionSlot = .night
        context.insert(nightSleep)

        // Breastfeeding - right, 12 min, 2:30 AM
        let bf2 = Activity(type: .breastfeeding, startTime: todayAt(2, 30), endTime: todayAt(2, 42), baby: baby)
        bf2.breastSide = .right
        bf2.sessionSlot = .night
        context.insert(bf2)

        // ── Yesterday's activities ──
        for hour in [7, 10, 13, 16, 19, 22] {
            let bf = Activity(type: .breastfeeding, startTime: yesterdayAt(hour, 0), endTime: yesterdayAt(hour, Int.random(in: 12...20)), baby: baby)
            bf.breastSide = hour % 2 == 0 ? .left : .right
            context.insert(bf)
        }
        for hour in [8, 14, 20] {
            let f = Activity(type: .formula, startTime: yesterdayAt(hour, 15), baby: baby)
            f.volumeML = Double(Int.random(in: 80...150))
            context.insert(f)
        }
        for hour in [6, 9, 12, 15, 18, 21] {
            let d = Activity(type: .diaper, startTime: yesterdayAt(hour, Int.random(in: 0...45)), baby: baby)
            d.diaperType = [DiaperType.pee, .poop, .both].randomElement()!
            context.insert(d)
        }

        // ── Past week of activities (for stats) ──
        for dayOffset in 2...7 {
            let dayDate = cal.date(byAdding: .day, value: -dayOffset, to: now)!

            // 4-6 feedings per day
            for _ in 0..<Int.random(in: 4...6) {
                let hour = Int.random(in: 5...22)
                let start = dateAt(dayDate, hour, Int.random(in: 0...59))
                let act = Activity(type: [.breastfeeding, .formula, .momsMilk].randomElement()!, startTime: start, endTime: dateAt(dayDate, hour, Int.random(in: 10...55)), baby: baby)
                if act.type == .formula || act.type == .momsMilk {
                    act.volumeML = Double(Int.random(in: 60...160))
                } else {
                    act.breastSide = Bool.random() ? .left : .right
                }
                context.insert(act)
            }

            // 1-2 solid foods
            for _ in 0..<Int.random(in: 1...2) {
                let sf = Activity(type: .solidFood, startTime: dateAt(dayDate, Int.random(in: 8...18), 0), baby: baby)
                sf.foodName = ["Banana", "Avocado", "Sweet potato", "Rice cereal", "Apple puree"].randomElement()!
                sf.foodQuantity = Double(Int.random(in: 20...60))
                sf.foodUnit = .grams
                context.insert(sf)
            }

            // 2-3 sleep sessions
            let nightSl = Activity(type: .sleep, startTime: dateAt(dayDate, 21, 0), endTime: dateAt(cal.date(byAdding: .day, value: 1, to: dayDate)!, 5, Int.random(in: 0...59)), baby: baby)
            nightSl.sessionSlot = .night
            context.insert(nightSl)

            let napSl = Activity(type: .sleep, startTime: dateAt(dayDate, Int.random(in: 12...14), 0), endTime: dateAt(dayDate, Int.random(in: 14...16), 30), baby: baby)
            napSl.sessionSlot = .day
            context.insert(napSl)

            // 4-6 diapers
            for _ in 0..<Int.random(in: 4...6) {
                let d = Activity(type: .diaper, startTime: dateAt(dayDate, Int.random(in: 6...22), Int.random(in: 0...59)), baby: baby)
                d.diaperType = [DiaperType.pee, .poop, .both].randomElement()!
                context.insert(d)
            }
        }

        // ── Growth records (at birth, 1m, 2m, 3m) ──
        let birthDate = baby.dateOfBirth
        let growthData: [(Int, Double, Double, Double)] = [
            (0,  3.2, 49.5, 34.0),  // birth
            (30, 4.1, 54.0, 37.0),  // 1 month
            (60, 5.2, 58.0, 39.5),  // 2 months
            (90, 6.2, 64.0, 42.0),  // 3 months
        ]
        for (daysAfter, weight, height, head) in growthData {
            let gr = GrowthRecord(
                date: cal.date(byAdding: .day, value: daysAfter, to: birthDate)!,
                weightKg: weight,
                heightCm: height,
                headCircumferenceCm: head,
                baby: baby
            )
            context.insert(gr)
        }

        // ── Health records ──
        let vacc = HealthRecord(
            illnessType: .vaccination,
            startDate: cal.date(byAdding: .day, value: -14, to: now)!,
            endDate: cal.date(byAdding: .day, value: -14, to: now)!,
            notes: "2-month vaccines (DTaP, IPV, Hib, PCV13, Rotavirus)",
            baby: baby
        )
        context.insert(vacc)

        let cold = HealthRecord(
            illnessType: .cold,
            startDate: cal.date(byAdding: .day, value: -7, to: now)!,
            endDate: cal.date(byAdding: .day, value: -3, to: now)!,
            notes: "Mild runny nose, resolved on its own",
            baby: baby
        )
        context.insert(cold)

        let teeth = HealthRecord(
            illnessType: .teething,
            startDate: cal.date(byAdding: .day, value: -2, to: now)!,
            notes: "Drooling more than usual, slight gum swelling",
            baby: baby
        )
        context.insert(teeth)

        try? context.save()
    }

    // MARK: - Date helpers

    private static func todayAt(_ hour: Int, _ minute: Int) -> Date {
        Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: Date())!
    }

    private static func yesterdayAt(_ hour: Int, _ minute: Int) -> Date {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        return Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: yesterday)!
    }

    private static func dateAt(_ day: Date, _ hour: Int, _ minute: Int) -> Date {
        Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: day)!
    }
}
