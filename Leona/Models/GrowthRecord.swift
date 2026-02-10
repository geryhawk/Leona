import Foundation
import SwiftData

@Model
final class GrowthRecord {
    var id: UUID
    var date: Date
    var weightKg: Double?
    var heightCm: Double?
    var headCircumferenceCm: Double?
    var baby: Baby?
    var createdAt: Date
    var updatedAt: Date
    
    init(
        date: Date = Date(),
        weightKg: Double? = nil,
        heightCm: Double? = nil,
        headCircumferenceCm: Double? = nil,
        baby: Baby? = nil
    ) {
        self.id = UUID()
        self.date = date
        self.weightKg = weightKg
        self.heightCm = heightCm
        self.headCircumferenceCm = headCircumferenceCm
        self.baby = baby
        self.createdAt = Date()
        self.updatedAt = Date()
    }
    
    var ageInDaysAtMeasurement: Int? {
        guard let baby = baby else { return nil }
        return Calendar.current.dateComponents([.day], from: baby.dateOfBirth, to: date).day
    }
    
    var ageInMonthsAtMeasurement: Double? {
        guard let baby = baby else { return nil }
        let components = Calendar.current.dateComponents([.month, .day], from: baby.dateOfBirth, to: date)
        return Double(components.month ?? 0) + Double(components.day ?? 0) / 30.44
    }
    
    var hasMeasurements: Bool {
        weightKg != nil || heightCm != nil || headCircumferenceCm != nil
    }
}
