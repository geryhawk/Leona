import SwiftUI

// MARK: - App Theme Colors

extension Color {
    
    // Primary palette
    static let leonaPink = Color(red: 0.863, green: 0.518, blue: 0.639)
    static let leonaPinkLight = Color(red: 0.949, green: 0.784, blue: 0.847)
    static let leonaPinkDark = Color(red: 0.694, green: 0.361, blue: 0.478)
    
    // Accent colors
    static let leonaBlue = Color(red: 0.4, green: 0.6, blue: 0.85)
    static let leonaBlueDark = Color(red: 0.2, green: 0.3, blue: 0.55)
    static let leonaPurple = Color(red: 0.6, green: 0.4, blue: 0.8)
    static let leonaGreen = Color(red: 0.247, green: 0.392, blue: 0.325)
    static let leonaOrange = Color(red: 0.95, green: 0.6, blue: 0.3)
    
    // Background colors
    static let leonaBackground = Color(red: 0.973, green: 0.976, blue: 0.98)
    static let leonaCardBackground = Color.white
    static let leonaNightBackground = Color(red: 0.1, green: 0.12, blue: 0.25)
    static let leonaDayBackground = Color(red: 0.85, green: 0.92, blue: 1.0)
    
    // Text
    static let leonaText = Color(red: 0.298, green: 0.298, blue: 0.298)
    static let leonaTextSecondary = Color(red: 0.55, green: 0.55, blue: 0.6)
    
    // Status
    static let leonaSuccess = Color(red: 0.247, green: 0.392, blue: 0.325)
    static let leonaWarning = Color(red: 0.95, green: 0.75, blue: 0.25)
    static let leonaError = Color(red: 0.85, green: 0.25, blue: 0.25)
    
    // Activity colors
    static let feedingColor = Color(red: 1.0, green: 0.6, blue: 0.7)
    static let sleepColor = Color(red: 0.55, green: 0.55, blue: 0.95)
    static let diaperColor = Color(red: 0.4, green: 0.8, blue: 0.85)
    
    // Gradients
    static let leonaPinkGradient = LinearGradient(
        colors: [leonaPinkLight, leonaPink],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let leonaBlueGradient = LinearGradient(
        colors: [leonaDayBackground, leonaBlue],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let leonaNightGradient = LinearGradient(
        colors: [Color(red: 0.15, green: 0.15, blue: 0.35), leonaNightBackground],
        startPoint: .top,
        endPoint: .bottom
    )
    
    static let leonaSunriseGradient = LinearGradient(
        colors: [leonaOrange.opacity(0.6), leonaPink.opacity(0.4), leonaBlue.opacity(0.3)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

// MARK: - Themed View Modifiers

struct LeonaCardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
    }
}

struct LeonaButtonStyle: ButtonStyle {
    let color: Color
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            .background(color.gradient)
            .clipShape(Capsule())
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct LeonaSecondaryButtonStyle: ButtonStyle {
    let color: Color
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

extension View {
    func leonaCard() -> some View {
        modifier(LeonaCardStyle())
    }
    
    func leonaButton(color: Color = .leonaPink) -> some View {
        buttonStyle(LeonaButtonStyle(color: color))
    }
    
    func leonaSecondaryButton(color: Color = .leonaPink) -> some View {
        buttonStyle(LeonaSecondaryButtonStyle(color: color))
    }
}
