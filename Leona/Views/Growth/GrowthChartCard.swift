import SwiftUI
import Charts

/// The WHO chart: P3–P97 band, dashed median, and the baby's own line on top.
/// Values are converted to the display unit; ages stay in months.
struct GrowthChartCard: View {
    let baby: Baby
    let metric: GrowthMetric
    let records: [GrowthRecord]

    private var useMetric: Bool { AppSettings.shared.useMetric }

    var body: some View {
        let rawPercentiles = metric.percentiles(gender: baby.gender)
        let rawPoints = babyPoints
        let percentiles = converted(rawPercentiles)
        let points = convertedPoints(rawPoints)
        let xDomain = xDomain(points: rawPoints, percentiles: rawPercentiles)
        let visible = percentiles.filter { $0.ageInMonths <= xDomain.upperBound }
        let yDomain = yDomain(percentiles: visible, points: points)
        let ticks = xTicks(upper: xDomain.upperBound)
        let endP97 = interpolate(percentiles, \.p97, at: xDomain.upperBound)
        let endP3 = interpolate(percentiles, \.p3, at: xDomain.upperBound)

        LeonaCard(padding: EdgeInsets(top: 16, leading: 12, bottom: 12, trailing: 12)) {
            Chart {
                ForEach(visible) { point in
                    AreaMark(
                        x: .value("Age", point.ageInMonths),
                        yStart: .value("P3", point.p3),
                        yEnd: .value("P97", point.p97)
                    )
                    .foregroundStyle(Color.tBandFill)
                    .interpolationMethod(.catmullRom)
                }

                ForEach(visible) { point in
                    LineMark(
                        x: .value("Age", point.ageInMonths),
                        y: .value("Value", point.p50),
                        series: .value("Series", "P50")
                    )
                    .foregroundStyle(Color.tP50)
                    .lineStyle(StrokeStyle(lineWidth: 1.6, dash: [5, 4]))
                    .interpolationMethod(.catmullRom)
                }

                if let endP97, let endP3 {
                    PointMark(x: .value("Age", xDomain.upperBound), y: .value("Value", endP97))
                        .symbolSize(0)
                        .annotation(position: .bottomLeading, spacing: 2) { bandLabel("P97") }
                    PointMark(x: .value("Age", xDomain.upperBound), y: .value("Value", endP3))
                        .symbolSize(0)
                        .annotation(position: .topLeading, spacing: 2) { bandLabel("P3") }
                }

                ForEach(points) { point in
                    LineMark(
                        x: .value("Age", point.ageInMonths),
                        y: .value("Value", point.value),
                        series: .value("Series", "Baby")
                    )
                    .foregroundStyle(Color.vermilion)
                    .lineStyle(StrokeStyle(lineWidth: 3.2, lineCap: .round, lineJoin: .round))
                    .interpolationMethod(.catmullRom)
                }

                ForEach(points) { point in
                    PointMark(
                        x: .value("Age", point.ageInMonths),
                        y: .value("Value", point.value)
                    )
                    .symbol {
                        Circle()
                            .fill(Color.vermilion)
                            .frame(width: 10.4, height: 10.4)
                            .overlay(Circle().stroke(Color.tSurface, lineWidth: 2.4))
                    }
                }
            }
            .chartXScale(domain: xDomain)
            .chartYScale(domain: yDomain)
            .chartYAxis(.hidden)
            .chartXAxis {
                AxisMarks(values: ticks) { value in
                    if let months = value.as(Double.self) {
                        AxisValueLabel(anchor: anchor(for: months, upper: xDomain.upperBound)) {
                            Text(tickLabel(months: months, step: tickStep(upper: xDomain.upperBound)))
                                .font(.leona(10, .bold))
                                .foregroundStyle(.tMuted)
                        }
                    }
                }
            }
            .chartLegend(.hidden)
            .frame(height: 200)
        }
    }

    private func bandLabel(_ text: String) -> some View {
        Text(text)
            .font(.leona(9, .heavy))
            .foregroundStyle(Color.tP50)
    }

    // MARK: - Data

    private var babyPoints: [GrowthChartPoint] {
        records
            .sorted { $0.date < $1.date }
            .compactMap { record in
                guard let age = record.ageInMonthsAtMeasurement, let value = metric.storedValue(of: record) else { return nil }
                return GrowthChartPoint(ageInMonths: max(0, age), value: value, percentile: nil)
            }
    }

    private func converted(_ points: [WHOPercentilePoint]) -> [WHOPercentilePoint] {
        guard !useMetric else { return points }
        return points.map { point in
            WHOPercentilePoint(
                ageInMonths: point.ageInMonths,
                p3: metric.display(point.p3),
                p15: metric.display(point.p15),
                p50: metric.display(point.p50),
                p85: metric.display(point.p85),
                p97: metric.display(point.p97)
            )
        }
    }

    private func convertedPoints(_ points: [GrowthChartPoint]) -> [GrowthChartPoint] {
        guard !useMetric else { return points }
        return points.map { GrowthChartPoint(ageInMonths: $0.ageInMonths, value: metric.display($0.value), percentile: $0.percentile) }
    }

    // MARK: - Domains

    /// Adapt the x domain to the baby's age, capped by the WHO data available.
    private func xDomain(points: [GrowthChartPoint], percentiles: [WHOPercentilePoint]) -> ClosedRange<Double> {
        let maxDataAge = points.map(\.ageInMonths).max() ?? 0
        let babyAge = max(maxDataAge, max(0, baby.ageInMonths))
        let maxWHO = percentiles.map(\.ageInMonths).max() ?? 24

        let rawUpper: Double
        if babyAge <= 1 {
            rawUpper = 3
        } else if babyAge <= 3 {
            rawUpper = 6
        } else if babyAge <= 6 {
            rawUpper = 9
        } else if babyAge <= 12 {
            rawUpper = babyAge + 3
        } else {
            rawUpper = babyAge * 1.15 + 3
        }

        let upper: Double
        if rawUpper <= 6 {
            upper = ceil(rawUpper)
        } else if rawUpper <= 24 {
            upper = ceil(rawUpper / 3) * 3
        } else if rawUpper <= 60 {
            upper = ceil(rawUpper / 6) * 6
        } else {
            upper = ceil(rawUpper / 12) * 12
        }
        return 0...max(1, min(upper, maxWHO))
    }

    private func yDomain(percentiles: [WHOPercentilePoint], points: [GrowthChartPoint]) -> ClosedRange<Double> {
        let whoMin = percentiles.map(\.p3).min() ?? 0
        let whoMax = percentiles.map(\.p97).max() ?? 100
        let low = min(whoMin, points.map(\.value).min() ?? whoMin)
        let high = max(whoMax, points.map(\.value).max() ?? whoMax)
        let padding = max((high - low) * 0.08, 0.1)
        return max(0, low - padding)...(high + padding)
    }

    // MARK: - Axis

    private func tickStep(upper: Double) -> Double {
        if upper <= 3 { return 1 }
        if upper <= 12 { return 3 }
        if upper <= 36 { return 6 }
        return 12
    }

    private func xTicks(upper: Double) -> [Double] {
        let step = tickStep(upper: upper)
        var ticks = Array(stride(from: 0.0, through: upper, by: step))
        if let last = ticks.last, upper - last >= step * 0.4 { ticks.append(upper) }
        return ticks
    }

    private func tickLabel(months: Double, step: Double) -> String {
        if months == 0 { return String(localized: "growth_axis_birth") }
        if step >= 12 {
            let years = months / 12
            let text = years == floor(years) ? String(Int(years)) : String(format: "%.1f", years)
            return String(localized: "growth_axis_years \(text)")
        }
        return String(localized: "growth_axis_months \(Int(months.rounded()))")
    }

    private func anchor(for months: Double, upper: Double) -> UnitPoint {
        if months == 0 { return .topLeading }
        if months >= upper { return .topTrailing }
        return .top
    }

    private func interpolate(_ points: [WHOPercentilePoint], _ keyPath: KeyPath<WHOPercentilePoint, Double>, at age: Double) -> Double? {
        guard let lower = points.last(where: { $0.ageInMonths <= age }),
              let upper = points.first(where: { $0.ageInMonths >= age }) else { return nil }
        if lower.ageInMonths == upper.ageInMonths { return lower[keyPath: keyPath] }
        let ratio = (age - lower.ageInMonths) / (upper.ageInMonths - lower.ageInMonths)
        return lower[keyPath: keyPath] + (upper[keyPath: keyPath] - lower[keyPath: keyPath]) * ratio
    }
}
