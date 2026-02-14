import Foundation
import CloudKit

// MARK: - CKRecord Convertible Protocol

protocol CKRecordConvertible {
    static var ckRecordType: String { get }
    var id: UUID { get }
    func toCKRecord(in zone: CKRecordZone.ID) -> CKRecord
    mutating func applyCKRecord(_ record: CKRecord)
}

// MARK: - Baby + CKRecord

extension Baby: CKRecordConvertible {
    static var ckRecordType: String { "Baby" }

    func toCKRecord(in zone: CKRecordZone.ID) -> CKRecord {
        let recordID = CKRecord.ID(recordName: id.uuidString, zoneID: zone)
        let record = CKRecord(recordType: Self.ckRecordType, recordID: recordID)
        record["firstName"] = firstName as CKRecordValue
        record["lastName"] = lastName as CKRecordValue
        record["dateOfBirth"] = dateOfBirth as CKRecordValue
        record["gender"] = gender.rawValue as CKRecordValue
        record["bloodType"] = bloodType as CKRecordValue
        record["isActive"] = (isActive ? 1 : 0) as CKRecordValue
        record["ownerName"] = ownerName as CKRecordValue?
        record["createdAt"] = createdAt as CKRecordValue
        record["updatedAt"] = updatedAt as CKRecordValue

        if let imageData = profileImageData {
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString + ".jpg")
            try? imageData.write(to: tempURL)
            record["profileImage"] = CKAsset(fileURL: tempURL)
        }

        return record
    }

    func applyCKRecord(_ record: CKRecord) {
        if let val = record["firstName"] as? String { firstName = val }
        if let val = record["lastName"] as? String { lastName = val }
        if let val = record["dateOfBirth"] as? Date { dateOfBirth = val }
        if let val = record["gender"] as? String { gender = BabyGender(rawValue: val) ?? .unspecified }
        if let val = record["bloodType"] as? String { bloodType = val }
        if let val = record["isActive"] as? Int { isActive = val == 1 }
        ownerName = record["ownerName"] as? String

        if let asset = record["profileImage"] as? CKAsset, let url = asset.fileURL {
            profileImageData = try? Data(contentsOf: url)
        }

        ckRecordName = record.recordID.recordName
        ckChangeTag = record.recordChangeTag
        updatedAt = record.modificationDate ?? Date()
    }
}

// MARK: - Activity + CKRecord

extension Activity: CKRecordConvertible {
    static var ckRecordType: String { "Activity" }

    func toCKRecord(in zone: CKRecordZone.ID) -> CKRecord {
        let recordID = CKRecord.ID(recordName: id.uuidString, zoneID: zone)
        let record = CKRecord(recordType: Self.ckRecordType, recordID: recordID)
        record["type"] = type.rawValue as CKRecordValue
        record["startTime"] = startTime as CKRecordValue
        record["endTime"] = endTime as CKRecordValue?
        record["isOngoing"] = (isOngoing ? 1 : 0) as CKRecordValue
        record["volumeML"] = volumeML as CKRecordValue?
        record["breastSide"] = breastSide?.rawValue as CKRecordValue?
        record["sessionSlot"] = sessionSlot?.rawValue as CKRecordValue?
        record["foodName"] = foodName as CKRecordValue?
        record["foodQuantity"] = foodQuantity as CKRecordValue?
        record["foodUnit"] = foodUnit?.rawValue as CKRecordValue?
        record["diaperType"] = diaperType?.rawValue as CKRecordValue?
        record["noteText"] = noteText as CKRecordValue?
        record["createdAt"] = createdAt as CKRecordValue
        record["updatedAt"] = updatedAt as CKRecordValue

        // Parent reference
        if let babyID = baby?.id {
            let babyRecordID = CKRecord.ID(recordName: babyID.uuidString, zoneID: zone)
            record["baby"] = CKRecord.Reference(recordID: babyRecordID, action: .deleteSelf)
        }

        return record
    }

    func applyCKRecord(_ record: CKRecord) {
        if let val = record["type"] as? String { type = ActivityType(rawValue: val) ?? .note }
        if let val = record["startTime"] as? Date { startTime = val }
        endTime = record["endTime"] as? Date
        if let val = record["isOngoing"] as? Int { isOngoing = val == 1 }
        volumeML = record["volumeML"] as? Double
        if let val = record["breastSide"] as? String { breastSide = BreastSide(rawValue: val) }
        if let val = record["sessionSlot"] as? String { sessionSlot = SessionSlot(rawValue: val) }
        foodName = record["foodName"] as? String
        foodQuantity = record["foodQuantity"] as? Double
        if let val = record["foodUnit"] as? String { foodUnit = FoodUnit(rawValue: val) }
        if let val = record["diaperType"] as? String { diaperType = DiaperType(rawValue: val) }
        noteText = record["noteText"] as? String

        ckRecordName = record.recordID.recordName
        ckChangeTag = record.recordChangeTag
        updatedAt = record.modificationDate ?? Date()
    }
}

// MARK: - GrowthRecord + CKRecord

extension GrowthRecord: CKRecordConvertible {
    static var ckRecordType: String { "GrowthRecord" }

    func toCKRecord(in zone: CKRecordZone.ID) -> CKRecord {
        let recordID = CKRecord.ID(recordName: id.uuidString, zoneID: zone)
        let record = CKRecord(recordType: Self.ckRecordType, recordID: recordID)
        record["date"] = date as CKRecordValue
        record["weightKg"] = weightKg as CKRecordValue?
        record["heightCm"] = heightCm as CKRecordValue?
        record["headCircumferenceCm"] = headCircumferenceCm as CKRecordValue?
        record["createdAt"] = createdAt as CKRecordValue
        record["updatedAt"] = updatedAt as CKRecordValue

        if let babyID = baby?.id {
            let babyRecordID = CKRecord.ID(recordName: babyID.uuidString, zoneID: zone)
            record["baby"] = CKRecord.Reference(recordID: babyRecordID, action: .deleteSelf)
        }

        return record
    }

    func applyCKRecord(_ record: CKRecord) {
        if let val = record["date"] as? Date { date = val }
        weightKg = record["weightKg"] as? Double
        heightCm = record["heightCm"] as? Double
        headCircumferenceCm = record["headCircumferenceCm"] as? Double

        ckRecordName = record.recordID.recordName
        ckChangeTag = record.recordChangeTag
        updatedAt = record.modificationDate ?? Date()
    }
}

// MARK: - HealthRecord + CKRecord

extension HealthRecord: CKRecordConvertible {
    static var ckRecordType: String { "HealthRecord" }

    func toCKRecord(in zone: CKRecordZone.ID) -> CKRecord {
        let recordID = CKRecord.ID(recordName: id.uuidString, zoneID: zone)
        let record = CKRecord(recordType: Self.ckRecordType, recordID: recordID)
        record["illnessType"] = illnessType.rawValue as CKRecordValue
        record["startDate"] = startDate as CKRecordValue
        record["endDate"] = endDate as CKRecordValue?
        record["notes"] = notes as CKRecordValue
        record["symptomsData"] = symptomsData as CKRecordValue?
        record["medicationsData"] = medicationsData as CKRecordValue?
        record["temperaturesData"] = temperaturesData as CKRecordValue?
        record["createdAt"] = createdAt as CKRecordValue
        record["updatedAt"] = updatedAt as CKRecordValue

        if let babyID = baby?.id {
            let babyRecordID = CKRecord.ID(recordName: babyID.uuidString, zoneID: zone)
            record["baby"] = CKRecord.Reference(recordID: babyRecordID, action: .deleteSelf)
        }

        return record
    }

    func applyCKRecord(_ record: CKRecord) {
        if let val = record["illnessType"] as? String { illnessType = IllnessType(rawValue: val) ?? .other }
        if let val = record["startDate"] as? Date { startDate = val }
        endDate = record["endDate"] as? Date
        if let val = record["notes"] as? String { notes = val }
        symptomsData = record["symptomsData"] as? Data
        medicationsData = record["medicationsData"] as? Data
        temperaturesData = record["temperaturesData"] as? Data

        ckRecordName = record.recordID.recordName
        ckChangeTag = record.recordChangeTag
        updatedAt = record.modificationDate ?? Date()
    }
}
