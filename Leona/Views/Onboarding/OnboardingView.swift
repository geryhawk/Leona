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
    @State private var appearAnimated = false
    
    private let totalPages = 3
    
    var body: some View {
        ZStack {
            // Animated background gradient
            LinearGradient(
                colors: backgroundColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 0.6), value: currentPage)
            
            // Floating decorative circles
            floatingDecorations
            
            VStack(spacing: 0) {
                // Page content
                TabView(selection: $currentPage) {
                    welcomePage.tag(0)
                    babyInfoPage.tag(1)
                    readyPage.tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.spring(response: 0.5, dampingFraction: 0.8), value: currentPage)
                
                // Navigation
                bottomNavigation
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) {
                appearAnimated = true
            }
        }
    }
    
    // MARK: - Background Colors per Page
    
    private var backgroundColors: [Color] {
        switch currentPage {
        case 0:
            return [.leonaPinkLight.opacity(0.3), .leonaBlue.opacity(0.15), Color(.systemBackground)]
        case 1:
            return [.leonaBlue.opacity(0.2), .leonaPurple.opacity(0.1), Color(.systemBackground)]
        default:
            return [.leonaPinkLight.opacity(0.2), .leonaOrange.opacity(0.1), Color(.systemBackground)]
        }
    }
    
    // MARK: - Floating Decorations
    
    private var floatingDecorations: some View {
        GeometryReader { geo in
            Circle()
                .fill(Color.leonaPink.opacity(0.08))
                .frame(width: 200, height: 200)
                .offset(x: -60, y: appearAnimated ? 80 : -20)
                .animation(.easeInOut(duration: 3).repeatForever(autoreverses: true), value: appearAnimated)
            
            Circle()
                .fill(Color.leonaBlue.opacity(0.06))
                .frame(width: 150, height: 150)
                .offset(x: geo.size.width - 100, y: geo.size.height - 300)
                .animation(.easeInOut(duration: 4).repeatForever(autoreverses: true).delay(1), value: appearAnimated)
            
            Circle()
                .fill(Color.leonaPurple.opacity(0.05))
                .frame(width: 100, height: 100)
                .offset(x: geo.size.width - 60, y: appearAnimated ? 160 : 200)
                .animation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true).delay(0.5), value: appearAnimated)
        }
        .ignoresSafeArea()
    }
    
    // MARK: - Welcome Page
    
    private var welcomePage: some View {
        VStack(spacing: 28) {
            Spacer()
            
            // Logo with animation
            ZStack {
                // Glow
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.leonaPink.opacity(0.25), Color.clear],
                            center: .center,
                            startRadius: 10,
                            endRadius: 100
                        )
                    )
                    .frame(width: 200, height: 200)
                
                Image(systemName: "figure.and.child.holdinghands")
                    .font(.system(size: 80, weight: .light))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.leonaPink, .leonaPinkDark],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .symbolEffect(.pulse, options: .repeating.speed(0.5))
            }
            .scaleEffect(appearAnimated ? 1.0 : 0.5)
            .opacity(appearAnimated ? 1.0 : 0)
            
            VStack(spacing: 12) {
                Text("Leona")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.leonaPink, .leonaPinkDark],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                
                Text(String(localized: "onboarding_subtitle"))
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .opacity(appearAnimated ? 1.0 : 0)
            
            // Feature cards with glassmorphism
            VStack(spacing: 12) {
                featureCard(icon: "moon.stars.fill", color: .indigo, text: String(localized: "onboarding_feature_sleep"), delay: 0)
                featureCard(icon: "cup.and.saucer.fill", color: .orange, text: String(localized: "onboarding_feature_feeding"), delay: 0.1)
                featureCard(icon: "chart.line.uptrend.xyaxis", color: .green, text: String(localized: "onboarding_feature_growth"), delay: 0.2)
                featureCard(icon: "icloud.fill", color: .blue, text: String(localized: "onboarding_feature_sync"), delay: 0.3)
            }
            .padding(.horizontal, 24)
            
            Spacer()
        }
    }
    
    // MARK: - Baby Info Page
    
    private var babyInfoPage: some View {
        ScrollView {
            VStack(spacing: 28) {
                Spacer().frame(height: 20)
                
                babyInfoHeader
                
                babyInfoForm
                
                Spacer().frame(height: 40)
            }
        }
    }
    
    private var babyInfoHeader: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.crop.circle.badge.plus")
                .font(.system(size: 56))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.leonaBlue, .leonaPurple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            Text(String(localized: "onboarding_baby_title"))
                .font(.title.bold())
        }
    }
    
    private var babyInfoForm: some View {
        VStack(spacing: 20) {
            firstNameField
            lastNameField
            dateOfBirthField
            genderSelector
        }
        .padding(.horizontal, 24)
    }
    
    private var firstNameField: some View {
        glassField {
            VStack(alignment: .leading, spacing: 8) {
                Text(String(localized: "first_name"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                
                TextField(String(localized: "baby_name_placeholder"), text: $babyName)
                    .font(.title3)
            }
        }
    }
    
    private var lastNameField: some View {
        glassField {
            VStack(alignment: .leading, spacing: 8) {
                Text(String(localized: "last_name"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                
                TextField(String(localized: "last_name_placeholder"), text: $babyLastName)
                    .font(.title3)
            }
        }
    }
    
    private var dateOfBirthField: some View {
        glassField {
            VStack(alignment: .leading, spacing: 8) {
                Text(String(localized: "date_of_birth"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                
                DatePicker(
                    String(localized: "date_of_birth"),
                    selection: $dateOfBirth,
                    in: ...Date(),
                    displayedComponents: .date
                )
                .datePickerStyle(.compact)
                .labelsHidden()
            }
        }
    }
    
    private var genderSelector: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(String(localized: "gender"))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)
            
            HStack(spacing: 12) {
                ForEach(BabyGender.allCases) { g in
                    genderButton(for: g)
                }
            }
        }
    }
    
    private func genderButton(for g: BabyGender) -> some View {
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
            .background {
                if gender == g {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(g.color.opacity(0.15))
                } else {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.ultraThinMaterial)
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(gender == g ? g.color : Color.gray.opacity(0.2), lineWidth: gender == g ? 2 : 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .foregroundStyle(gender == g ? g.color : .secondary)
    }
    
    // MARK: - Ready Page
    
    private var readyPage: some View {
        VStack(spacing: 32) {
            Spacer()
            
            if !babyName.isEmpty {
                ZStack {
                    // Celebration glow
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color.leonaPink.opacity(0.2), Color.leonaOrange.opacity(0.1), Color.clear],
                                center: .center,
                                startRadius: 10,
                                endRadius: 120
                            )
                        )
                        .frame(width: 260, height: 260)
                    
                    Image(systemName: "sparkles")
                        .font(.system(size: 80))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.leonaPink, .leonaOrange],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .symbolEffect(.variableColor.iterative.reversing, options: .repeating)
                }
                
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
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                        .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
                }
            } else {
                Spacer().frame(width: 44)
            }
            
            Spacer()
            
            // Page indicators
            HStack(spacing: 8) {
                ForEach(0..<totalPages, id: \.self) { page in
                    Capsule()
                        .fill(page == currentPage ? Color.leonaPink : Color.gray.opacity(0.3))
                        .frame(width: page == currentPage ? 24 : 8, height: 8)
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
                        .background(Color.leonaPink.gradient)
                        .clipShape(Circle())
                        .shadow(color: Color.leonaPink.opacity(0.3), radius: 6, x: 0, y: 3)
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
                        .background(
                            (babyName.isEmpty ? AnyShapeStyle(Color.gray) : AnyShapeStyle(Color.leonaPink.gradient))
                        )
                        .clipShape(Capsule())
                        .shadow(color: babyName.isEmpty ? .clear : Color.leonaPink.opacity(0.3), radius: 6, x: 0, y: 3)
                }
                .disabled(babyName.isEmpty)
            }
        }
    }
    
    // MARK: - Feature Card (Glassmorphism)
    
    private func featureCard(icon: String, color: Color, text: String, delay: Double) -> some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 44, height: 44)
                
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(color)
            }
            
            Text(text)
                .font(.body)
                .foregroundStyle(.primary)
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 2)
    }
    
    // MARK: - Glass Field
    
    @ViewBuilder
    private func glassField<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding()
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .shadow(color: .black.opacity(0.03), radius: 4, x: 0, y: 2)
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
