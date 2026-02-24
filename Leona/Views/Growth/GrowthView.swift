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
            case .weight: return "kg"
            case .height: return "cm"
            case .headCircumference: return "cm"
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
            case .weight: return .blue
            case .height: return .green
            case .headCircumference: return .purple
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Latest measurements card
                    latestMeasurementsCard
                    
                    // Chart type selector
                    chartTypeSelector
                    
                    // Growth chart with WHO percentiles
                    growthChart
                    
                    // Records list
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
                            measurementPill(
                                icon: "scalemass.fill",
                                value: String(format: "%.2f", weight),
                                unit: "kg",
                                color: .blue,
                                percentile: calculatePercentile(value: weight, type: .weight)
                            )
                        }
                        
                        if let height = latest.heightCm {
                            measurementPill(
                                icon: "ruler.fill",
                                value: String(format: "%.1f", height),
                                unit: "cm",
                                color: .green,
                                percentile: calculatePercentile(value: height, type: .height)
                            )
                        }
                        
                        if let head = latest.headCircumferenceCm {
                            measurementPill(
                                icon: "circle.dashed",
                                value: String(format: "%.1f", head),
                                unit: "cm",
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
        VStack(alignment: .leading, spacing: 8) {
            Text("\(selectedChart.displayName) (\(selectedChart.unit))")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            
            let percentiles = whoPercentiles(for: selectedChart)
            let babyPoints = chartPoints(for: selectedChart)
            
            Chart {
                // WHO percentile bands
                ForEach(percentiles) { point in
                    AreaMark(
                        x: .value("Age", point.ageInMonths),
                        yStart: .value("P3", point.p3),
                        yEnd: .value("P97", point.p97)
                    )
                    .foregroundStyle(selectedChart.color.opacity(0.06))
                    
                    AreaMark(
                        x: .value("Age", point.ageInMonths),
                        yStart: .value("P15", point.p15),
                        yEnd: .value("P85", point.p85)
                    )
                    .foregroundStyle(selectedChart.color.opacity(0.08))
                    
                    // P50 line (median)
                    LineMark(
                        x: .value("Age", point.ageInMonths),
                        y: .value("P50", point.p50)
                    )
                    .foregroundStyle(selectedChart.color.opacity(0.3))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    
                    // P3 line
                    LineMark(
                        x: .value("Age", point.ageInMonths),
                        y: .value("P3", point.p3)
                    )
                    .foregroundStyle(selectedChart.color.opacity(0.2))
                    .lineStyle(StrokeStyle(lineWidth: 0.5, dash: [2, 2]))
                    
                    // P97 line
                    LineMark(
                        x: .value("Age", point.ageInMonths),
                        y: .value("P97", point.p97)
                    )
                    .foregroundStyle(selectedChart.color.opacity(0.2))
                    .lineStyle(StrokeStyle(lineWidth: 0.5, dash: [2, 2]))
                }
                
                // Baby's data points
                ForEach(babyPoints) { point in
                    LineMark(
                        x: .value("Age", point.ageInMonths),
                        y: .value("Value", point.value)
                    )
                    .foregroundStyle(selectedChart.color)
                    .lineStyle(StrokeStyle(lineWidth: 2.5))
                    .interpolationMethod(.catmullRom)
                    
                    PointMark(
                        x: .value("Age", point.ageInMonths),
                        y: .value("Value", point.value)
                    )
                    .foregroundStyle(selectedChart.color)
                    .symbolSize(40)
                }
            }
            .chartXAxisLabel(String(localized: "chart_age_months"))
            .chartYAxisLabel(selectedChart.unit)
            .chartXScale(domain: 0...24)
            .frame(height: 280)
            .padding()
            .leonaCard()
            
            // Legend
            HStack(spacing: 16) {
                legendItem(color: selectedChart.color, label: baby.displayName)
                legendItem(color: selectedChart.color.opacity(0.3), label: "P50", dashed: true)
                legendItem(color: selectedChart.color.opacity(0.1), label: "P3-P97", isFill: true)
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
    }
    
    private func legendItem(color: Color, label: String, dashed: Bool = false, isFill: Bool = false) -> some View {
        HStack(spacing: 4) {
            if isFill {
                RoundedRectangle(cornerRadius: 2)
                    .fill(color)
                    .frame(width: 16, height: 8)
            } else {
                Rectangle()
                    .fill(color)
                    .frame(width: 16, height: dashed ? 1 : 2)
            }
            Text(label)
        }
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
                        .frame(width: 60)
                }
                .frame(width: 80, height: 70)
                .background(.red)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }

            Button(action: onTap) {
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
                            Text("\(String(format: "%.2f", w)) kg")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.blue)
                        }
                        if let h = record.heightCm {
                            Text("\(String(format: "%.1f", h)) cm")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.green)
                        }
                        if let hc = record.headCircumferenceCm {
                            Text("\(String(format: "%.1f", hc)) cm")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.purple)
                        }
                    }

                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .padding()
                .leonaCard()
            }
            .buttonStyle(.plain)
            .offset(x: offset)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        if value.translation.width < 0 {
                            offset = max(value.translation.width, -80)
                        }
                    }
                    .onEnded { value in
                        withAnimation(.spring(response: 0.3)) {
                            offset = value.translation.width < -40 ? -80 : 0
                        }
                    }
            )
        }
    }
}
