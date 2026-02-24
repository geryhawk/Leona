import SwiftUI
import SwiftData

struct ActivityCardView: View {
    let activity: Activity
    
    @Environment(\.modelContext) private var modelContext
    @State private var showEditSheet = false
    @State private var showDeleteConfirmation = false
    @State private var offset: CGFloat = 0
    
    var body: some View {
        ZStack(alignment: .trailing) {
            // Delete background
            HStack {
                Spacer()
                
                Button(role: .destructive) {
                    showDeleteConfirmation = true
                } label: {
                    Image(systemName: "trash.fill")
                        .foregroundStyle(.white)
                        .frame(width: 60)
                }
                .frame(width: 80, height: 70)
                .background(.red)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            
            // Main card
            mainCardContent
                .offset(x: offset)
                .simultaneousGesture(swipeGesture)
        }
        .sheet(isPresented: $showEditSheet) {
            EditActivityView(activity: activity)
        }
        .confirmationDialog(
            String(localized: "delete_activity_confirm"),
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button(String(localized: "delete"), role: .destructive) {
                withAnimation {
                    modelContext.delete(activity)
                    try? modelContext.save()
                }
            }
        }
    }
    
    private var mainCardContent: some View {
        HStack(spacing: 14) {
            // Activity icon
            ZStack {
                if activity.type == .sleep {
                    Circle()
                        .fill(activity.type.color.gradient)
                        .frame(width: 44, height: 44)
                    Image(systemName: activity.type.icon)
                        .font(.body)
                        .foregroundStyle(.white)
                        .shadow(color: .white.opacity(0.8), radius: 6)
                        .if(activity.isOngoing) { view in
                            view.symbolEffect(.pulse, options: .repeating)
                        }
                } else if activity.type == .diaper, let diaperType = activity.diaperType {
                    Circle()
                        .fill(diaperType.color.opacity(0.15))
                        .frame(width: 44, height: 44)
                    Image(systemName: diaperType.icon)
                        .font(.body)
                        .foregroundStyle(diaperType.color)
                } else {
                    Circle()
                        .fill(activity.type.color.opacity(0.15))
                        .frame(width: 44, height: 44)
                    Image(systemName: activity.type.icon)
                        .font(.body)
                        .foregroundStyle(activity.type.color)
                }
            }
            
            // Activity details
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(activity.type.displayName)
                        .font(.subheadline.weight(.semibold))
                    
                    if activity.isOngoing {
                        Text(String(localized: "ongoing"))
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(activity.type.color)
                            .clipShape(Capsule())
                    }
                }
                
                Text(activity.summaryText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            
            Spacer()
            
            // Time
            VStack(alignment: .trailing, spacing: 2) {
                Text(activity.startTime.timeString)
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.primary)
                
                if let end = activity.endTime {
                    Text(end.timeString)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 1)
        .onTapGesture {
            showEditSheet = true
        }
    }
    
    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 20, coordinateSpace: .local)
            .onChanged { value in
                // Only handle horizontal swipes (ignore vertical to let ScrollView work)
                let horizontal = abs(value.translation.width)
                let vertical = abs(value.translation.height)
                guard horizontal > vertical else { return }
                if value.translation.width < 0 {
                    offset = max(value.translation.width, -80)
                }
            }
            .onEnded { value in
                withAnimation(.spring(response: 0.3)) {
                    if value.translation.width < -40 {
                        offset = -80
                    } else {
                        offset = 0
                    }
                }
            }
    }
}

// MARK: - Edit Activity View

struct EditActivityView: View {
    @Bindable var activity: Activity
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @State private var editedStartTime: Date
    @State private var editedEndTime: Date
    @State private var editedDisplayVolume: Double
    @State private var editedBreastSide: BreastSide
    @State private var editedDiaperType: DiaperType
    @State private var editedNoteText: String
    @State private var editedFoodName: String
    @State private var editedFoodQuantity: Double
    @State private var editedFoodUnit: FoodUnit
    @State private var hasEndTime: Bool

    init(activity: Activity) {
        self.activity = activity
        self._editedStartTime = State(initialValue: activity.startTime)
        self._editedEndTime = State(initialValue: activity.endTime ?? Date())
        self._editedDisplayVolume = State(initialValue: UnitConversion.displayVolume(activity.volumeML ?? 0))
        self._editedBreastSide = State(initialValue: activity.breastSide ?? .left)
        self._editedDiaperType = State(initialValue: activity.diaperType ?? .pee)
        self._editedNoteText = State(initialValue: activity.noteText ?? "")
        self._editedFoodName = State(initialValue: activity.foodName ?? "")
        self._editedFoodQuantity = State(initialValue: activity.foodQuantity ?? 0)
        self._editedFoodUnit = State(initialValue: activity.foodUnit ?? .grams)
        self._hasEndTime = State(initialValue: activity.endTime != nil)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section(String(localized: "edit_time")) {
                    DatePicker(String(localized: "start_time"), selection: $editedStartTime, in: ...Date())

                    if activity.isOngoing {
                        Toggle(String(localized: "mark_as_finished"), isOn: $hasEndTime)

                        if hasEndTime {
                            DatePicker(String(localized: "end_time"), selection: $editedEndTime, in: ...Date())
                        }
                    } else {
                        DatePicker(String(localized: "end_time"), selection: $editedEndTime, in: ...Date())
                    }
                }
                
                switch activity.type {
                case .breastfeeding:
                    Section(String(localized: "edit_details")) {
                        let laps = activity.breastfeedingLaps
                        if laps.count > 1 {
                            ForEach(Array(laps.enumerated()), id: \.element.id) { index, lap in
                                // Show break row before this lap if there's a gap
                                if index > 0, let prevEnd = laps[index - 1].endTime {
                                    let gap = lap.startTime.timeIntervalSince(prevEnd)
                                    if gap > 1 {
                                        HStack {
                                            Image(systemName: "pause.circle.fill")
                                                .foregroundStyle(.orange)
                                            Text(String(localized: "break_label"))
                                                .foregroundStyle(.orange)
                                            Spacer()
                                            Text(formatLapDuration(gap))
                                                .foregroundStyle(.orange.opacity(0.7))
                                        }
                                        .font(.subheadline)
                                    }
                                }

                                HStack {
                                    Image(systemName: lap.side == .left ? "arrow.left.circle.fill" : "arrow.right.circle.fill")
                                        .foregroundStyle(lap.side == .left ? .pink : .purple)
                                    Text(lap.side.displayName)
                                    Spacer()
                                    if let dur = lap.duration {
                                        Text(formatLapDuration(dur))
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }

                            // Summary row
                            let totalFeeding = laps.compactMap(\.duration).reduce(0, +)
                            let totalBreaks = breakDuration(from: laps)
                            HStack {
                                Text(String(localized: "total_feeding"))
                                    .font(.subheadline.weight(.semibold))
                                Spacer()
                                Text(formatLapDuration(totalFeeding))
                                    .font(.subheadline.weight(.semibold))
                            }
                            if totalBreaks > 1 {
                                HStack {
                                    Text(String(localized: "total_breaks"))
                                        .font(.subheadline)
                                        .foregroundStyle(.orange)
                                    Spacer()
                                    Text(formatLapDuration(totalBreaks))
                                        .font(.subheadline)
                                        .foregroundStyle(.orange)
                                }
                            }
                        } else {
                            Picker(String(localized: "breast_side"), selection: $editedBreastSide) {
                                ForEach(BreastSide.allCases) { side in
                                    Text(side.displayName).tag(side)
                                }
                            }
                        }
                    }
                    
                case .formula, .momsMilk:
                    Section(String(localized: "edit_details")) {
                        HStack {
                            Text(String(localized: "volume_label"))
                            Spacer()
                            TextField("0", value: $editedDisplayVolume, format: .number)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 100)
                            Text(UnitConversion.volumeUnit)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                case .solidFood:
                    Section(String(localized: "edit_details")) {
                        TextField(String(localized: "food_name"), text: $editedFoodName)
                        
                        HStack {
                            Text(String(localized: "quantity"))
                            Spacer()
                            TextField("0", value: $editedFoodQuantity, format: .number)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 100)
                        }
                        
                        Picker(String(localized: "unit"), selection: $editedFoodUnit) {
                            ForEach(FoodUnit.allCases) { unit in
                                Text(unit.displayName).tag(unit)
                            }
                        }
                    }
                    
                case .diaper:
                    Section(String(localized: "edit_details")) {
                        Picker(String(localized: "diaper_type"), selection: $editedDiaperType) {
                            ForEach(DiaperType.allCases) { type in
                                Text(type.displayName).tag(type)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    
                case .note:
                    Section(String(localized: "edit_details")) {
                        TextEditor(text: $editedNoteText)
                            .frame(minHeight: 100)
                    }
                    
                case .sleep:
                    EmptyView()
                }
            }
            .navigationTitle(String(localized: "edit_activity"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "save")) { saveChanges() }
                        .fontWeight(.semibold)
                }
            }
        }
    }
    
    private func formatLapDuration(_ interval: TimeInterval) -> String {
        let m = Int(interval) / 60
        let s = Int(interval) % 60
        return m > 0 ? "\(m)m \(String(format: "%02d", s))s" : "\(s)s"
    }

    private func breakDuration(from laps: [BreastfeedingLap]) -> TimeInterval {
        var total: TimeInterval = 0
        for i in 1..<laps.count {
            if let prevEnd = laps[i - 1].endTime {
                let gap = laps[i].startTime.timeIntervalSince(prevEnd)
                if gap > 1 { total += gap }
            }
        }
        return total
    }

    private func saveChanges() {
        activity.startTime = editedStartTime

        if hasEndTime {
            let endTime = editedEndTime > editedStartTime ? editedEndTime : editedStartTime
            activity.endTime = endTime
            activity.isOngoing = false
        } else if !activity.isOngoing {
            // Was already finished — keep end time updated
            activity.endTime = editedEndTime > editedStartTime ? editedEndTime : editedStartTime
        }

        let storedMl = UnitConversion.storageVolume(editedDisplayVolume)
        activity.volumeML = storedMl > 0 ? storedMl : nil
        activity.breastSide = editedBreastSide
        activity.diaperType = editedDiaperType
        activity.noteText = editedNoteText.isEmpty ? nil : editedNoteText
        activity.foodName = editedFoodName.isEmpty ? nil : editedFoodName
        activity.foodQuantity = editedFoodQuantity > 0 ? editedFoodQuantity : nil
        activity.foodUnit = editedFoodUnit
        activity.updatedAt = Date()

        dismiss()
    }
}
