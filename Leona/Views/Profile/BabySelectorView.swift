import SwiftUI
import SwiftData

struct BabySelectorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AppSettings.self) private var settings
    
    @Query(sort: \Baby.createdAt) private var babies: [Baby]
    
    @State private var showAddBaby = false
    @State private var editingBaby: Baby?
    
    var body: some View {
        NavigationStack {
            List {
                // Baby profiles
                Section(String(localized: "your_babies")) {
                    ForEach(babies) { baby in
                        let isSelected = settings.activeBabyID == baby.id.uuidString
                        Button {
                            selectBaby(baby)
                        } label: {
                            HStack(spacing: 14) {
                                // Avatar
                                ZStack {
                                    if let image = baby.profileImage {
                                        image
                                            .resizable()
                                            .scaledToFill()
                                    } else {
                                        Image(systemName: "person.crop.circle.fill")
                                            .resizable()
                                            .foregroundStyle(baby.gender.color.opacity(0.6))
                                    }
                                }
                                .frame(width: 48, height: 48)
                                .clipShape(Circle())
                                .overlay(
                                    Circle().stroke(
                                        isSelected ? Color.leonaPrimary : Color.clear,
                                        lineWidth: 2.5
                                    )
                                )
                                
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(baby.fullName.isEmpty ? baby.displayName : baby.fullName)
                                        .font(.headline)
                                    
                                    Text(baby.ageDescription)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                
                                Spacer()
                                
                                if isSelected {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.leonaPrimary)
                                        .font(.title3)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        .tint(.primary)
                        .listRowBackground(isSelected ? Color.leonaPrimary.opacity(0.06) : nil)
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                deleteBaby(baby)
                            } label: {
                                Label(String(localized: "delete"), systemImage: "trash")
                            }
                            
                            Button {
                                editingBaby = baby
                            } label: {
                                Label(String(localized: "edit"), systemImage: "pencil")
                            }
                            .tint(.orange)
                        }
                    }
                }
                
                // Add baby
                Section {
                    Button {
                        showAddBaby = true
                    } label: {
                        Label(String(localized: "add_baby"), systemImage: "plus.circle.fill")
                            .foregroundStyle(.leonaPrimary)
                    }
                }
            }
            .navigationTitle(String(localized: "babies"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "done")) { dismiss() }
                }
            }
            .sheet(isPresented: $showAddBaby) {
                AddBabyView()
            }
            .sheet(item: $editingBaby) { baby in
                BabyProfileView(baby: baby)
            }
        }
    }
    
    private func selectBaby(_ baby: Baby) {
        withAnimation(.easeInOut(duration: 0.2)) {
            settings.activeBabyID = baby.id.uuidString
        }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        // Small delay so the user sees the selection feedback
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            dismiss()
        }
    }
    
    private func deleteBaby(_ baby: Baby) {
        guard babies.count > 1 else { return }
        
        if settings.activeBabyID == baby.id.uuidString {
            if let other = babies.first(where: { $0.id != baby.id }) {
                settings.activeBabyID = other.id.uuidString
            }
        }
        
        withAnimation {
            modelContext.delete(baby)
        }
    }
}
