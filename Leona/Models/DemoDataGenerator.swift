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

        // Create baby: Leo, 8 months old, boy — born July 2025
        let baby = Baby(
            firstName: "Leo",
            lastName: "",
            dateOfBirth: cal.date(byAdding: .month, value: -8, to: now)!,
            gender: .boy
        )
        context.insert(baby)

        // Set as active baby
        AppSettings.shared.activeBabyID = baby.id.uuidString
        AppSettings.shared.hasCompletedOnboarding = true

        // ── Today's activities ──

        // Breastfeeding with laps — this morning
        let bf1 = Activity(type: .breastfeeding, startTime: todayAt(7, 15), endTime: todayAt(7, 35), baby: baby)
        bf1.breastSide = .left
        bf1.sessionSlot = .morning
        bf1.breastfeedingLaps = [
            BreastfeedingLap(side: .left, startTime: todayAt(7, 15), endTime: todayAt(7, 24)),
            BreastfeedingLap(side: .right, startTime: todayAt(7, 26), endTime: todayAt(7, 35))
        ]
        context.insert(bf1)

        // Formula - 150ml
        let f1 = Activity(type: .formula, startTime: todayAt(10, 0), baby: baby)
        f1.volumeML = 150
        f1.sessionSlot = .morning
        context.insert(f1)

        // Solid food - sweet potato + chicken
        let sf1 = Activity(type: .solidFood, startTime: todayAt(12, 0), baby: baby)
        sf1.foodName = "Patate douce & poulet"
        sf1.foodQuantity = 80
        sf1.foodUnit = .grams
        context.insert(sf1)

        // Nap
        let nap1 = Activity(type: .sleep, startTime: todayAt(9, 30), endTime: todayAt(11, 15), baby: baby)
        nap1.sessionSlot = .day
        context.insert(nap1)

        // Diapers
        let d1 = Activity(type: .diaper, startTime: todayAt(7, 0), baby: baby)
        d1.diaperType = .both
        context.insert(d1)

        let d2 = Activity(type: .diaper, startTime: todayAt(11, 20), baby: baby)
        d2.diaperType = .pee
        context.insert(d2)

        // Mom's Milk - night feed
        let mm1 = Activity(type: .momsMilk, startTime: todayAt(3, 30), baby: baby)
        mm1.volumeML = 100
        mm1.sessionSlot = .night
        context.insert(mm1)

        // Night sleep
        let nightSleep = Activity(type: .sleep, startTime: yesterdayAt(20, 45), endTime: todayAt(3, 20), baby: baby)
        nightSleep.sessionSlot = .night
        context.insert(nightSleep)

        // Note
        let n1 = Activity(type: .note, startTime: todayAt(8, 0), baby: baby)
        n1.noteText = "A fait coucou avec la main pour la première fois !"
        context.insert(n1)

        // ── Yesterday's activities ──
        let yesterdayFeedings: [(Int, Int, ActivityType)] = [
            (6, 45, .breastfeeding), (9, 30, .formula), (12, 0, .solidFood),
            (15, 0, .breastfeeding), (18, 0, .solidFood), (20, 15, .formula)
        ]
        for (hour, min, type) in yesterdayFeedings {
            let act = Activity(type: type, startTime: yesterdayAt(hour, min), baby: baby)
            if type == .formula { act.volumeML = Double(Int.random(in: 120...180)) }
            else if type == .breastfeeding { act.breastSide = Bool.random() ? .left : .right; act.endTime = yesterdayAt(hour, min + Int.random(in: 12...20)) }
            else if type == .solidFood { act.foodName = ["Compote pomme", "Purée courgette", "Banane écrasée"].randomElement()!; act.foodQuantity = Double(Int.random(in: 40...90)); act.foodUnit = .grams }
            context.insert(act)
        }

        for hour in [7, 10, 13, 16, 19] {
            let d = Activity(type: .diaper, startTime: yesterdayAt(hour, Int.random(in: 0...30)), baby: baby)
            d.diaperType = [DiaperType.pee, .pee, .poop, .both].randomElement()!
            context.insert(d)
        }

        let yNap = Activity(type: .sleep, startTime: yesterdayAt(13, 0), endTime: yesterdayAt(15, 10), baby: baby)
        yNap.sessionSlot = .day
        context.insert(yNap)

        // ── Past 2 weeks of activities ──
        for dayOffset in 2...14 {
            let dayDate = cal.date(byAdding: .day, value: -dayOffset, to: now)!

            // 5-7 feedings per day
            for _ in 0..<Int.random(in: 5...7) {
                let hour = Int.random(in: 5...21)
                let start = dateAt(dayDate, hour, Int.random(in: 0...59))
                let types: [ActivityType] = [.breastfeeding, .formula, .momsMilk, .solidFood]
                let act = Activity(type: types.randomElement()!, startTime: start, baby: baby)
                if act.type == .formula || act.type == .momsMilk {
                    act.volumeML = Double(Int.random(in: 80...180))
                } else if act.type == .breastfeeding {
                    act.breastSide = Bool.random() ? .left : .right
                    act.endTime = dateAt(dayDate, hour, Int.random(in: 10...55))
                } else {
                    act.foodName = ["Banane", "Avocat", "Patate douce", "Céréales riz", "Compote pomme", "Purée carotte", "Yaourt nature"].randomElement()!
                    act.foodQuantity = Double(Int.random(in: 30...100))
                    act.foodUnit = [FoodUnit.grams, .tablespoons].randomElement()!
                }
                context.insert(act)
            }

            // Night sleep + 1-2 naps
            let nightSl = Activity(type: .sleep, startTime: dateAt(dayDate, Int.random(in: 19...21), 0), endTime: dateAt(cal.date(byAdding: .day, value: 1, to: dayDate)!, Int.random(in: 4...6), Int.random(in: 0...59)), baby: baby)
            nightSl.sessionSlot = .night
            context.insert(nightSl)

            let morningNap = Activity(type: .sleep, startTime: dateAt(dayDate, Int.random(in: 9...10), 0), endTime: dateAt(dayDate, Int.random(in: 10...11), Int.random(in: 15...45)), baby: baby)
            morningNap.sessionSlot = .day
            context.insert(morningNap)

            if Bool.random() {
                let afternoonNap = Activity(type: .sleep, startTime: dateAt(dayDate, Int.random(in: 13...14), 0), endTime: dateAt(dayDate, Int.random(in: 14...16), Int.random(in: 0...30)), baby: baby)
                afternoonNap.sessionSlot = .day
                context.insert(afternoonNap)
            }

            // 4-7 diapers
            for _ in 0..<Int.random(in: 4...7) {
                let d = Activity(type: .diaper, startTime: dateAt(dayDate, Int.random(in: 6...22), Int.random(in: 0...59)), baby: baby)
                d.diaperType = [DiaperType.pee, .pee, .poop, .both].randomElement()!
                context.insert(d)
            }
        }

        // ── Growth records (birth to 8 months — monthly) ──
        let birthDate = baby.dateOfBirth
        let growthData: [(Int, Double, Double, Double)] = [
            // (days, weight kg, height cm, head cm)
            (0,   3.5,  50.0, 35.0),   // birth
            (5,   3.3,  50.0, 35.0),   // day 5 — physiological weight loss
            (14,  3.6,  51.0, 35.5),   // 2 weeks — regained birth weight
            (30,  4.4,  54.5, 37.5),   // 1 month
            (60,  5.5,  58.5, 39.5),   // 2 months
            (90,  6.4,  62.0, 41.0),   // 3 months
            (120, 7.0,  64.5, 42.5),   // 4 months
            (150, 7.5,  66.5, 43.5),   // 5 months
            (180, 7.9,  68.0, 44.5),   // 6 months
            (210, 8.4,  70.0, 45.5),   // 7 months
            (240, 8.8,  72.0, 46.0),   // 8 months
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

        // Vaccination at 2 months
        let vacc1 = HealthRecord(
            illnessType: .vaccination,
            startDate: cal.date(byAdding: .day, value: 60, to: birthDate)!,
            endDate: cal.date(byAdding: .day, value: 60, to: birthDate)!,
            notes: "Vaccins 2 mois (DTP, coqueluche, Hib, hépatite B, pneumocoque)",
            baby: baby
        )
        context.insert(vacc1)
        vacc1.temperatures = [
            TemperatureReading(temperature: 38.2, measuredAt: cal.date(byAdding: .day, value: 60, to: birthDate)!)
        ]
        vacc1.symptoms = [
            Symptom(description: "Pleurs après injection", severity: .mild),
            Symptom(description: "Rougeur au point d'injection", severity: .mild)
        ]

        // Vaccination at 4 months
        let vacc2 = HealthRecord(
            illnessType: .vaccination,
            startDate: cal.date(byAdding: .day, value: 120, to: birthDate)!,
            endDate: cal.date(byAdding: .day, value: 120, to: birthDate)!,
            notes: "Rappel vaccins 4 mois",
            baby: baby
        )
        context.insert(vacc2)

        // Cold at 5 months
        let cold = HealthRecord(
            illnessType: .cold,
            startDate: cal.date(byAdding: .day, value: 145, to: birthDate)!,
            endDate: cal.date(byAdding: .day, value: 152, to: birthDate)!,
            notes: "Rhume léger, nez qui coule pendant 1 semaine",
            baby: baby
        )
        context.insert(cold)
        cold.symptoms = [
            Symptom(description: "Nez qui coule", severity: .moderate),
            Symptom(description: "Éternuements", severity: .mild),
            Symptom(description: "Sommeil perturbé", severity: .mild)
        ]
        cold.temperatures = [
            TemperatureReading(temperature: 37.8, measuredAt: cal.date(byAdding: .day, value: 145, to: birthDate)!),
            TemperatureReading(temperature: 38.1, measuredAt: cal.date(byAdding: .day, value: 146, to: birthDate)!),
            TemperatureReading(temperature: 37.5, measuredAt: cal.date(byAdding: .day, value: 148, to: birthDate)!)
        ]
        cold.medications = [
            Medication(name: "Sérum physiologique", dosage: "Lavage nasal 6x/jour")
        ]

        // Teething — ongoing
        let teeth = HealthRecord(
            illnessType: .teething,
            startDate: cal.date(byAdding: .day, value: -10, to: now)!,
            notes: "Premières dents en cours, bave beaucoup, mâchouille tout",
            baby: baby
        )
        context.insert(teeth)
        teeth.symptoms = [
            Symptom(description: "Bave excessive", severity: .moderate),
            Symptom(description: "Gencives gonflées", severity: .moderate),
            Symptom(description: "Irritabilité", severity: .mild)
        ]
        teeth.temperatures = [
            TemperatureReading(temperature: 37.6, measuredAt: cal.date(byAdding: .day, value: -8, to: now)!)
        ]
        teeth.medications = [
            Medication(name: "Anneau de dentition réfrigéré", dosage: "À la demande"),
            Medication(name: "Camilia", dosage: "1 dose 3x/jour")
        ]

        // Stomach bug at 7 months
        let stomachBug = HealthRecord(
            illnessType: .stomachBug,
            startDate: cal.date(byAdding: .day, value: -25, to: now)!,
            endDate: cal.date(byAdding: .day, value: -22, to: now)!,
            notes: "Gastro-entérite légère, 3 jours",
            baby: baby
        )
        context.insert(stomachBug)
        stomachBug.symptoms = [
            Symptom(description: "Vomissements", severity: .moderate),
            Symptom(description: "Diarrhée", severity: .moderate),
            Symptom(description: "Perte d'appétit", severity: .mild)
        ]
        stomachBug.temperatures = [
            TemperatureReading(temperature: 38.5, measuredAt: cal.date(byAdding: .day, value: -25, to: now)!),
            TemperatureReading(temperature: 38.8, measuredAt: cal.date(byAdding: .day, value: -24, to: now)!),
            TemperatureReading(temperature: 37.4, measuredAt: cal.date(byAdding: .day, value: -23, to: now)!)
        ]
        stomachBug.medications = [
            Medication(name: "Solution de réhydratation", dosage: "50ml après chaque selle"),
            Medication(name: "Smecta", dosage: "1/2 sachet 2x/jour")
        ]

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
