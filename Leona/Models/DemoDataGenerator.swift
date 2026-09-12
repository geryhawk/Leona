import Foundation
import SwiftData
import SwiftUI
import UIKit

/// Generates deterministic mock data for App Store screenshots.
/// Activated by launching with `-demo`.
struct DemoDataGenerator {

    enum DemoScreen: String {
        case onboarding
        case dashboard
        case sleep
        case forecast
        case stats
        case growth
        case health
        case sharing
        case settings
    }

    static var isDemoMode: Bool {
        CommandLine.arguments.contains("-demo")
    }

    static var requestedTab: String? {
        argumentValue(after: "-tab")
    }

    static var requestedScreen: DemoScreen? {
        guard let value = argumentValue(after: "-screen")?.lowercased() else { return nil }
        return DemoScreen(rawValue: value)
    }

    static var requestedVariant: String? {
        argumentValue(after: "-variant")?.lowercased()
    }

    static var requestedPage: Int {
        Int(argumentValue(after: "-page") ?? "") ?? 0
    }

    static var showOnboarding: Bool {
        CommandLine.arguments.contains("-onboarding") || requestedScreen == .onboarding
    }

    @MainActor
    static func populate(context: ModelContext) {
        resetAllData(in: context)
        configureDemoSettings()

        if showOnboarding {
            AppSettings.shared.hasCompletedOnboarding = false
            AppSettings.shared.activeBabyID = nil
            return
        }

        let calendar = Calendar.current
        let now = Date()

        let baby = Baby(
            firstName: "Alma",
            lastName: "",
            dateOfBirth: calendar.date(byAdding: .day, value: -6, to: calendar.date(byAdding: .month, value: -10, to: now)!)!,
            gender: .girl,
            bloodType: "O+"
        )
        baby.profileImageData = makeProfileImageData(initial: "A")
        context.insert(baby)

        AppSettings.shared.activeBabyID = baby.id.uuidString
        AppSettings.shared.hasCompletedOnboarding = true

        insertTodayActivities(for: baby, in: context)
        insertHistoricalActivities(for: baby, in: context)
        insertGrowthRecords(for: baby, in: context)
        insertHealthRecords(for: baby, in: context)

        if requestedScreen == .sleep {
            insertOngoingSleep(for: baby, in: context)
        }

        try? context.save()
    }

    private static func argumentValue(after flag: String) -> String? {
        guard let idx = CommandLine.arguments.firstIndex(of: flag),
              idx + 1 < CommandLine.arguments.count else { return nil }
        return CommandLine.arguments[idx + 1]
    }

    @MainActor
    private static func resetAllData(in context: ModelContext) {
        try? context.delete(model: Activity.self)
        try? context.delete(model: GrowthRecord.self)
        try? context.delete(model: HealthRecord.self)
        try? context.delete(model: Baby.self)
        try? context.save()
    }

    @MainActor
    private static func configureDemoSettings() {
        let settings = AppSettings.shared
        settings.showSleepTracking = true
        settings.showFeedingTracking = true
        settings.showDiaperTracking = true
        settings.showBreastfeeding = true
        settings.showBreastfeedingNotifications = true
        settings.showOngoingStatus = true
        settings.showProfile = true
        settings.showGrowth = true
        settings.showHealth = true
        settings.showStats = true
        settings.showDataExport = true
        settings.enableFeedingReminders = true
        settings.feedingReminderInterval = 3 * 60 * 60
        settings.useCelsius = true
        settings.useMetric = true
        settings.colorScheme = .light
        settings.accentColor = .corail
        settings.iCloudSyncEnabled = requestedScreen == .sharing || requestedScreen == .settings
    }

    @MainActor
    private static func insertTodayActivities(for baby: Baby, in context: ModelContext) {
        let nightSleep = Activity(
            type: .sleep,
            startTime: yesterdayAt(20, 52),
            endTime: todayAt(6, 24),
            baby: baby
        )
        nightSleep.sessionSlot = .night
        context.insert(nightSleep)

        let diaper1 = Activity(type: .diaper, startTime: todayAt(6, 28), baby: baby)
        diaper1.diaperType = .both
        context.insert(diaper1)

        let breastfeeding = Activity(
            type: .breastfeeding,
            startTime: todayAt(6, 42),
            endTime: todayAt(7, 2),
            baby: baby
        )
        breastfeeding.breastSide = .both
        breastfeeding.sessionSlot = .morning
        breastfeeding.breastfeedingLaps = [
            BreastfeedingLap(side: .left, startTime: todayAt(6, 42), endTime: todayAt(6, 51)),
            BreastfeedingLap(side: .right, startTime: todayAt(6, 53), endTime: todayAt(7, 2))
        ]
        context.insert(breastfeeding)

        let breakfast = Activity(type: .solidFood, startTime: todayAt(7, 38), baby: baby)
        breakfast.foodName = "Porridge poire & cannelle"
        breakfast.foodQuantity = 115
        breakfast.foodUnit = .grams
        context.insert(breakfast)

        let diaper2 = Activity(type: .diaper, startTime: todayAt(8, 5), baby: baby)
        diaper2.diaperType = .pee
        context.insert(diaper2)

        let formula = Activity(type: .formula, startTime: todayAt(9, 44), baby: baby)
        formula.volumeML = 180
        formula.sessionSlot = .morning
        context.insert(formula)

        let morningNap = Activity(
            type: .sleep,
            startTime: todayAt(10, 8),
            endTime: todayAt(11, 46),
            baby: baby
        )
        morningNap.sessionSlot = .day
        context.insert(morningNap)

        let note = Activity(type: .note, startTime: todayAt(12, 12), baby: baby)
        note.noteText = "A applaudi toute seule pendant la comptine."
        context.insert(note)

        let pumpedMilk = Activity(type: .momsMilk, startTime: todayAt(13, 18), baby: baby)
        pumpedMilk.volumeML = 120
        pumpedMilk.sessionSlot = .day
        context.insert(pumpedMilk)

        let lunch = Activity(type: .solidFood, startTime: todayAt(14, 4), baby: baby)
        lunch.foodName = "Courgette, saumon & riz"
        lunch.foodQuantity = 140
        lunch.foodUnit = .grams
        context.insert(lunch)

        let diaper3 = Activity(type: .diaper, startTime: todayAt(14, 28), baby: baby)
        diaper3.diaperType = .both
        context.insert(diaper3)

        let afternoonNap = Activity(
            type: .sleep,
            startTime: todayAt(15, 8),
            endTime: todayAt(16, 2),
            baby: baby
        )
        afternoonNap.sessionSlot = .day
        context.insert(afternoonNap)
    }

    @MainActor
    private static func insertHistoricalActivities(for baby: Baby, in context: ModelContext) {
        let formulaVolumes = [175.0, 185.0, 170.0, 180.0, 165.0, 190.0, 175.0, 180.0, 170.0, 185.0, 175.0, 180.0]
        let expressedMilkVolumes = [110.0, 90.0, 120.0, 95.0, 105.0, 115.0]
        let breakfasts = [
            "Compote pomme-poire",
            "Banane & avoine",
            "Yaourt nature & framboise",
            "Porridge mangue",
            "Poire & biscuit bebe",
            "Semoule vanille"
        ]
        let lunches = [
            "Carotte & patate douce",
            "Brocoli & poulet",
            "Courge & quinoa",
            "Petits pois & dinde",
            "Patate douce & cabillaud",
            "Riz, carotte & lentilles"
        ]
        let notes = [
            "A fait coucou a la nounou.",
            "A rampe jusque sous la table basse.",
            "Sourire geant apres le bain.",
            "S'est endormie seule dans le lit.",
            "A tape dans ses mains au parc."
        ]

        for dayOffset in 1...18 {
            let dayDate = Calendar.current.date(byAdding: .day, value: -dayOffset, to: Date())!
            let previousEvening = Calendar.current.date(byAdding: .day, value: -1, to: dayDate)!

            let overnight = Activity(
                type: .sleep,
                startTime: dateAt(previousEvening, 20 + dayOffset % 2, 32 + (dayOffset % 3) * 4),
                endTime: dateAt(dayDate, 6, 6 + (dayOffset % 4) * 7),
                baby: baby
            )
            overnight.sessionSlot = .night
            context.insert(overnight)

            let firstDiaper = Activity(type: .diaper, startTime: dateAt(dayDate, 6, 20 + dayOffset % 6), baby: baby)
            firstDiaper.diaperType = dayOffset.isMultiple(of: 3) ? .both : .pee
            context.insert(firstDiaper)

            let morningBottle = Activity(type: .formula, startTime: dateAt(dayDate, 7, 18 + dayOffset % 10), baby: baby)
            morningBottle.volumeML = formulaVolumes[(dayOffset - 1) % formulaVolumes.count]
            morningBottle.sessionSlot = .morning
            context.insert(morningBottle)

            let breakfast = Activity(type: .solidFood, startTime: dateAt(dayDate, 8, 3 + dayOffset % 14), baby: baby)
            breakfast.foodName = breakfasts[(dayOffset - 1) % breakfasts.count]
            breakfast.foodQuantity = Double(85 + (dayOffset % 4) * 10)
            breakfast.foodUnit = .grams
            context.insert(breakfast)

            let morningNap = Activity(
                type: .sleep,
                startTime: dateAt(dayDate, 9, 40 + dayOffset % 9),
                endTime: dateAt(dayDate, 11, 5 + (dayOffset % 3) * 12),
                baby: baby
            )
            morningNap.sessionSlot = .day
            context.insert(morningNap)

            let lunch = Activity(type: .solidFood, startTime: dateAt(dayDate, 12, 5 + dayOffset % 11), baby: baby)
            lunch.foodName = lunches[(dayOffset - 1) % lunches.count]
            lunch.foodQuantity = Double(120 + (dayOffset % 5) * 8)
            lunch.foodUnit = .grams
            context.insert(lunch)

            let afternoonBottle = Activity(type: .momsMilk, startTime: dateAt(dayDate, 13, 38 + dayOffset % 12), baby: baby)
            afternoonBottle.volumeML = expressedMilkVolumes[(dayOffset - 1) % expressedMilkVolumes.count]
            afternoonBottle.sessionSlot = .day
            context.insert(afternoonBottle)

            let afternoonNap = Activity(
                type: .sleep,
                startTime: dateAt(dayDate, 14, 30 + dayOffset % 15),
                endTime: dateAt(dayDate, 15, 32 + (dayOffset % 3) * 14),
                baby: baby
            )
            afternoonNap.sessionSlot = .day
            context.insert(afternoonNap)

            let thirdDiaper = Activity(type: .diaper, startTime: dateAt(dayDate, 16, 12 + dayOffset % 10), baby: baby)
            thirdDiaper.diaperType = dayOffset.isMultiple(of: 2) ? .pee : .both
            context.insert(thirdDiaper)

            let dinner = Activity(type: .solidFood, startTime: dateAt(dayDate, 18, 2 + dayOffset % 8), baby: baby)
            dinner.foodName = dayOffset.isMultiple(of: 2) ? "Polenta & courgette" : "Purée de lentilles corail"
            dinner.foodQuantity = Double(95 + (dayOffset % 4) * 12)
            dinner.foodUnit = .grams
            context.insert(dinner)

            let bedtimeBottle = Activity(type: .formula, startTime: dateAt(dayDate, 19, 8 + dayOffset % 14), baby: baby)
            bedtimeBottle.volumeML = 190 - Double((dayOffset % 3) * 10)
            bedtimeBottle.sessionSlot = .evening
            context.insert(bedtimeBottle)

            if dayOffset.isMultiple(of: 3) {
                let note = Activity(type: .note, startTime: dateAt(dayDate, 17, 24), baby: baby)
                note.noteText = notes[(dayOffset / 3 - 1) % notes.count]
                context.insert(note)
            }
        }
    }

    @MainActor
    private static func insertGrowthRecords(for baby: Baby, in context: ModelContext) {
        let birthDate = baby.dateOfBirth
        let growthData: [(Int, Double, Double, Double)] = [
            (0, 3.4, 50.5, 35.0),
            (14, 3.7, 51.4, 35.8),
            (30, 4.5, 54.8, 37.3),
            (60, 5.6, 58.7, 39.4),
            (90, 6.4, 61.8, 40.9),
            (120, 7.1, 64.5, 42.1),
            (150, 7.6, 66.7, 43.2),
            (180, 8.0, 69.0, 44.1),
            (210, 8.4, 71.0, 45.0),
            (240, 8.7, 72.6, 45.6),
            (270, 9.0, 74.0, 46.0),
            (300, 9.2, 75.2, 46.4)
        ]

        for (daysAfterBirth, weight, height, head) in growthData {
            let record = GrowthRecord(
                date: Calendar.current.date(byAdding: .day, value: daysAfterBirth, to: birthDate)!,
                weightKg: weight,
                heightCm: height,
                headCircumferenceCm: head,
                baby: baby
            )
            context.insert(record)
        }
    }

    @MainActor
    private static func insertHealthRecords(for baby: Baby, in context: ModelContext) {
        let calendar = Calendar.current
        let birthDate = baby.dateOfBirth
        let now = Date()

        let vaccine2Months = HealthRecord(
            illnessType: .vaccination,
            startDate: calendar.date(byAdding: .day, value: 60, to: birthDate)!,
            endDate: calendar.date(byAdding: .day, value: 60, to: birthDate)!,
            notes: "Vaccins 2 mois (DTP, coqueluche, Hib, hepatite B, pneumocoque).",
            baby: baby
        )
        vaccine2Months.temperatures = [
            TemperatureReading(temperature: 38.1, measuredAt: calendar.date(byAdding: .day, value: 60, to: birthDate)!)
        ]
        vaccine2Months.symptoms = [
            Symptom(description: "Rougeur au point d'injection", severity: .mild),
            Symptom(description: "Sommeil plus court", severity: .mild)
        ]
        context.insert(vaccine2Months)

        let cold = HealthRecord(
            illnessType: .cold,
            startDate: calendar.date(byAdding: .day, value: 192, to: birthDate)!,
            endDate: calendar.date(byAdding: .day, value: 198, to: birthDate)!,
            notes: "Rhume leger avec nez qui coule et reveils plus frequents.",
            baby: baby
        )
        cold.symptoms = [
            Symptom(description: "Nez qui coule", severity: .moderate),
            Symptom(description: "Eternuements", severity: .mild),
            Symptom(description: "Sommeil perturbe", severity: .mild)
        ]
        cold.temperatures = [
            TemperatureReading(temperature: 37.8, measuredAt: calendar.date(byAdding: .day, value: 192, to: birthDate)!),
            TemperatureReading(temperature: 37.6, measuredAt: calendar.date(byAdding: .day, value: 194, to: birthDate)!)
        ]
        context.insert(cold)

        if requestedScreen == .health {
            let earInfection = HealthRecord(
                illnessType: .earInfection,
                startDate: calendar.date(byAdding: .hour, value: -26, to: now)!,
                notes: "Se reveille en pleurant et touche souvent son oreille droite.",
                baby: baby
            )
            earInfection.symptoms = [
                Symptom(description: "Oreille chaude", severity: .moderate),
                Symptom(description: "Irritabilite", severity: .moderate),
                Symptom(description: "Petit appetit", severity: .mild)
            ]
            earInfection.temperatures = [
                TemperatureReading(temperature: 38.4, measuredAt: calendar.date(byAdding: .hour, value: -18, to: now)!),
                TemperatureReading(temperature: 38.7, measuredAt: calendar.date(byAdding: .hour, value: -6, to: now)!),
                TemperatureReading(temperature: 38.2, measuredAt: calendar.date(byAdding: .hour, value: -1, to: now)!)
            ]
            earInfection.medications = [
                Medication(name: "Doliprane", dosage: "120 mg si besoin"),
                Medication(name: "Sérum physiologique", dosage: "Lavage de nez avant le coucher")
            ]
            context.insert(earInfection)
        } else {
            let teething = HealthRecord(
                illnessType: .teething,
                startDate: calendar.date(byAdding: .day, value: -8, to: now)!,
                notes: "Premieres molaires en preparation, bave beaucoup.",
                baby: baby
            )
            teething.symptoms = [
                Symptom(description: "Gencives gonflees", severity: .moderate),
                Symptom(description: "Mordille ses jouets", severity: .moderate),
                Symptom(description: "Bave excessive", severity: .mild)
            ]
            teething.temperatures = [
                TemperatureReading(temperature: 37.6, measuredAt: calendar.date(byAdding: .day, value: -2, to: now)!)
            ]
            teething.medications = [
                Medication(name: "Anneau de dentition refroidi", dosage: "A la demande")
            ]
            context.insert(teething)
        }
    }

    @MainActor
    private static func insertOngoingSleep(for baby: Baby, in context: ModelContext) {
        let ongoingSleep = Activity(
            type: .sleep,
            startTime: Calendar.current.date(byAdding: .minute, value: -98, to: Date())!,
            isOngoing: true,
            baby: baby
        )
        ongoingSleep.sessionSlot = .day
        context.insert(ongoingSleep)
    }

    private static func todayAt(_ hour: Int, _ minute: Int) -> Date {
        dateAt(Date(), hour, minute)
    }

    private static func yesterdayAt(_ hour: Int, _ minute: Int) -> Date {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        return dateAt(yesterday, hour, minute)
    }

    private static func dateAt(_ day: Date, _ hour: Int, _ minute: Int) -> Date {
        let startOfDay = Calendar.current.startOfDay(for: day)
        return Calendar.current.date(byAdding: .minute, value: hour * 60 + minute, to: startOfDay)!
    }

    private static func makeProfileImageData(initial: String) -> Data? {
        let size = CGSize(width: 600, height: 600)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            let cg = context.cgContext

            let colors = [
                UIColor(red: 1.0, green: 0.78, blue: 0.84, alpha: 1).cgColor,
                UIColor(red: 1.0, green: 0.62, blue: 0.70, alpha: 1).cgColor,
                UIColor(red: 0.98, green: 0.50, blue: 0.57, alpha: 1).cgColor
            ] as CFArray

            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 0.55, 1])!
            cg.drawLinearGradient(gradient, start: CGPoint(x: 0, y: 0), end: CGPoint(x: size.width, y: size.height), options: [])

            cg.setFillColor(UIColor.white.withAlphaComponent(0.18).cgColor)
            cg.fillEllipse(in: CGRect(x: 56, y: 76, width: 180, height: 180))
            cg.fillEllipse(in: CGRect(x: 320, y: 96, width: 220, height: 220))
            cg.fillEllipse(in: CGRect(x: 180, y: 340, width: 300, height: 180))

            let circleRect = CGRect(x: 105, y: 105, width: 390, height: 390)
            cg.setFillColor(UIColor.white.withAlphaComponent(0.18).cgColor)
            cg.fillEllipse(in: circleRect)
            cg.setStrokeColor(UIColor.white.withAlphaComponent(0.30).cgColor)
            cg.setLineWidth(6)
            cg.strokeEllipse(in: circleRect.insetBy(dx: 8, dy: 8))

            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 220, weight: .black),
                .foregroundColor: UIColor.white
            ]
            let attributed = NSAttributedString(string: initial, attributes: attributes)
            let textSize = attributed.size()
            let textRect = CGRect(
                x: (size.width - textSize.width) / 2,
                y: (size.height - textSize.height) / 2 - 24,
                width: textSize.width,
                height: textSize.height
            )
            attributed.draw(in: textRect)
        }
        return image.pngData()
    }
}
