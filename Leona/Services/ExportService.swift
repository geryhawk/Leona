import Foundation
import UniformTypeIdentifiers

/// Exports baby data to CSV and PDF formats
struct ExportService {
    
    // MARK: - CSV Export
    
    static func exportToCSV(baby: Baby, activities: [Activity]) -> String {
        var csv = "Date,Time,Activity,Details,Duration,Volume(ml),Notes\n"
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm:ss"
        
        let sorted = activities.sorted { $0.startTime > $1.startTime }
        
        for activity in sorted {
            let date = dateFormatter.string(from: activity.startTime)
            let time = timeFormatter.string(from: activity.startTime)
            let type = activity.type.displayName
            let details = csvEscape(activity.summaryText)
            let duration = activity.durationFormatted
            let volume = activity.volumeML.map { String(format: "%.0f", $0) } ?? ""
            let notes = csvEscape(activity.noteText ?? "")
            
            csv += "\(date),\(time),\(type),\(details),\(duration),\(volume),\(notes)\n"
        }
        
        return csv
    }
    
    // MARK: - XML Export
    
    static func exportToXML(baby: Baby, activities: [Activity]) -> String {
        var xml = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
        xml += "<baby_data>\n"
        xml += "  <baby>\n"
        xml += "    <name>\(xmlEscape(baby.fullName))</name>\n"
        xml += "    <date_of_birth>\(ISO8601DateFormatter().string(from: baby.dateOfBirth))</date_of_birth>\n"
        xml += "    <gender>\(baby.gender.rawValue)</gender>\n"
        xml += "  </baby>\n"
        xml += "  <activities>\n"
        
        let sorted = activities.sorted { $0.startTime > $1.startTime }
        
        for activity in sorted {
            xml += "    <activity>\n"
            xml += "      <type>\(activity.type.rawValue)</type>\n"
            xml += "      <start_time>\(ISO8601DateFormatter().string(from: activity.startTime))</start_time>\n"
            if let end = activity.endTime {
                xml += "      <end_time>\(ISO8601DateFormatter().string(from: end))</end_time>\n"
            }
            if let vol = activity.volumeML {
                xml += "      <volume_ml>\(String(format: "%.0f", vol))</volume_ml>\n"
            }
            if let side = activity.breastSide {
                xml += "      <breast_side>\(side.rawValue)</breast_side>\n"
            }
            if let diaper = activity.diaperType {
                xml += "      <diaper_type>\(diaper.rawValue)</diaper_type>\n"
            }
            if let note = activity.noteText {
                xml += "      <note>\(xmlEscape(note))</note>\n"
            }
            if let food = activity.foodName {
                xml += "      <food_name>\(xmlEscape(food))</food_name>\n"
                if let qty = activity.foodQuantity {
                    xml += "      <food_quantity>\(String(format: "%.1f", qty))</food_quantity>\n"
                }
                if let unit = activity.foodUnit {
                    xml += "      <food_unit>\(unit.rawValue)</food_unit>\n"
                }
            }
            xml += "    </activity>\n"
        }
        
        xml += "  </activities>\n"
        xml += "</baby_data>\n"
        
        return xml
    }
    
    // MARK: - Growth Export
    
    static func exportGrowthToCSV(baby: Baby, records: [GrowthRecord]) -> String {
        var csv = "Date,Age(months),Weight(kg),Height(cm),Head Circumference(cm)\n"
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        let sorted = records.sorted { $0.date > $1.date }
        
        for record in sorted {
            let date = dateFormatter.string(from: record.date)
            let age = record.ageInMonthsAtMeasurement.map { String(format: "%.1f", $0) } ?? ""
            let weight = record.weightKg.map { String(format: "%.2f", $0) } ?? ""
            let height = record.heightCm.map { String(format: "%.1f", $0) } ?? ""
            let head = record.headCircumferenceCm.map { String(format: "%.1f", $0) } ?? ""
            
            csv += "\(date),\(age),\(weight),\(height),\(head)\n"
        }
        
        return csv
    }
    
    // MARK: - Full Report
    
    static func generateFullReport(
        baby: Baby,
        activities: [Activity],
        growthRecords: [GrowthRecord],
        healthRecords: [HealthRecord]
    ) -> String {
        var report = "=== LEONA BABY REPORT ===\n"
        report += "Generated: \(Date().formatted(date: .long, time: .shortened))\n\n"
        
        // Baby Info
        report += "--- Baby Profile ---\n"
        report += "Name: \(baby.fullName)\n"
        report += "Date of Birth: \(baby.dateOfBirth.formatted(date: .long, time: .omitted))\n"
        report += "Age: \(baby.ageDescription)\n"
        report += "Gender: \(baby.gender.displayName)\n"
        if !baby.bloodType.isEmpty {
            report += "Blood Type: \(baby.bloodType)\n"
        }
        report += "\n"
        
        // Activity Summary
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        let last30 = activities.filter {
            $0.startTime > thirtyDaysAgo
        }
        report += "--- Last 30 Days Summary ---\n"
        report += "Total Activities: \(last30.count)\n"
        report += "Feedings: \(last30.filter { $0.type.category == .feeding }.count)\n"
        report += "Sleep Sessions: \(last30.filter { $0.type == .sleep }.count)\n"
        report += "Diaper Changes: \(last30.filter { $0.type == .diaper }.count)\n\n"
        
        // Growth
        if let latest = growthRecords.sorted(by: { $0.date > $1.date }).first {
            report += "--- Latest Growth ---\n"
            report += "Date: \(latest.date.formatted(date: .long, time: .omitted))\n"
            if let w = latest.weightKg { report += "Weight: \(String(format: "%.2f", w)) kg\n" }
            if let h = latest.heightCm { report += "Height: \(String(format: "%.1f", h)) cm\n" }
            if let hc = latest.headCircumferenceCm { report += "Head: \(String(format: "%.1f", hc)) cm\n" }
            report += "\n"
        }
        
        // Health
        let activeIllnesses = healthRecords.filter { $0.isOngoing }
        if !activeIllnesses.isEmpty {
            report += "--- Active Health Issues ---\n"
            for illness in activeIllnesses {
                report += "- \(illness.illnessType.displayName) (since \(illness.startDate.formatted(date: .abbreviated, time: .omitted)))\n"
            }
            report += "\n"
        }
        
        return report
    }
    
    // MARK: - Helpers
    
    private static func csvEscape(_ string: String) -> String {
        if string.contains(",") || string.contains("\"") || string.contains("\n") {
            return "\"\(string.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return string
    }
    
    private static func xmlEscape(_ string: String) -> String {
        string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }
}
