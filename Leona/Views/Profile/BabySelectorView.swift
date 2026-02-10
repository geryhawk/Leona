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
                        Button {
                            selectBaby(baby)
                        } label: {
                            HStack(spacing: 14) {
                                // Avatar
                                Group {
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
                                        settings.activeBabyID == baby.id.uuidString
                                            ? Color.leonaPink
                                            : Color.clear,
                                        lineWidth: 2
                                    )
                                )
                                
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(baby.fullName.isEmpty ? baby.displayName : baby.fullName)
                                        .font(.headline)
                                    
                                    Text(baby.ageDescription)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                
                                Spacer()
                                
                                if settings.activeBabyID == baby.id.uuidString {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.leonaPink)
                                }
                            }
                        }
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
                            .foregroundStyle(.leonaPink)
                    }
                }
                
                // Sharing info
                Section {
                    HStack(spacing: 12) {
                        Image(systemName: "icloud.fill")
                            .foregroundStyle(.blue)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(String(localized: "icloud_sync"))
                                .font(.subheadline.weight(.medium))
                            Text(String(localized: "icloud_sync_description"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text(String(localized: "sharing"))
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
        settings.activeBabyID = baby.id.uuidString
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        dismiss()
    }
    
    private func deleteBaby(_ baby: Baby) {
        guard babies.count > 1 else { return } // Don't delete the last baby
        
        if settings.activeBabyID == baby.id.uuidString {
            // Switch to another baby
            if let other = babies.first(where: { $0.id != baby.id }) {
                settings.activeBabyID = other.id.uuidString
            }
        }
        
        modelContext.delete(baby)
    }
}
