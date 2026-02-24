import SwiftUI
import SwiftData
import Charts

struct GrowthView: View {
    let baby: Baby

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \GrowthRecord.date, order: .reverse) private var allRecords: [GrowthRecord]

    @State private var showAddRecord = false
    @State private var selectedChart: GrowthChartType = .weight
    @State private var editingRecord: GrowthRecord?
    @State private var recordToDelete: GrowthRecord?
    @State private var chartScale: CGFloat = 1.0
    @State private var lastChartScale: CGFloat = 1.0

    private var settings: AppSettings { AppSettings.shared }

    private var babyRecords: [GrowthRecord] {
        allRecords.filter { $0.baby?.id == baby.id }
    }

    enum GrowthChartType: String, CaseIterable, Identifiable {
        case weight, height, headCircumference

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .weight: return String(localized: "growth_weight")
            case .height: return String(localized: "growth_height")
            case .headCircumference: return String(localized: "growth_head")
            }
        }

        var unit: String {
            switch self {
            case .weight: return UnitConversion.weightUnit
            case .height, .headCircumference: return UnitConversion.heightUnit
            }
        }

        var icon: String {
            switch self {
            case .weight: return "scalemass.fill"
            case .height: return "ruler.fill"
            case .headCircumference: return "circle.dashed"
            }
        }

        var color: Color {
            switch self {
            case .weight: return Color(red: 0.35, green: 0.55, blue: 0.9)
            case .height: return Color(red: 0.3, green: 0.75, blue: 0.55)
            case .headCircumference: return Color(red: 0.6, green: 0.45, blue: 0.85)
            }
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    latestMeasurementsCard
                    chartTypeSelector
                    growthChart
                    recordsList
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(String(localized: "growth"))
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showAddRecord = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(.leonaPink)
                    }
                }
            }
            .sheet(isPresented: $showAddRecord) {
                GrowthEntryView(baby: baby)
            }
            .sheet(item: $editingRecord) { record in
                GrowthEntryView(baby: baby, editingRecord: record)
            }
            .alert(String(localized: "delete_record"), isPresented: Binding<Bool>(
                get: { recordToDelete != nil },
                set: { if !$0 { recordToDelete = nil } }
            )) {
                Button(String(localized: "delete"), role: .destructive) {
                    if let record = recordToDelete {
                        modelContext.delete(record)
                        try? modelContext.save()
                    }
                    recordToDelete = nil
                }
                Button(String(localized: "cancel"), role: .cancel) {
                    recordToDelete = nil
                }
            } message: {
                Text(String(localized: "delete_record_message"))
            }
        }
    }

    // MARK: - Latest Measurements

    private var latestMeasurementsCard: some View {
        Group {
            if let latest = babyRecords.first {
                VStack(spacing: 16) {
                    HStack {
                        Text(String(localized: "latest_measurements"))
                            .font(.headline)
                        Spacer()
                        Text(latest.date.dateString)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    HStack(spacing: 16) {
                        if let weight = latest.weightKg {
                            let display = UnitConversion.displayWeight(weight)
                            measurementPill(
                                icon: "scalemass.fill",
                                value: String(format: "%.2f", display),
                                unit: UnitConversion.weightUnit,
                                color: .blue,
                                percentile: calculatePercentile(value: weight, type: .weight)
                            )
                        }

                        if let height = latest.heightCm {
                            let display = UnitConversion.displayHeight(height)
                            measurementPill(
                                icon: "ruler.fill",
                                value: String(format: "%.1f", display),
                                unit: UnitConversion.heightUnit,
                                color: .green,
                                percentile: calculatePercentile(value: height, type: .height)
                            )
                        }

                        if let head = latest.headCircumferenceCm {
                            let display = UnitConversion.displayHeight(head)
                            measurementPill(
                                icon: "circle.dashed",
                                value: String(format: "%.1f", display),
                                unit: UnitConversion.heightUnit,
                                color: .purple,
                                percentile: calculatePercentile(value: head, type: .headCircumference)
                            )
                        }
                    }
                }
                .padding()
                .leonaCard()
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)

                    Text(String(localized: "growth_no_records"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Button {
                        showAddRecord = true
                    } label: {
                        Label(String(localized: "add_measurement"), systemImage: "plus.circle.fill")
                    }
                    .buttonStyle(LeonaSecondaryButtonStyle(color: .leonaPink))
                }
                .padding(32)
                .frame(maxWidth: .infinity)
                .leonaCard()
            }
        }
    }

    private func measurementPill(icon: String, value: String, unit: String, color: Color, percentile: Double?) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(color)

            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.headline.monospacedDigit())
                Text(unit)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let p = percentile {
                Text("P\(Int(p))")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(percentileColor(p))
                    .clipShape(Capsule())
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Chart Type Selector

    private var chartTypeSelector: some View {
        Picker(String(localized: "chart_type"), selection: $selectedChart) {
            ForEach(GrowthChartType.allCases) { type in
                Label(type.displayName, systemImage: type.icon).tag(type)
            }
        }
        .pickerStyle(.segmented)
    }

    // MARK: - Growth Chart

    private var growthChart: some View {
        let rawPercentiles = whoPercentiles(for: selectedChart)
        let rawBabyPoints = chartPoints(for: selectedChart)

        // Convert to display units (imperial if needed)
        let percentiles = convertedPercentiles(rawPercentiles)
        let babyPoints = convertedBabyPoints(rawBabyPoints)

        let chartColor = selectedChart.color
        let xDomain = chartXDomain(babyPoints: rawBabyPoints, percentiles: rawPercentiles)
        let yDomain = chartYDomain(percentiles: percentiles, babyPoints: babyPoints, xDomain: xDomain)
        let useYears = xDomain.upperBound > 36

        return VStack(alignment: .leading, spacing: 12) {
            // Chart header
            HStack(alignment: .firstTextBaseline) {
                Text(selectedChart.displayName)
                    .font(.headline)
                Text("(\(selectedChart.unit))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                if let lastPoint = babyPoints.last {
                    Text(String(format: selectedChart == .weight ? "%.2f" : "%.1f", lastPoint.value))
                        .font(.title3.weight(.semibold).monospacedDigit())
                        .foregroundStyle(chartColor)
                    + Text(" \(selectedChart.unit)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Chart {
                // === WHO bands — 6 discrete non-overlapping fills ===

                // Band 1: Bottom edge → P3 (very light)
                ForEach(percentiles) { point in
                    AreaMark(
                        x: .value("Age", point.ageInMonths),
                        yStart: .value("Bottom", yDomain.lowerBound),
                        yEnd: .value("P3", point.p3)
                    )
                    .foregroundStyle(chartColor.opacity(0.03))
                    .interpolationMethod(.catmullRom)
                }

                // Band 2: P3 → P15 (light)
                ForEach(percentiles) { point in
                    AreaMark(
                        x: .value("Age", point.ageInMonths),
                        yStart: .value("P3", point.p3),
                        yEnd: .value("P15", point.p15)
                    )
                    .foregroundStyle(chartColor.opacity(0.06))
                    .interpolationMethod(.catmullRom)
                }

                // Band 3: P15 → P50 (medium)
                ForEach(percentiles) { point in
                    AreaMark(
                        x: .value("Age", point.ageInMonths),
                        yStart: .value("P15", point.p15),
                        yEnd: .value("P50", point.p50)
                    )
                    .foregroundStyle(chartColor.opacity(0.10))
                    .interpolationMethod(.catmullRom)
                }

                // Band 4: P50 → P85 (medium)
                ForEach(percentiles) { point in
                    AreaMark(
                        x: .value("Age", point.ageInMonths),
                        yStart: .value("P50", point.p50),
                        yEnd: .value("P85", point.p85)
                    )
                    .foregroundStyle(chartColor.opacity(0.10))
                    .interpolationMethod(.catmullRom)
                }

                // Band 5: P85 → P97 (light)
                ForEach(percentiles) { point in
                    AreaMark(
                        x: .value("Age", point.ageInMonths),
                        yStart: .value("P85", point.p85),
                        yEnd: .value("P97", point.p97)
                    )
                    .foregroundStyle(chartColor.opacity(0.06))
                    .interpolationMethod(.catmullRom)
                }

                // Band 6: P97 → Top edge (very light)
                ForEach(percentiles) { point in
                    AreaMark(
                        x: .value("Age", point.ageInMonths),
                        yStart: .value("P97", point.p97),
                        yEnd: .value("Top", yDomain.upperBound)
                    )
                    .foregroundStyle(chartColor.opacity(0.03))
                    .interpolationMethod(.catmullRom)
                }

                // === Percentile lines ===

                // P3 line
                ForEach(percentiles) { point in
                    LineMark(
                        x: .value("Age", point.ageInMonths),
                        y: .value("Value", point.p3),
                        series: .value("Series", "P3")
                    )
                    .foregroundStyle(chartColor.opacity(0.25))
                    .lineStyle(StrokeStyle(lineWidth: 0.7, dash: [3, 4]))
                    .interpolationMethod(.catmullRom)
                }

                // P15 line
                ForEach(percentiles) { point in
                    LineMark(
                        x: .value("Age", point.ageInMonths),
                        y: .value("Value", point.p15),
                        series: .value("Series", "P15")
                    )
                    .foregroundStyle(chartColor.opacity(0.30))
                    .lineStyle(StrokeStyle(lineWidth: 0.7, dash: [3, 3]))
                    .interpolationMethod(.catmullRom)
                }

                // P50 median line (most prominent)
                ForEach(percentiles) { point in
                    LineMark(
                        x: .value("Age", point.ageInMonths),
                        y: .value("Value", point.p50),
                        series: .value("Series", "P50")
                    )
                    .foregroundStyle(chartColor.opacity(0.50))
                    .lineStyle(StrokeStyle(lineWidth: 1.2, dash: [5, 4]))
                    .interpolationMethod(.catmullRom)
                }

                // P85 line
                ForEach(percentiles) { point in
                    LineMark(
                        x: .value("Age", point.ageInMonths),
                        y: .value("Value", point.p85),
                        series: .value("Series", "P85")
                    )
                    .foregroundStyle(chartColor.opacity(0.30))
                    .lineStyle(StrokeStyle(lineWidth: 0.7, dash: [3, 3]))
                    .interpolationMethod(.catmullRom)
                }

                // P97 line
                ForEach(percentiles) { point in
                    LineMark(
                        x: .value("Age", point.ageInMonths),
                        y: .value("Value", point.p97),
                        series: .value("Series", "P97")
                    )
                    .foregroundStyle(chartColor.opacity(0.25))
                    .lineStyle(StrokeStyle(lineWidth: 0.7, dash: [3, 4]))
                    .interpolationMethod(.catmullRom)
                }

                // === Baby's data ===

                // Baby's curve — area fill (clamped between P3 and baby's value)
                if babyPoints.count >= 2 {
                    ForEach(babyPoints) { point in
                        let p3AtAge = interpolatedP3(at: point.ageInMonths, percentiles: percentiles)
                        AreaMark(
                            x: .value("Age", point.ageInMonths),
                            yStart: .value("Floor", p3AtAge),
                            yEnd: .value("Value", point.value)
                        )
                        .foregroundStyle(chartColor.opacity(0.15))
                        .interpolationMethod(.catmullRom)
                    }
                }

                // Baby's curve — main line
                ForEach(babyPoints) { point in
                    LineMark(
                        x: .value("Age", point.ageInMonths),
                        y: .value("Value", point.value),
                        series: .value("Series", "Baby")
                    )
                    .foregroundStyle(chartColor.gradient)
                    .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                    .interpolationMethod(.catmullRom)
                }

                // Data points with shadow glow
                ForEach(babyPoints) { point in
                    PointMark(
                        x: .value("Age", point.ageInMonths),
                        y: .value("Value", point.value)
                    )
                    .foregroundStyle(.white)
                    .symbolSize(30)

                    PointMark(
                        x: .value("Age", point.ageInMonths),
                        y: .value("Value", point.value)
                    )
                    .foregroundStyle(chartColor.gradient)
                    .symbolSize(50)
                    .symbol {
                        Circle()
                            .fill(chartColor.gradient)
                            .frame(width: 8, height: 8)
                            .shadow(color: chartColor.opacity(0.5), radius: 4)
                    }
                }
            }
            .chartXScale(domain: xDomain)
            .chartYScale(domain: yDomain)
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 6)) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.3))
                        .foregroundStyle(Color.secondary.opacity(0.3))
                    AxisTick(stroke: StrokeStyle(lineWidth: 0.3))
                        .foregroundStyle(Color.secondary.opacity(0.3))
                    AxisValueLabel {
                        if let v = value.as(Double.self) {
                            Text(ageLabel(months: v, useYears: useYears))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 5)) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.3))
                        .foregroundStyle(Color.secondary.opacity(0.2))
                    AxisValueLabel {
                        if let v = value.as(Double.self) {
                            Text(selectedChart == .weight ? String(format: "%.1f", v) : String(format: "%.0f", v))
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
            }
            .frame(height: max(300, 300 * chartScale))
            .padding(.top, 8)
            .padding(.bottom, 4)
            .padding(.horizontal, 4)
            .gesture(
                MagnifyGesture()
                    .onChanged { value in
                        let newScale = lastChartScale * value.magnification
                        chartScale = min(max(newScale, 1.0), 3.0)
                    }
                    .onEnded { _ in
                        lastChartScale = chartScale
                    }
            )
            .animation(.easeInOut(duration: 0.2), value: chartScale)

            // Legend
            HStack(spacing: 16) {
                legendItem(color: chartColor, label: baby.displayName)
                legendItem(color: chartColor.opacity(0.50), label: "P50", dashed: true)
                legendItem(color: chartColor.opacity(0.18), label: "P3–P97", isFill: true)
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 4)

            if chartScale > 1.0 {
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        chartScale = 1.0
                        lastChartScale = 1.0
                    }
                } label: {
                    Label(String(localized: "reset_zoom"), systemImage: "arrow.down.right.and.arrow.up.left")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 4)
            }
        }
        .padding(16)
        .leonaCard()
    }

    // MARK: - Chart Domain Helpers

    /// Adapt X domain to baby's age — scales with available WHO data
    private func chartXDomain(babyPoints: [GrowthChartPoint], percentiles: [WHOPercentilePoint]) -> ClosedRange<Double> {
        let maxDataAge = babyPoints.map(\.ageInMonths).max() ?? 0
        let babyAge = max(maxDataAge, baby.ageInMonths)
        let maxWHO = percentiles.map(\.ageInMonths).max() ?? 24

        // Show a bit ahead of baby's age, minimum 12 months
        let rawUpper = max(12, babyAge * 1.2 + 3)

        // Round to nice intervals
        let upper: Double
        if rawUpper <= 24 {
            upper = ceil(rawUpper / 3) * 3       // round to nearest 3 months
        } else if rawUpper <= 60 {
            upper = ceil(rawUpper / 6) * 6       // round to nearest 6 months
        } else {
            upper = ceil(rawUpper / 12) * 12     // round to nearest year
        }

        return 0...min(upper, maxWHO)
    }

    /// Adapt Y domain: encompass WHO bands and baby data with some breathing room
    private func chartYDomain(percentiles: [WHOPercentilePoint], babyPoints: [GrowthChartPoint], xDomain: ClosedRange<Double>) -> ClosedRange<Double> {
        let relevantPercentiles = percentiles.filter { $0.ageInMonths <= xDomain.upperBound }
        let whoMin = relevantPercentiles.map(\.p3).min() ?? 0
        let whoMax = relevantPercentiles.map(\.p97).max() ?? 100
        let dataMin = babyPoints.map(\.value).min() ?? whoMin
        let dataMax = babyPoints.map(\.value).max() ?? whoMax
        let low = min(whoMin, dataMin)
        let high = max(whoMax, dataMax)
        let padding = (high - low) * 0.08
        return max(0, low - padding)...(high + padding)
    }

    /// Format age label: months for short ranges, years for longer ranges
    private func ageLabel(months: Double, useYears: Bool) -> String {
        if useYears {
            let years = months / 12
            if years == floor(years) {
                return "\(Int(years))y"
            }
            return String(format: "%.1fy", years)
        } else {
            return "\(Int(months))m"
        }
    }

    // MARK: - Unit Conversion for Chart Data

    /// Convert WHO percentile values to display units
    private func convertedPercentiles(_ points: [WHOPercentilePoint]) -> [WHOPercentilePoint] {
        guard !settings.useMetric else { return points }
        let convert: (Double) -> Double = selectedChart == .weight
            ? UnitConversion.kgToLbs
            : UnitConversion.cmToInches
        return points.map { point in
            WHOPercentilePoint(
                ageInMonths: point.ageInMonths,
                p3: convert(point.p3),
                p15: convert(point.p15),
                p50: convert(point.p50),
                p85: convert(point.p85),
                p97: convert(point.p97)
            )
        }
    }

    /// Convert baby measurement points to display units
    private func convertedBabyPoints(_ points: [GrowthChartPoint]) -> [GrowthChartPoint] {
        guard !settings.useMetric else { return points }
        let convert: (Double) -> Double = selectedChart == .weight
            ? UnitConversion.kgToLbs
            : UnitConversion.cmToInches
        return points.map {
            GrowthChartPoint(ageInMonths: $0.ageInMonths, value: convert($0.value), percentile: $0.percentile)
        }
    }

    private func legendItem(color: Color, label: String, dashed: Bool = false, isFill: Bool = false) -> some View {
        HStack(spacing: 4) {
            if isFill {
                RoundedRectangle(cornerRadius: 2)
                    .fill(color)
                    .frame(width: 16, height: 8)
            } else if dashed {
                Rectangle()
                    .fill(color)
                    .frame(width: 16, height: 1)
                    .overlay(
                        Rectangle()
                            .stroke(color, style: StrokeStyle(lineWidth: 1, dash: [3, 2]))
                            .frame(height: 1)
                    )
            } else {
                Capsule()
                    .fill(color)
                    .frame(width: 16, height: 3)
            }
            Text(label)
        }
    }

    /// Interpolate P3 value at a given age from percentile data points
    private func interpolatedP3(at age: Double, percentiles: [WHOPercentilePoint]) -> Double {
        guard !percentiles.isEmpty else { return 0 }
        // Find surrounding points
        if let exact = percentiles.first(where: { $0.ageInMonths == age }) {
            return exact.p3
        }
        guard let upper = percentiles.first(where: { $0.ageInMonths > age }),
              let lowerIdx = percentiles.lastIndex(where: { $0.ageInMonths < age }) else {
            return percentiles.first?.p3 ?? 0
        }
        let lower = percentiles[lowerIdx]
        let ratio = (age - lower.ageInMonths) / (upper.ageInMonths - lower.ageInMonths)
        return lower.p3 + (upper.p3 - lower.p3) * ratio
    }

    // MARK: - Records List

    private var recordsList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "all_measurements"))
                .font(.headline)
                .foregroundStyle(.secondary)

            ForEach(babyRecords) { record in
                GrowthRecordRow(record: record) {
                    editingRecord = record
                } onDelete: {
                    recordToDelete = record
                }
            }
        }
    }

    // MARK: - Helpers

    private func whoPercentiles(for type: GrowthChartType) -> [WHOPercentilePoint] {
        switch type {
        case .weight: return WHODataService.weightPercentiles(gender: baby.gender)
        case .height: return WHODataService.heightPercentiles(gender: baby.gender)
        case .headCircumference: return WHODataService.headCircumferencePercentiles(gender: baby.gender)
        }
    }

    private func chartPoints(for type: GrowthChartType) -> [GrowthChartPoint] {
        babyRecords
            .sorted { $0.date < $1.date }
            .compactMap { record in
                guard let age = record.ageInMonthsAtMeasurement else { return nil }
                let value: Double?
                switch type {
                case .weight: value = record.weightKg
                case .height: value = record.heightCm
                case .headCircumference: value = record.headCircumferenceCm
                }
                guard let v = value else { return nil }
                return GrowthChartPoint(ageInMonths: age, value: v, percentile: nil)
            }
    }

    private func calculatePercentile(value: Double, type: GrowthChartType) -> Double? {
        let data = whoPercentiles(for: type)
        return WHODataService.calculatePercentile(
            value: value,
            ageInMonths: baby.ageInMonths,
            data: data
        )
    }

    private func percentileColor(_ percentile: Double) -> Color {
        if percentile < 3 || percentile > 97 { return .red }
        if percentile < 15 || percentile > 85 { return .orange }
        return .green
    }
}

// MARK: - Growth Record Row with swipe-to-delete

private struct GrowthRecordRow: View {
    let record: GrowthRecord
    let onTap: () -> Void
    let onDelete: () -> Void

    @State private var offset: CGFloat = 0

    var body: some View {
        ZStack(alignment: .trailing) {
            HStack {
                Spacer()
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Image(systemName: "trash.fill")
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .frame(width: 80)
                .background(.red)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }

            cardContent
                .offset(x: offset)
                .simultaneousGesture(swipeGesture)
        }
    }

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 20, coordinateSpace: .local)
            .onChanged { value in
                let horizontal = abs(value.translation.width)
                let vertical = abs(value.translation.height)
                guard horizontal > vertical else { return }
                if value.translation.width < 0 {
                    offset = max(value.translation.width, -80)
                }
            }
            .onEnded { value in
                withAnimation(.spring(response: 0.3)) {
                    offset = value.translation.width < -40 ? -80 : 0
                }
            }
    }

    private var cardContent: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(record.date.dateString)
                    .font(.subheadline.weight(.semibold))

                if let age = record.ageInMonthsAtMeasurement {
                    Text(String(localized: "growth_age_months \(String(format: "%.1f", age))"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                if let w = record.weightKg {
                    Text(UnitConversion.formatWeight(w))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.blue)
                }
                if let h = record.heightCm {
                    Text(UnitConversion.formatHeight(h))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.green)
                }
                if let hc = record.headCircumferenceCm {
                    Text(UnitConversion.formatHeight(hc))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.purple)
                }
            }

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 1)
        .onTapGesture {
            if offset < 0 {
                withAnimation(.spring(response: 0.3)) { offset = 0 }
            } else {
                onTap()
            }
        }
    }
}
