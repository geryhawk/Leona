import Foundation
import SwiftData
import SwiftUI
import UIKit

@Model
final class Baby {
    var id: UUID
    var firstName: String
    var lastName: String
    var dateOfBirth: Date
    var gender: BabyGender
    var bloodType: String
    @Attribute(.externalStorage) var profileImageData: Data?
    var isActive: Bool
    var createdAt: Date
    var updatedAt: Date
    
    // Sharing
    var shareCode: String?
    var ownerName: String?
    
    // Relationships
    @Relationship(deleteRule: .cascade, inverse: \Activity.baby)
    var activities: [Activity] = []
    
    @Relationship(deleteRule: .cascade, inverse: \GrowthRecord.baby)
    var growthRecords: [GrowthRecord] = []
    
    @Relationship(deleteRule: .cascade, inverse: \HealthRecord.baby)
    var healthRecords: [HealthRecord] = []
    
    init(
        firstName: String,
        lastName: String = "",
        dateOfBirth: Date,
        gender: BabyGender = .unspecified,
        bloodType: String = ""
    ) {
        self.id = UUID()
        self.firstName = firstName
        self.lastName = lastName
        self.dateOfBirth = dateOfBirth
        self.gender = gender
        self.bloodType = bloodType
        self.profileImageData = nil
        self.isActive = true
        self.createdAt = Date()
        self.updatedAt = Date()
        self.shareCode = nil
        self.ownerName = nil
    }
    
    var fullName: String {
        [firstName, lastName].filter { !$0.isEmpty }.joined(separator: " ")
    }
    
    var displayName: String {
        firstName.isEmpty ? String(localized: "baby") : firstName
    }
    
    var ageComponents: DateComponents {
        Calendar.current.dateComponents([.year, .month, .day], from: dateOfBirth, to: Date())
    }
    
    var ageInDays: Int {
        Calendar.current.dateComponents([.day], from: dateOfBirth, to: Date()).day ?? 0
    }
    
    var ageInMonths: Double {
        let components = Calendar.current.dateComponents([.month, .day], from: dateOfBirth, to: Date())
        return Double(components.month ?? 0) + Double(components.day ?? 0) / 30.44
    }
    
    var isBorn: Bool {
        dateOfBirth <= Date()
    }
    
    var ageDescription: String {
        if !isBorn {
            let days = Calendar.current.dateComponents([.day], from: Date(), to: dateOfBirth).day ?? 0
            return String(localized: "arrival_in_days \(days)")
        }
        let comps = ageComponents
        let years = comps.year ?? 0
        let months = comps.month ?? 0
        let days = comps.day ?? 0
        
        if years > 0 {
            return months > 0
                ? String(localized: "age_years_months \(years) \(months)")
                : String(localized: "age_years \(years)")
        } else if months > 0 {
            return days > 0
                ? String(localized: "age_months_days \(months) \(days)")
                : String(localized: "age_months \(months)")
        } else {
            return String(localized: "age_days \(days)")
        }
    }
    
    var profileImage: Image? {
        guard let data = profileImageData,
              let uiImage = UIImage(data: data) else { return nil }
        return Image(uiImage: uiImage)
    }
    
    var isBirthday: Bool {
        let cal = Calendar.current
        let today = Date()
        return cal.component(.month, from: dateOfBirth) == cal.component(.month, from: today) &&
               cal.component(.day, from: dateOfBirth) == cal.component(.day, from: today)
    }
    
    var isMonthBirthday: Bool {
        let cal = Calendar.current
        return cal.component(.day, from: dateOfBirth) == cal.component(.day, from: Date())
    }
}

// MARK: - Enums

enum BabyGender: String, Codable, CaseIterable, Identifiable {
    case boy
    case girl
    case unspecified
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .boy: return String(localized: "gender_boy")
        case .girl: return String(localized: "gender_girl")
        case .unspecified: return String(localized: "gender_unspecified")
        }
    }
    
    var icon: String {
        switch self {
        case .boy: return "figure.child"
        case .girl: return "figure.child.circle"
        case .unspecified: return "face.smiling"
        }
    }
    
    var color: Color {
        switch self {
        case .boy: return .blue
        case .girl: return .pink
        case .unspecified: return .purple
        }
    }
}
