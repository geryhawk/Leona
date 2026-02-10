import Foundation

/// Provides WHO growth percentile data for charts
struct WHODataService {
    
    // MARK: - WHO Percentile Data (embedded for reliability)
    // Based on WHO Child Growth Standards
    // Age in months, values for P3, P15, P50, P85, P97
    
    static func weightPercentiles(gender: BabyGender) -> [WHOPercentilePoint] {
        let data: [(Double, Double, Double, Double, Double, Double)]
        
        if gender == .girl {
            data = [
                // (months, P3, P15, P50, P85, P97)
                (0, 2.4, 2.8, 3.2, 3.7, 4.2),
                (1, 3.2, 3.6, 4.2, 4.8, 5.5),
                (2, 3.9, 4.5, 5.1, 5.8, 6.6),
                (3, 4.5, 5.2, 5.8, 6.6, 7.5),
                (4, 5.0, 5.7, 6.4, 7.3, 8.2),
                (5, 5.4, 6.1, 6.9, 7.8, 8.8),
                (6, 5.7, 6.5, 7.3, 8.2, 9.3),
                (7, 6.0, 6.8, 7.6, 8.6, 9.8),
                (8, 6.3, 7.0, 7.9, 9.0, 10.2),
                (9, 6.5, 7.3, 8.2, 9.3, 10.5),
                (10, 6.7, 7.5, 8.5, 9.6, 10.9),
                (11, 6.9, 7.7, 8.7, 9.9, 11.2),
                (12, 7.0, 7.9, 8.9, 10.1, 11.5),
                (15, 7.6, 8.5, 9.6, 10.9, 12.4),
                (18, 8.1, 9.1, 10.2, 11.6, 13.2),
                (21, 8.6, 9.6, 10.9, 12.4, 14.0),
                (24, 9.0, 10.2, 11.5, 13.0, 14.8),
            ]
        } else {
            data = [
                (0, 2.5, 2.9, 3.3, 3.9, 4.4),
                (1, 3.4, 3.9, 4.5, 5.1, 5.8),
                (2, 4.3, 4.9, 5.6, 6.3, 7.1),
                (3, 5.0, 5.7, 6.4, 7.2, 8.0),
                (4, 5.6, 6.2, 7.0, 7.8, 8.7),
                (5, 6.0, 6.7, 7.5, 8.4, 9.3),
                (6, 6.4, 7.1, 7.9, 8.8, 9.8),
                (7, 6.7, 7.4, 8.3, 9.2, 10.3),
                (8, 6.9, 7.7, 8.6, 9.6, 10.7),
                (9, 7.1, 8.0, 8.9, 9.9, 11.0),
                (10, 7.4, 8.2, 9.2, 10.2, 11.4),
                (11, 7.6, 8.4, 9.4, 10.5, 11.7),
                (12, 7.7, 8.6, 9.6, 10.8, 12.0),
                (15, 8.3, 9.2, 10.3, 11.5, 12.8),
                (18, 8.8, 9.8, 10.9, 12.2, 13.7),
                (21, 9.3, 10.3, 11.5, 12.9, 14.5),
                (24, 9.7, 10.8, 12.2, 13.6, 15.3),
            ]
        }
        
        return data.map { WHOPercentilePoint(ageInMonths: $0.0, p3: $0.1, p15: $0.2, p50: $0.3, p85: $0.4, p97: $0.5) }
    }
    
    static func heightPercentiles(gender: BabyGender) -> [WHOPercentilePoint] {
        let data: [(Double, Double, Double, Double, Double, Double)]
        
        if gender == .girl {
            data = [
                (0, 45.4, 47.3, 49.1, 51.0, 52.9),
                (1, 49.8, 51.7, 53.7, 55.6, 57.6),
                (2, 53.0, 55.0, 57.1, 59.1, 61.1),
                (3, 55.6, 57.7, 59.8, 61.9, 63.9),
                (4, 57.8, 59.9, 62.1, 64.3, 66.4),
                (5, 59.6, 61.8, 64.0, 66.2, 68.5),
                (6, 61.2, 63.5, 65.7, 68.0, 70.3),
                (7, 62.7, 65.0, 67.3, 69.6, 71.9),
                (8, 64.0, 66.4, 68.7, 71.1, 73.5),
                (9, 65.3, 67.7, 70.1, 72.6, 75.0),
                (10, 66.5, 69.0, 71.5, 73.9, 76.4),
                (11, 67.7, 70.3, 72.8, 75.3, 77.8),
                (12, 68.9, 71.4, 74.0, 76.6, 79.2),
                (15, 72.0, 74.8, 77.5, 80.2, 83.0),
                (18, 74.9, 77.8, 80.7, 83.6, 86.5),
                (21, 77.5, 80.6, 83.7, 86.7, 89.8),
                (24, 80.0, 83.2, 86.4, 89.6, 92.9),
            ]
        } else {
            data = [
                (0, 46.1, 48.0, 49.9, 51.8, 53.7),
                (1, 50.8, 52.8, 54.7, 56.7, 58.6),
                (2, 54.4, 56.4, 58.4, 60.4, 62.4),
                (3, 57.3, 59.4, 61.4, 63.5, 65.5),
                (4, 59.7, 61.8, 63.9, 66.0, 68.0),
                (5, 61.7, 63.8, 65.9, 68.0, 70.1),
                (6, 63.3, 65.5, 67.6, 69.8, 71.9),
                (7, 64.8, 67.0, 69.2, 71.3, 73.5),
                (8, 66.2, 68.4, 70.6, 72.8, 75.0),
                (9, 67.5, 69.7, 72.0, 74.2, 76.5),
                (10, 68.7, 71.0, 73.3, 75.6, 77.9),
                (11, 69.9, 72.2, 74.5, 76.9, 79.2),
                (12, 71.0, 73.4, 75.7, 78.1, 80.5),
                (15, 74.1, 76.6, 79.1, 81.7, 84.2),
                (18, 76.9, 79.6, 82.3, 85.0, 87.7),
                (21, 79.4, 82.3, 85.1, 88.0, 90.9),
                (24, 81.7, 84.8, 87.8, 90.9, 93.9),
            ]
        }
        
        return data.map { WHOPercentilePoint(ageInMonths: $0.0, p3: $0.1, p15: $0.2, p50: $0.3, p85: $0.4, p97: $0.5) }
    }
    
    static func headCircumferencePercentiles(gender: BabyGender) -> [WHOPercentilePoint] {
        let data: [(Double, Double, Double, Double, Double, Double)]
        
        if gender == .girl {
            data = [
                (0, 31.5, 32.7, 33.9, 35.1, 36.2),
                (1, 34.2, 35.4, 36.5, 37.7, 38.9),
                (2, 35.8, 37.0, 38.3, 39.5, 40.7),
                (3, 37.1, 38.3, 39.5, 40.8, 42.0),
                (4, 38.1, 39.3, 40.6, 41.8, 43.1),
                (5, 38.9, 40.2, 41.5, 42.7, 44.0),
                (6, 39.6, 40.9, 42.2, 43.5, 44.8),
                (7, 40.2, 41.5, 42.8, 44.1, 45.5),
                (8, 40.7, 42.0, 43.4, 44.7, 46.0),
                (9, 41.2, 42.5, 43.8, 45.2, 46.5),
                (10, 41.5, 42.9, 44.2, 45.6, 46.9),
                (11, 41.9, 43.2, 44.6, 45.9, 47.3),
                (12, 42.2, 43.5, 44.9, 46.3, 47.6),
                (15, 43.0, 44.4, 45.8, 47.2, 48.6),
                (18, 43.6, 45.0, 46.5, 47.9, 49.3),
                (21, 44.1, 45.5, 47.0, 48.5, 49.9),
                (24, 44.6, 46.0, 47.5, 49.0, 50.5),
            ]
        } else {
            data = [
                (0, 32.1, 33.2, 34.5, 35.7, 36.9),
                (1, 34.9, 36.1, 37.3, 38.4, 39.6),
                (2, 36.8, 38.0, 39.1, 40.3, 41.5),
                (3, 38.1, 39.3, 40.5, 41.7, 42.9),
                (4, 39.2, 40.4, 41.6, 42.8, 44.0),
                (5, 40.1, 41.3, 42.6, 43.8, 45.0),
                (6, 40.9, 42.1, 43.3, 44.6, 45.8),
                (7, 41.5, 42.7, 44.0, 45.2, 46.4),
                (8, 42.0, 43.3, 44.5, 45.8, 47.0),
                (9, 42.5, 43.7, 45.0, 46.3, 47.5),
                (10, 42.9, 44.1, 45.4, 46.7, 47.9),
                (11, 43.2, 44.5, 45.8, 47.0, 48.3),
                (12, 43.5, 44.8, 46.1, 47.4, 48.6),
                (15, 44.3, 45.5, 46.8, 48.1, 49.4),
                (18, 44.8, 46.1, 47.4, 48.8, 50.1),
                (21, 45.3, 46.6, 47.9, 49.2, 50.5),
                (24, 45.8, 47.1, 48.4, 49.7, 51.0),
            ]
        }
        
        return data.map { WHOPercentilePoint(ageInMonths: $0.0, p3: $0.1, p15: $0.2, p50: $0.3, p85: $0.4, p97: $0.5) }
    }
    
    // MARK: - Percentile Calculation
    
    /// Calculate which percentile a measurement falls on
    static func calculatePercentile(
        value: Double,
        ageInMonths: Double,
        data: [WHOPercentilePoint]
    ) -> Double? {
        // Find the two surrounding data points
        guard let lower = data.last(where: { $0.ageInMonths <= ageInMonths }),
              let upper = data.first(where: { $0.ageInMonths >= ageInMonths }) else {
            return nil
        }
        
        // Interpolate if needed
        let point: WHOPercentilePoint
        if lower.ageInMonths == upper.ageInMonths {
            point = lower
        } else {
            let ratio = (ageInMonths - lower.ageInMonths) / (upper.ageInMonths - lower.ageInMonths)
            point = WHOPercentilePoint(
                ageInMonths: ageInMonths,
                p3: lower.p3 + (upper.p3 - lower.p3) * ratio,
                p15: lower.p15 + (upper.p15 - lower.p15) * ratio,
                p50: lower.p50 + (upper.p50 - lower.p50) * ratio,
                p85: lower.p85 + (upper.p85 - lower.p85) * ratio,
                p97: lower.p97 + (upper.p97 - lower.p97) * ratio
            )
        }
        
        // Estimate percentile based on where value falls
        if value <= point.p3 { return 3 }
        if value <= point.p15 {
            return 3 + (value - point.p3) / (point.p15 - point.p3) * 12
        }
        if value <= point.p50 {
            return 15 + (value - point.p15) / (point.p50 - point.p15) * 35
        }
        if value <= point.p85 {
            return 50 + (value - point.p50) / (point.p85 - point.p50) * 35
        }
        if value <= point.p97 {
            return 85 + (value - point.p85) / (point.p97 - point.p85) * 12
        }
        return 97
    }
}
