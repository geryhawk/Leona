import SwiftUI
import SwiftData

struct HealthView: View {
    let baby: Baby

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \HealthRecord.startDate, order: .reverse) private var allRecords: [HealthRecord]

    /// Unified sheet presentation to avoid SwiftUI multiple-sheet conflicts
    enum SheetType: Identifiable {
        case add
        case detail(HealthRecord)

        var id: String {
            switch self {
            case .add: return "add"
            case .detail(let record): return record.id.uuidString
            }
        }
    }

    @State private var activeSheet: SheetType?
    @State private var recordToDelete: HealthRecord?
    
    private var babyRecords: [HealthRecord] {
        allRecords.filter { $0.baby?.id == baby.id }
    }
    
    private var activeRecords: [HealthRecord] {
        babyRecords.filter { $0.isOngoing }
    }
    
    private var pastRecords: [HealthRecord] {
        babyRecords.filter { !$0.isOngoing }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Active health issues
                    if !activeRecords.isEmpty {
                        activeHealthSection
                    }
                    
                    // Quick temp check
                    if let latestTemp = activeRecords.compactMap({ $0.latestTemperature }).max() {
                        temperatureAlert(temperature: latestTemp)
                    }
                    
                    // Health history
                    if babyRecords.isEmpty {
                        emptyState
                    } else {
                        healthHistorySection
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(String(localized: "health"))
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        activeSheet = .add
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(.leonaPink)
                    }
                }
            }
            .sheet(item: $activeSheet) { sheet in
                switch sheet {
                case .add:
                    HealthEntryView(baby: baby)
                case .detail(let record):
                    HealthDetailView(record: record)
                }
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
    
    // MARK: - Active Health Issues
    
    private var activeHealthSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(String(localized: "active_health_issues"), systemImage: "exclamationmark.triangle.fill")
                .font(.headline)
                .foregroundStyle(.red)
            
            ForEach(activeRecords) { record in
                HealthRecordRow(record: record, isActive: true) {
                    activeSheet = .detail(record)
                } onDelete: {
                    recordToDelete = record
                }
            }
        }
    }

    // MARK: - Temperature Alert
    
    private func temperatureAlert(temperature: Double) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "thermometer.high")
                .font(.title2)
                .foregroundStyle(temperatureColor(temperature))
            
            VStack(alignment: .leading, spacing: 2) {
                Text(String(localized: "current_temperature"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(String(format: "%.1f°C", temperature))
                    .font(.title2.bold())
                    .foregroundStyle(temperatureColor(temperature))
            }
            
            Spacer()
            
            Text(temperatureLabel(temperature))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(temperatureColor(temperature))
                .clipShape(Capsule())
        }
        .padding()
        .leonaCard()
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "heart.text.clipboard")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            
            Text(String(localized: "health_no_records"))
                .font(.headline)
                .foregroundStyle(.secondary)
            
            Text(String(localized: "health_no_records_desc"))
                .font(.subheadline)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
            
            Button {
                activeSheet = .add
            } label: {
                Label(String(localized: "add_health_record"), systemImage: "plus.circle.fill")
            }
            .buttonStyle(LeonaSecondaryButtonStyle(color: .leonaPink))
        }
        .padding(40)
    }
    
    // MARK: - Health History
    
    private var healthHistorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "health_history"))
                .font(.headline)
                .foregroundStyle(.secondary)
            
            ForEach(pastRecords) { record in
                HealthRecordRow(record: record, isActive: false) {
                    activeSheet = .detail(record)
                } onDelete: {
                    recordToDelete = record
                }
            }
        }
    }
    
    // MARK: - Helpers
    
    private func temperatureColor(_ temp: Double) -> Color {
        if temp >= 39.0 { return .red }
        if temp >= 38.0 { return .orange }
        if temp >= 37.5 { return .yellow }
        return .green
    }
    
    private func temperatureLabel(_ temp: Double) -> String {
        if temp >= 39.0 { return String(localized: "temp_high_fever") }
        if temp >= 38.0 { return String(localized: "temp_fever") }
        if temp >= 37.5 { return String(localized: "temp_elevated") }
        return String(localized: "temp_normal")
    }
}

// MARK: - Health Record Row with swipe-to-delete

private struct HealthRecordRow: View {
    let record: HealthRecord
    let isActive: Bool
    let onTap: () -> Void
    let onDelete: () -> Void

    @State private var offset: CGFloat = 0

    var body: some View {
        ZStack(alignment: .trailing) {
            // Delete background
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

            // Card content
            cardContent
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

    private var cardContent: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: record.illnessType.icon)
                    .font(isActive ? .title2 : .body)
                    .foregroundStyle(record.illnessType.color)
                    .frame(width: isActive ? 44 : 32)

                VStack(alignment: .leading, spacing: 4) {
                    Text(record.illnessType.displayName)
                        .font(.subheadline.weight(isActive ? .semibold : .medium))

                    HStack(spacing: 4) {
                        if isActive {
                            Text(String(localized: "health_since \(record.startDate.dateString)"))
                        } else {
                            Text(record.startDate.dateString)
                            if let end = record.endDate {
                                Text("→")
                                Text(end.dateString)
                            }
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)

                    if isActive, let days = record.durationDays {
                        Text(String(localized: "health_days \(days)"))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.red)
                    }

                    if isActive, let temp = record.latestTemperature {
                        HStack(spacing: 4) {
                            Image(systemName: "thermometer.medium")
                                .font(.caption2)
                            Text(String(format: "%.1f°C", temp))
                                .font(.caption.weight(.semibold))
                        }
                        .foregroundStyle(temp >= 39.0 ? .red : temp >= 38.0 ? .orange : temp >= 37.5 ? .yellow : .green)
                    }
                }

                Spacer()

                if !isActive, let days = record.durationDays {
                    Text(String(localized: "health_days \(days)"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding()
            .background(isActive ? .red.opacity(0.05) : Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                isActive
                    ? RoundedRectangle(cornerRadius: 16).stroke(.red.opacity(0.2), lineWidth: 1)
                    : nil
            )
            .shadow(color: .black.opacity(isActive ? 0 : 0.04), radius: 4, x: 0, y: 1)
        }
        .buttonStyle(.plain)
    }
}
