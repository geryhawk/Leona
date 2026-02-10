import Foundation
import SwiftData
import SwiftUI

@Model
final class HealthRecord {
    var id: UUID
    var illnessType: IllnessType
    var startDate: Date
    var endDate: Date?
    var notes: String
    var baby: Baby?
    var createdAt: Date
    var updatedAt: Date
    
    // Embedded data (stored as JSON-encoded arrays)
    var symptomsData: Data?
    var medicationsData: Data?
    var temperaturesData: Data?
    
    init(
        illnessType: IllnessType = .other,
        startDate: Date = Date(),
        endDate: Date? = nil,
        notes: String = "",
        baby: Baby? = nil
    ) {
        self.id = UUID()
        self.illnessType = illnessType
        self.startDate = startDate
        self.endDate = endDate
        self.notes = notes
        self.baby = baby
        self.createdAt = Date()
        self.updatedAt = Date()
    }
    
    var isOngoing: Bool {
        endDate == nil
    }
    
    var durationDays: Int? {
        let end = endDate ?? Date()
        return Calendar.current.dateComponents([.day], from: startDate, to: end).day
    }
    
    // MARK: - Symptoms
    
    var symptoms: [Symptom] {
        get {
            guard let data = symptomsData else { return [] }
            return (try? JSONDecoder().decode([Symptom].self, from: data)) ?? []
        }
        set {
            symptomsData = try? JSONEncoder().encode(newValue)
            updatedAt = Date()
        }
    }
    
    // MARK: - Medications
    
    var medications: [Medication] {
        get {
            guard let data = medicationsData else { return [] }
            return (try? JSONDecoder().decode([Medication].self, from: data)) ?? []
        }
        set {
            medicationsData = try? JSONEncoder().encode(newValue)
            updatedAt = Date()
        }
    }
    
    // MARK: - Temperatures
    
    var temperatures: [TemperatureReading] {
        get {
            guard let data = temperaturesData else { return [] }
            return (try? JSONDecoder().decode([TemperatureReading].self, from: data)) ?? []
        }
        set {
            temperaturesData = try? JSONEncoder().encode(newValue)
            updatedAt = Date()
        }
    }
    
    var latestTemperature: Double? {
        temperatures.sorted(by: { $0.measuredAt > $1.measuredAt }).first?.temperature
    }
    
    var maxTemperature: Double? {
        temperatures.map(\.temperature).max()
    }
}

// MARK: - Illness Type

enum IllnessType: String, Codable, CaseIterable, Identifiable {
    case cold
    case flu
    case fever
    case earInfection
    case stomachBug
    case rash
    case teething
    case allergy
    case vaccination
    case other
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .cold: return String(localized: "illness_cold")
        case .flu: return String(localized: "illness_flu")
        case .fever: return String(localized: "illness_fever")
        case .earInfection: return String(localized: "illness_ear_infection")
        case .stomachBug: return String(localized: "illness_stomach_bug")
        case .rash: return String(localized: "illness_rash")
        case .teething: return String(localized: "illness_teething")
        case .allergy: return String(localized: "illness_allergy")
        case .vaccination: return String(localized: "illness_vaccination")
        case .other: return String(localized: "illness_other")
        }
    }
    
    var icon: String {
        switch self {
        case .cold: return "wind"
        case .flu: return "facemask.fill"
        case .fever: return "thermometer.high"
        case .earInfection: return "ear.fill"
        case .stomachBug: return "stomach"
        case .rash: return "hand.raised.fingers.spread.fill"
        case .teething: return "mouth.fill"
        case .allergy: return "allergens.fill"
        case .vaccination: return "syringe.fill"
        case .other: return "cross.case.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .cold: return .blue
        case .flu: return .purple
        case .fever: return .red
        case .earInfection: return .orange
        case .stomachBug: return .green
        case .rash: return .pink
        case .teething: return .mint
        case .allergy: return .yellow
        case .vaccination: return .teal
        case .other: return .gray
        }
    }
}

// MARK: - Embedded Types

struct Symptom: Codable, Identifiable, Hashable {
    var id: UUID
    var description: String
    var observedAt: Date
    var severity: SymptomSeverity
    
    init(description: String, observedAt: Date = Date(), severity: SymptomSeverity = .moderate) {
        self.id = UUID()
        self.description = description
        self.observedAt = observedAt
        self.severity = severity
    }
}

enum SymptomSeverity: String, Codable, CaseIterable, Identifiable {
    case mild
    case moderate
    case severe
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .mild: return String(localized: "severity_mild")
        case .moderate: return String(localized: "severity_moderate")
        case .severe: return String(localized: "severity_severe")
        }
    }
    
    var color: Color {
        switch self {
        case .mild: return .yellow
        case .moderate: return .orange
        case .severe: return .red
        }
    }
}

struct Medication: Codable, Identifiable, Hashable {
    var id: UUID
    var name: String
    var dosage: String
    var administeredAt: Date
    
    init(name: String, dosage: String = "", administeredAt: Date = Date()) {
        self.id = UUID()
        self.name = name
        self.dosage = dosage
        self.administeredAt = administeredAt
    }
}

struct TemperatureReading: Codable, Identifiable, Hashable {
    var id: UUID
    var temperature: Double
    var measuredAt: Date
    
    init(temperature: Double, measuredAt: Date = Date()) {
        self.id = UUID()
        self.temperature = temperature
        self.measuredAt = measuredAt
    }
    
    var isElevated: Bool { temperature >= 37.5 }
    var isFever: Bool { temperature >= 38.0 }
    var isHighFever: Bool { temperature >= 39.0 }
}
