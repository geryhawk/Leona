import SwiftUI
import SwiftData

struct OnboardingView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.modelContext) private var modelContext
    
    @State private var currentPage = 0
    @State private var babyName = ""
    @State private var babyLastName = ""
    @State private var dateOfBirth = Date()
    @State private var gender: BabyGender = .unspecified
    @State private var showDatePicker = false
    
    private let totalPages = 3
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [.leonaPinkLight.opacity(0.3), .leonaBlue.opacity(0.2), .white],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Page content
                TabView(selection: $currentPage) {
                    welcomePage.tag(0)
                    babyInfoPage.tag(1)
                    readyPage.tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut(duration: 0.3), value: currentPage)
                
                // Navigation
                bottomNavigation
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)
            }
        }
    }
    
    // MARK: - Welcome Page
    
    private var welcomePage: some View {
        VStack(spacing: 32) {
            Spacer()
            
            Image(systemName: "heart.circle.fill")
                .font(.system(size: 100))
                .foregroundStyle(.leonaPink)
                .symbolEffect(.pulse, options: .repeating)
            
            VStack(spacing: 12) {
                Text("Leona")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundStyle(.leonaPink)
                
                Text(String(localized: "onboarding_subtitle"))
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            VStack(spacing: 16) {
                featureRow(icon: "moon.stars.fill", color: .indigo, text: String(localized: "onboarding_feature_sleep"))
                featureRow(icon: "cup.and.saucer.fill", color: .orange, text: String(localized: "onboarding_feature_feeding"))
                featureRow(icon: "chart.line.uptrend.xyaxis", color: .green, text: String(localized: "onboarding_feature_growth"))
                featureRow(icon: "icloud.fill", color: .blue, text: String(localized: "onboarding_feature_sync"))
            }
            .padding(.horizontal, 32)
            
            Spacer()
        }
    }
    
    // MARK: - Baby Info Page
    
    private var babyInfoPage: some View {
        ScrollView {
            VStack(spacing: 28) {
                Spacer().frame(height: 20)
                
                Image(systemName: "person.crop.circle.badge.plus")
                    .font(.system(size: 64))
                    .foregroundStyle(.leonaPink)
                
                Text(String(localized: "onboarding_baby_title"))
                    .font(.title.bold())
                
                VStack(spacing: 20) {
                    // First Name
                    VStack(alignment: .leading, spacing: 8) {
                        Text(String(localized: "first_name"))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                        
                        TextField(String(localized: "baby_name_placeholder"), text: $babyName)
                            .font(.title3)
                            .padding()
                            .background(.ultraThinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    
                    // Last Name
                    VStack(alignment: .leading, spacing: 8) {
                        Text(String(localized: "last_name"))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                        
                        TextField(String(localized: "last_name_placeholder"), text: $babyLastName)
                            .font(.title3)
                            .padding()
                            .background(.ultraThinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    
                    // Date of Birth
                    VStack(alignment: .leading, spacing: 8) {
                        Text(String(localized: "date_of_birth"))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                        
                        DatePicker(
                            String(localized: "date_of_birth"),
                            selection: $dateOfBirth,
                            displayedComponents: .date
                        )
                        .datePickerStyle(.compact)
                        .labelsHidden()
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    
                    // Gender
                    VStack(alignment: .leading, spacing: 8) {
                        Text(String(localized: "gender"))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                        
                        HStack(spacing: 12) {
                            ForEach(BabyGender.allCases) { g in
                                Button {
                                    withAnimation(.spring(response: 0.3)) {
                                        gender = g
                                    }
                                } label: {
                                    VStack(spacing: 6) {
                                        Image(systemName: g.icon)
                                            .font(.title2)
                                        Text(g.displayName)
                                            .font(.caption)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(gender == g ? g.color.opacity(0.15) : Color.clear)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(gender == g ? g.color : .gray.opacity(0.3), lineWidth: gender == g ? 2 : 1)
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                }
                                .foregroundStyle(gender == g ? g.color : .secondary)
                            }
                        }
                    }
                }
                .padding(.horizontal, 24)
                
                Spacer().frame(height: 40)
            }
        }
    }
    
    // MARK: - Ready Page
    
    private var readyPage: some View {
        VStack(spacing: 32) {
            Spacer()
            
            if !babyName.isEmpty {
                Image(systemName: "sparkles")
                    .font(.system(size: 80))
                    .foregroundStyle(.leonaPink)
                    .symbolEffect(.variableColor.iterative.reversing, options: .repeating)
                
                VStack(spacing: 12) {
                    Text(String(localized: "onboarding_ready_title"))
                        .font(.title.bold())
                    
                    Text(String(localized: "onboarding_ready_subtitle \(babyName)"))
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            } else {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 60))
                    .foregroundStyle(.orange)
                
                Text(String(localized: "onboarding_enter_name"))
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
        }
        .padding(.horizontal, 32)
    }
    
    // MARK: - Bottom Navigation
    
    private var bottomNavigation: some View {
        HStack {
            // Back button
            if currentPage > 0 {
                Button {
                    withAnimation { currentPage -= 1 }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.headline)
                        .foregroundStyle(.leonaPink)
                        .padding(12)
                        .background(.leonaPink.opacity(0.1))
                        .clipShape(Circle())
                }
            } else {
                Spacer().frame(width: 44)
            }
            
            Spacer()
            
            // Page indicators
            HStack(spacing: 8) {
                ForEach(0..<totalPages, id: \.self) { page in
                    Circle()
                        .fill(page == currentPage ? Color.leonaPink : Color.gray.opacity(0.3))
                        .frame(width: page == currentPage ? 10 : 7, height: page == currentPage ? 10 : 7)
                        .animation(.spring(response: 0.3), value: currentPage)
                }
            }
            
            Spacer()
            
            // Next / Create button
            if currentPage < totalPages - 1 {
                Button {
                    withAnimation { currentPage += 1 }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .padding(12)
                        .background(.leonaPink)
                        .clipShape(Circle())
                }
            } else {
                Button {
                    createBaby()
                } label: {
                    Text(String(localized: "get_started"))
                        .font(.headline)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(babyName.isEmpty ? .gray : .leonaPink)
                        .clipShape(Capsule())
                }
                .disabled(babyName.isEmpty)
            }
        }
    }
    
    // MARK: - Feature Row
    
    private func featureRow(icon: String, color: Color, text: String) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
                .frame(width: 44)
            
            Text(text)
                .font(.body)
                .foregroundStyle(.primary)
            
            Spacer()
        }
    }
    
    // MARK: - Create Baby
    
    private func createBaby() {
        guard !babyName.isEmpty else { return }
        
        let baby = Baby(
            firstName: babyName.trimmingCharacters(in: .whitespaces),
            lastName: babyLastName.trimmingCharacters(in: .whitespaces),
            dateOfBirth: dateOfBirth,
            gender: gender
        )
        
        modelContext.insert(baby)
        
        settings.activeBabyID = baby.id.uuidString
        settings.hasCompletedOnboarding = true
        
        // Request notification permission
        Task {
            _ = await NotificationManager.shared.requestAuthorization()
        }
    }
}
