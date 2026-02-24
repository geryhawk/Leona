import Foundation

/// Provides WHO growth percentile data for charts.
///
/// Data sources:
/// - WHO Child Growth Standards (0–5 years): Multi-country study (Brazil, Ghana, India, Norway, Oman, USA)
/// - WHO Growth Reference 2007 (5–19 years): Extended reference data
///
/// The WHO standards are ethnicity-independent by design — they represent how children
/// *should* grow under optimal conditions worldwide.
///
/// All values are stored in metric: weight in kg, height in cm, head circumference in cm.
struct WHODataService {

    // MARK: - Public API

    static func weightPercentiles(gender: BabyGender) -> [WHOPercentilePoint] {
        switch gender {
        case .girl: return girlWeight
        case .boy: return boyWeight
        case .unspecified: return mergedPercentiles(boyData: boyWeight, girlData: girlWeight)
        }
    }

    static func heightPercentiles(gender: BabyGender) -> [WHOPercentilePoint] {
        switch gender {
        case .girl: return girlHeight
        case .boy: return boyHeight
        case .unspecified: return mergedPercentiles(boyData: boyHeight, girlData: girlHeight)
        }
    }

    static func headCircumferencePercentiles(gender: BabyGender) -> [WHOPercentilePoint] {
        switch gender {
        case .girl: return girlHead
        case .boy: return boyHead
        case .unspecified: return mergedPercentiles(boyData: boyHead, girlData: girlHead)
        }
    }

    // MARK: - Percentile Calculation

    /// Calculate which percentile a measurement falls on
    static func calculatePercentile(
        value: Double,
        ageInMonths: Double,
        data: [WHOPercentilePoint]
    ) -> Double? {
        guard let lower = data.last(where: { $0.ageInMonths <= ageInMonths }),
              let upper = data.first(where: { $0.ageInMonths >= ageInMonths }) else {
            return nil
        }

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

        if value <= point.p3 { return 3 }
        if value <= point.p15 {
            let range = point.p15 - point.p3
            return range > 0 ? 3 + (value - point.p3) / range * 12 : 9
        }
        if value <= point.p50 {
            let range = point.p50 - point.p15
            return range > 0 ? 15 + (value - point.p15) / range * 35 : 32
        }
        if value <= point.p85 {
            let range = point.p85 - point.p50
            return range > 0 ? 50 + (value - point.p50) / range * 35 : 67
        }
        if value <= point.p97 {
            let range = point.p97 - point.p85
            return range > 0 ? 85 + (value - point.p85) / range * 12 : 91
        }
        return 97
    }

    // MARK: - Unspecified Gender Merge

    /// For unspecified gender: wider bands (min P3s, max P97s, average middle percentiles)
    private static func mergedPercentiles(boyData: [WHOPercentilePoint], girlData: [WHOPercentilePoint]) -> [WHOPercentilePoint] {
        zip(boyData, girlData).map { boy, girl in
            WHOPercentilePoint(
                ageInMonths: boy.ageInMonths,
                p3: min(boy.p3, girl.p3),
                p15: (boy.p15 + girl.p15) / 2,
                p50: (boy.p50 + girl.p50) / 2,
                p85: (boy.p85 + girl.p85) / 2,
                p97: max(boy.p97, girl.p97)
            )
        }
    }

    // MARK: - Girls Weight (kg) — 0–120 months (0–10 years)
    // WHO Child Growth Standards (0–60m) + WHO Growth Reference 2007 (61–120m)
    // (ageMonths, P3, P15, P50, P85, P97)

    private static let girlWeight: [WHOPercentilePoint] = [
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
        (30, 9.9, 11.2, 12.7, 14.4, 16.5),
        (36, 10.8, 12.2, 13.9, 15.8, 18.1),
        (42, 11.6, 13.1, 14.9, 17.2, 19.8),
        (48, 12.3, 14.0, 16.1, 18.5, 21.5),
        (54, 13.0, 14.8, 17.0, 19.8, 23.2),
        (60, 13.7, 15.8, 18.2, 21.2, 24.9),
        (72, 15.3, 17.7, 20.5, 24.2, 28.8),
        (84, 17.0, 19.9, 23.3, 27.8, 33.5),
        (96, 18.8, 22.2, 26.2, 31.8, 38.8),
        (108, 20.7, 24.7, 29.5, 36.3, 44.5),
        (120, 23.0, 27.6, 33.3, 41.3, 51.0),
    ].map { WHOPercentilePoint(ageInMonths: $0.0, p3: $0.1, p15: $0.2, p50: $0.3, p85: $0.4, p97: $0.5) }

    // MARK: - Boys Weight (kg) — 0–120 months (0–10 years)

    private static let boyWeight: [WHOPercentilePoint] = [
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
        (30, 10.5, 11.8, 13.3, 15.0, 17.0),
        (36, 11.3, 12.7, 14.3, 16.2, 18.3),
        (42, 12.1, 13.6, 15.3, 17.4, 19.7),
        (48, 12.8, 14.5, 16.3, 18.6, 21.2),
        (54, 13.5, 15.3, 17.3, 19.8, 22.7),
        (60, 14.1, 16.0, 18.3, 21.0, 24.2),
        (72, 15.9, 18.1, 20.7, 24.0, 28.0),
        (84, 17.7, 20.2, 23.4, 27.4, 32.3),
        (96, 19.5, 22.5, 26.3, 31.2, 37.2),
        (108, 21.6, 25.1, 29.7, 35.6, 42.8),
        (120, 24.0, 28.0, 33.3, 40.3, 48.8),
    ].map { WHOPercentilePoint(ageInMonths: $0.0, p3: $0.1, p15: $0.2, p50: $0.3, p85: $0.4, p97: $0.5) }

    // MARK: - Girls Height (cm) — 0–228 months (0–19 years)
    // WHO Child Growth Standards (0–60m) + WHO Growth Reference 2007 (61–228m)

    private static let girlHeight: [WHOPercentilePoint] = [
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
        (30, 84.4, 87.9, 91.4, 95.0, 98.5),
        (36, 88.3, 92.1, 95.9, 99.8, 103.6),
        (42, 91.8, 95.8, 99.9, 104.0, 108.0),
        (48, 94.9, 99.2, 103.5, 107.8, 112.1),
        (54, 98.0, 102.4, 106.9, 111.4, 115.9),
        (60, 100.7, 105.4, 110.0, 114.6, 119.3),
        (72, 106.2, 111.3, 116.4, 121.5, 126.6),
        (84, 111.8, 117.3, 122.8, 128.3, 133.8),
        (96, 117.2, 123.1, 129.1, 135.0, 141.0),
        (108, 122.5, 129.0, 135.4, 141.9, 148.3),
        (120, 128.0, 134.8, 141.5, 148.3, 155.0),
        (132, 133.5, 140.5, 147.5, 154.5, 161.5),
        (144, 139.5, 146.5, 153.5, 160.5, 167.5),
        (156, 143.8, 150.3, 156.8, 163.3, 169.8),
        (168, 146.5, 152.5, 158.5, 164.5, 170.5),
        (180, 148.0, 153.8, 159.6, 165.4, 171.2),
        (192, 148.8, 154.5, 160.2, 165.9, 171.6),
        (204, 149.2, 154.8, 160.5, 166.1, 171.8),
        (216, 149.4, 155.0, 160.7, 166.3, 172.0),
        (228, 149.5, 155.1, 160.8, 166.4, 172.1),
    ].map { WHOPercentilePoint(ageInMonths: $0.0, p3: $0.1, p15: $0.2, p50: $0.3, p85: $0.4, p97: $0.5) }

    // MARK: - Boys Height (cm) — 0–228 months (0–19 years)

    private static let boyHeight: [WHOPercentilePoint] = [
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
        (30, 85.8, 89.3, 92.7, 96.2, 99.6),
        (36, 89.5, 93.3, 97.1, 100.9, 104.7),
        (42, 93.0, 97.1, 101.1, 105.2, 109.2),
        (48, 96.2, 100.5, 104.9, 109.2, 113.6),
        (54, 99.2, 103.8, 108.3, 112.9, 117.4),
        (60, 102.0, 106.8, 111.6, 116.4, 121.2),
        (72, 107.7, 113.0, 118.3, 123.5, 128.8),
        (84, 113.0, 118.7, 124.5, 130.2, 136.0),
        (96, 118.1, 124.3, 130.5, 136.8, 143.0),
        (108, 123.0, 129.7, 136.5, 143.2, 150.0),
        (120, 127.8, 135.0, 142.2, 149.4, 156.6),
        (132, 132.5, 140.3, 148.0, 155.8, 163.5),
        (144, 137.8, 146.0, 154.2, 162.5, 170.7),
        (156, 144.0, 152.5, 161.0, 169.5, 178.0),
        (168, 150.5, 158.5, 166.5, 174.5, 182.5),
        (180, 156.0, 163.2, 170.5, 177.7, 185.0),
        (192, 159.8, 166.3, 172.8, 179.4, 185.9),
        (204, 161.8, 168.0, 174.2, 180.4, 186.6),
        (216, 163.0, 169.0, 175.0, 181.0, 187.0),
        (228, 163.5, 169.4, 175.3, 181.2, 187.1),
    ].map { WHOPercentilePoint(ageInMonths: $0.0, p3: $0.1, p15: $0.2, p50: $0.3, p85: $0.4, p97: $0.5) }

    // MARK: - Girls Head Circumference (cm) — 0–60 months (0–5 years)

    private static let girlHead: [WHOPercentilePoint] = [
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
        (18, 43.6, 45.0, 46.5, 47.9, 49.3),
        (24, 44.6, 46.0, 47.5, 49.0, 50.5),
        (30, 45.3, 46.8, 48.3, 49.8, 51.3),
        (36, 45.8, 47.3, 48.9, 50.4, 51.9),
        (42, 46.2, 47.7, 49.3, 50.9, 52.4),
        (48, 46.5, 48.1, 49.7, 51.2, 52.8),
        (54, 46.8, 48.3, 49.9, 51.5, 53.1),
        (60, 47.0, 48.6, 50.2, 51.8, 53.4),
    ].map { WHOPercentilePoint(ageInMonths: $0.0, p3: $0.1, p15: $0.2, p50: $0.3, p85: $0.4, p97: $0.5) }

    // MARK: - Boys Head Circumference (cm) — 0–60 months (0–5 years)

    private static let boyHead: [WHOPercentilePoint] = [
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
        (18, 44.8, 46.1, 47.4, 48.8, 50.1),
        (24, 45.8, 47.1, 48.4, 49.7, 51.0),
        (30, 46.5, 47.8, 49.2, 50.5, 51.8),
        (36, 47.1, 48.4, 49.8, 51.2, 52.5),
        (42, 47.5, 48.9, 50.3, 51.7, 53.0),
        (48, 47.9, 49.3, 50.7, 52.1, 53.5),
        (54, 48.2, 49.6, 51.0, 52.4, 53.9),
        (60, 48.5, 49.9, 51.4, 52.8, 54.2),
    ].map { WHOPercentilePoint(ageInMonths: $0.0, p3: $0.1, p15: $0.2, p50: $0.3, p85: $0.4, p97: $0.5) }
}
