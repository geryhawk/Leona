import SwiftUI

// MARK: - Dynamic Theme Colors (resolve from AppSettings accent color)

extension Color {
    
    // Dynamic primary colors - read from current accent setting
    static var leonaPrimary: Color {
        AppSettings.shared.accentColor.color
    }
    
    static var leonaPrimaryLight: Color {
        AppSettings.shared.accentColor.colorLight
    }
    
    static var leonaPrimaryDark: Color {
        AppSettings.shared.accentColor.colorDark
    }
    
    // Legacy aliases - point to dynamic primary
    static var leonaPink: Color { leonaPrimary }
    static var leonaPinkLight: Color { leonaPrimaryLight }
    static var leonaPinkDark: Color { leonaPrimaryDark }
    
    // Accent colors (fixed, for specific use)
    static let leonaBlue = Color(red: 0.4, green: 0.6, blue: 0.85)
    static let leonaPurple = Color(red: 0.6, green: 0.4, blue: 0.8)
    static let leonaOrange = Color(red: 0.95, green: 0.6, blue: 0.3)
    
    // Background colors
    static let leonaBackground = Color(.systemGroupedBackground)
    static let leonaCardBackground = Color(.secondarySystemGroupedBackground)
    static let leonaNightBackground = Color(red: 0.1, green: 0.12, blue: 0.25)
    static let leonaDayBackground = Color(red: 0.85, green: 0.92, blue: 1.0)
}

// MARK: - ShapeStyle Extensions (allows .leonaPink in foregroundStyle, stroke, etc.)

extension ShapeStyle where Self == Color {
    static var leonaPink: Color { Color.leonaPink }
    static var leonaPinkLight: Color { Color.leonaPinkLight }
    static var leonaPinkDark: Color { Color.leonaPinkDark }
    static var leonaPrimary: Color { Color.leonaPrimary }
    static var leonaPrimaryLight: Color { Color.leonaPrimaryLight }
    static var leonaPrimaryDark: Color { Color.leonaPrimaryDark }
    static var leonaBlue: Color { Color.leonaBlue }
    static var leonaPurple: Color { Color.leonaPurple }
    static var leonaOrange: Color { Color.leonaOrange }
    static var leonaBackground: Color { Color.leonaBackground }
    static var leonaCardBackground: Color { Color.leonaCardBackground }
    static var leonaNightBackground: Color { Color.leonaNightBackground }
    static var leonaDayBackground: Color { Color.leonaDayBackground }
}

// MARK: - Dynamic Gradients

extension Color {
    static var leonaPrimaryGradient: LinearGradient {
        LinearGradient(
            colors: [leonaPrimaryLight, leonaPrimary],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    // Legacy alias
    static var leonaPinkGradient: LinearGradient { leonaPrimaryGradient }
}

// MARK: - Themed View Modifiers

struct LeonaCardStyle: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .background(
                colorScheme == .dark
                    ? AnyShapeStyle(Color(.secondarySystemGroupedBackground))
                    : AnyShapeStyle(.regularMaterial)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(
                color: colorScheme == .dark
                    ? .clear
                    : .black.opacity(0.06),
                radius: 8, x: 0, y: 2
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(
                        colorScheme == .dark
                            ? Color.white.opacity(0.06)
                            : Color.clear,
                        lineWidth: 0.5
                    )
            )
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
}
