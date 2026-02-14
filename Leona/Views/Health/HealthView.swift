import SwiftUI
import SwiftData

struct HealthView: View {
    let baby: Baby
    
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \HealthRecord.startDate, order: .reverse) private var allRecords: [HealthRecord]
    
    @State private var showAddRecord = false
    @State private var editingRecord: HealthRecord?
    @State private var recordToDelete: HealthRecord?
    @State private var showDeleteConfirm = false
    
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
                        showAddRecord = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(.leonaPink)
                    }
                }
            }
            .sheet(isPresented: $showAddRecord) {
                HealthEntryView(baby: baby)
            }
            .sheet(item: $editingRecord) { record in
                HealthDetailView(record: record)
            }
            .alert(String(localized: "delete_record"), isPresented: $showDeleteConfirm) {
                Button(String(localized: "delete"), role: .destructive) {
                    if let record = recordToDelete {
                        modelContext.delete(record)
                        try? modelContext.save()
                        recordToDelete = nil
                    }
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
                Button {
                    editingRecord = record
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: record.illnessType.icon)
                            .font(.title2)
                            .foregroundStyle(record.illnessType.color)
                            .frame(width: 44)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(record.illnessType.displayName)
                                .font(.subheadline.weight(.semibold))
                            
                            HStack(spacing: 8) {
                                Text(String(localized: "health_since \(record.startDate.dateString)"))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                
                                if let days = record.durationDays {
                                    Text(String(localized: "health_days \(days)"))
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.red)
                                }
                            }
                            
                            if let temp = record.latestTemperature {
                                HStack(spacing: 4) {
                                    Image(systemName: "thermometer.medium")
                                        .font(.caption2)
                                    Text(String(format: "%.1f°C", temp))
                                        .font(.caption.weight(.semibold))
                                }
                                .foregroundStyle(temperatureColor(temp))
                            }
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .padding()
                    .background(.red.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(.red.opacity(0.2), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .contextMenu {
                    Button(role: .destructive) {
                        recordToDelete = record
                        showDeleteConfirm = true
                    } label: {
                        Label(String(localized: "delete"), systemImage: "trash")
                    }
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
                showAddRecord = true
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
                Button {
                    editingRecord = record
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: record.illnessType.icon)
                            .foregroundStyle(record.illnessType.color)
                            .frame(width: 32)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(record.illnessType.displayName)
                                .font(.subheadline.weight(.medium))
                            
                            HStack(spacing: 4) {
                                Text(record.startDate.dateString)
                                if let end = record.endDate {
                                    Text("→")
                                    Text(end.dateString)
                                }
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                        
                        if let days = record.durationDays {
                            Text(String(localized: "health_days \(days)"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .padding()
                    .leonaCard()
                }
                .buttonStyle(.plain)
                .contextMenu {
                    Button(role: .destructive) {
                        recordToDelete = record
                        showDeleteConfirm = true
                    } label: {
                        Label(String(localized: "delete"), systemImage: "trash")
                    }
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
