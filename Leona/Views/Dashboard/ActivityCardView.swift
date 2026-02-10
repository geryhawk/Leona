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
                .gesture(swipeGesture)
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
                }
            }
        }
    }
    
    private var mainCardContent: some View {
        HStack(spacing: 14) {
            // Activity icon
            ZStack {
                Circle()
                    .fill(activity.type.color.opacity(0.15))
                    .frame(width: 44, height: 44)
                
                Image(systemName: activity.type.icon)
                    .font(.body)
                    .foregroundStyle(activity.type.color)
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
        DragGesture()
            .onChanged { value in
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
    @State private var editedVolume: Double
    @State private var editedBreastSide: BreastSide
    @State private var editedDiaperType: DiaperType
    @State private var editedNoteText: String
    @State private var editedFoodName: String
    @State private var editedFoodQuantity: Double
    @State private var editedFoodUnit: FoodUnit
    
    init(activity: Activity) {
        self.activity = activity
        self._editedStartTime = State(initialValue: activity.startTime)
        self._editedEndTime = State(initialValue: activity.endTime ?? Date())
        self._editedVolume = State(initialValue: activity.volumeML ?? 0)
        self._editedBreastSide = State(initialValue: activity.breastSide ?? .left)
        self._editedDiaperType = State(initialValue: activity.diaperType ?? .pee)
        self._editedNoteText = State(initialValue: activity.noteText ?? "")
        self._editedFoodName = State(initialValue: activity.foodName ?? "")
        self._editedFoodQuantity = State(initialValue: activity.foodQuantity ?? 0)
        self._editedFoodUnit = State(initialValue: activity.foodUnit ?? .grams)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section(String(localized: "edit_time")) {
                    DatePicker(String(localized: "start_time"), selection: $editedStartTime)
                    
                    if activity.endTime != nil {
                        DatePicker(String(localized: "end_time"), selection: $editedEndTime)
                    }
                }
                
                switch activity.type {
                case .breastfeeding:
                    Section(String(localized: "edit_details")) {
                        Picker(String(localized: "breast_side"), selection: $editedBreastSide) {
                            ForEach(BreastSide.allCases) { side in
                                Text(side.displayName).tag(side)
                            }
                        }
                    }
                    
                case .formula, .momsMilk:
                    Section(String(localized: "edit_details")) {
                        HStack {
                            Text(String(localized: "volume_ml"))
                            Spacer()
                            TextField("0", value: $editedVolume, format: .number)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 100)
                            Text("ml")
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
    
    private func saveChanges() {
        activity.startTime = editedStartTime
        if activity.endTime != nil {
            activity.endTime = editedEndTime
        }
        activity.volumeML = editedVolume > 0 ? editedVolume : nil
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
