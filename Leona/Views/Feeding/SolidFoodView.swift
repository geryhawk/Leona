import SwiftUI
import SwiftData

struct SolidFoodView: View {
    let baby: Baby
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @State private var foodName = ""
    @State private var quantity: Double = 50
    @State private var selectedUnit: FoodUnit = .grams
    @State private var dateTime: Date = Date()
    @State private var noteText = ""
    
    // Common baby foods for quick selection
    private let commonFoods = [
        ("🥕", "food_carrot"),
        ("🍌", "food_banana"),
        ("🍎", "food_apple"),
        ("🥑", "food_avocado"),
        ("🍠", "food_sweet_potato"),
        ("🥦", "food_broccoli"),
        ("🍚", "food_rice_cereal"),
        ("🥣", "food_oatmeal"),
        ("🍗", "food_chicken"),
        ("🐟", "food_fish"),
        ("🥛", "food_yogurt"),
        ("🧀", "food_cheese"),
    ]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Food icon
                    Image(systemName: "fork.knife")
                        .font(.system(size: 48))
                        .foregroundStyle(.green)
                        .padding(.top, 20)
                    
                    // Food name
                    VStack(alignment: .leading, spacing: 8) {
                        Text(String(localized: "food_name"))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                        
                        TextField(String(localized: "food_name_placeholder"), text: $foodName)
                            .font(.title3)
                            .padding()
                            .background(.ultraThinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    
                    // Common foods
                    VStack(alignment: .leading, spacing: 8) {
                        Text(String(localized: "common_foods"))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                        
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible()),
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 8) {
                            ForEach(commonFoods, id: \.1) { emoji, nameKey in
                                Button {
                                    foodName = String(localized: String.LocalizationValue(nameKey))
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                } label: {
                                    VStack(spacing: 4) {
                                        Text(emoji)
                                            .font(.title2)
                                        Text(String(localized: String.LocalizationValue(nameKey)))
                                            .font(.caption2)
                                            .lineLimit(1)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(Color(.systemGray6))
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                }
                                .foregroundStyle(.primary)
                            }
                        }
                    }
                    
                    // Quantity
                    VStack(alignment: .leading, spacing: 8) {
                        Text(String(localized: "quantity"))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                        
                        HStack(spacing: 16) {
                            // Stepper-like control
                            HStack(spacing: 0) {
                                Button {
                                    if quantity > 5 {
                                        withAnimation { quantity -= 5 }
                                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    }
                                } label: {
                                    Image(systemName: "minus")
                                        .frame(width: 44, height: 44)
                                        .background(.ultraThinMaterial)
                                }
                                
                                Text(String(format: "%.0f", quantity))
                                    .font(.title2.bold().monospacedDigit())
                                    .frame(width: 80)
                                    .contentTransition(.numericText())
                                    .animation(.spring(response: 0.3), value: quantity)
                                
                                Button {
                                    if quantity < 500 {
                                        withAnimation { quantity += 5 }
                                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    }
                                } label: {
                                    Image(systemName: "plus")
                                        .frame(width: 44, height: 44)
                                        .background(.ultraThinMaterial)
                                }
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(.quaternary))
                            
                            // Unit picker
                            Picker(String(localized: "unit"), selection: $selectedUnit) {
                                ForEach(FoodUnit.allCases) { unit in
                                    Text(unit.displayName).tag(unit)
                                }
                            }
                            .pickerStyle(.menu)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(.ultraThinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                    
                    // Slider
                    Slider(value: $quantity, in: 5...500, step: 5)
                        .tint(.green)
                    
                    // Date/Time
                    VStack(alignment: .leading, spacing: 8) {
                        Text(String(localized: "date_time"))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                        
                        DatePicker(String(localized: "date_time"), selection: $dateTime)
                            .labelsHidden()
                            .padding()
                            .background(.ultraThinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    
                    // Note
                    VStack(alignment: .leading, spacing: 8) {
                        Text(String(localized: "note_optional"))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                        
                        TextField(String(localized: "note_placeholder"), text: $noteText, axis: .vertical)
                            .lineLimit(2...4)
                            .padding()
                            .background(.ultraThinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    
                    // Save
                    Button {
                        saveSolidFood()
                    } label: {
                        Label(String(localized: "save_solid_food"), systemImage: "checkmark.circle.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(LeonaButtonStyle(color: .green))
                    .disabled(foodName.isEmpty)
                    .opacity(foodName.isEmpty ? 0.6 : 1)
                }
                .padding()
            }
            .background(
                LinearGradient(
                    colors: [.green.opacity(0.08), Color(.systemBackground)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .navigationTitle(String(localized: "solid_food"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "cancel")) { dismiss() }
                }
            }
        }
    }
    
    private func saveSolidFood() {
        let activity = Activity(type: .solidFood, startTime: dateTime, baby: baby)
        activity.foodName = foodName
        activity.foodQuantity = quantity
        activity.foodUnit = selectedUnit
        if !noteText.isEmpty { activity.noteText = noteText }
        modelContext.insert(activity)
        
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        dismiss()
    }
}
