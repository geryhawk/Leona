import SwiftUI

struct SplashScreenView: View {
    @Environment(\.colorScheme) private var colorScheme

    @State private var iconScale: CGFloat = 0.5
    @State private var iconOpacity: Double = 0
    @State private var titleOpacity: Double = 0
    @State private var taglineOpacity: Double = 0
    @State private var glowScale: CGFloat = 0.8
    @State private var backgroundOpacity: Double = 1

    let onFinished: () -> Void

    var body: some View {
        ZStack {
            // Background — adapts to color scheme
            backgroundGradient
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // App icon with glow
                ZStack {
                    // Soft radial glow behind icon
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color.leonaPrimary.opacity(0.2),
                                    Color.leonaPrimary.opacity(0.05),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 30,
                                endRadius: 120
                            )
                        )
                        .frame(width: 240, height: 240)
                        .scaleEffect(glowScale)
                        .opacity(iconOpacity * 0.6)

                    // App icon
                    Image("AppIconImage")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 120, height: 120)
                        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                    .shadow(color: Color.leonaPrimary.opacity(colorScheme == .dark ? 0.4 : 0.25), radius: 20, x: 0, y: 8)
                    .scaleEffect(iconScale)
                    .opacity(iconOpacity)
                }

                Spacer().frame(height: 32)

                // App name
                Text("Leona")
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.leonaPrimary, Color.leonaPrimaryDark],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .opacity(titleOpacity)

                Spacer().frame(height: 10)

                // Tagline
                Text(String(localized: "splash_tagline"))
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.secondary)
                    .opacity(taglineOpacity)

                Spacer()
                Spacer()
            }
        }
        .opacity(backgroundOpacity)
        .onAppear {
            startAnimation()
        }
    }

    // MARK: - Background

    private var backgroundGradient: some View {
        Group {
            if colorScheme == .dark {
                LinearGradient(
                    colors: [
                        Color(red: 0.08, green: 0.08, blue: 0.12),
                        Color(red: 0.10, green: 0.09, blue: 0.16),
                        Color(red: 0.08, green: 0.08, blue: 0.14)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            } else {
                LinearGradient(
                    colors: [
                        Color(red: 0.98, green: 0.96, blue: 0.97),
                        Color(red: 0.96, green: 0.95, blue: 0.98),
                        Color(red: 0.97, green: 0.97, blue: 0.99)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
    }

    // MARK: - Animation

    private func startAnimation() {
        // Phase 1: Icon springs in
        withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.1)) {
            iconScale = 1.0
            iconOpacity = 1.0
        }

        // Glow breathes
        withAnimation(.easeInOut(duration: 1.5).delay(0.3).repeatCount(2, autoreverses: true)) {
            glowScale = 1.15
        }

        // Phase 2: Title fades in
        withAnimation(.easeOut(duration: 0.4).delay(0.4)) {
            titleOpacity = 1.0
        }

        // Phase 3: Tagline fades in
        withAnimation(.easeOut(duration: 0.4).delay(0.7)) {
            taglineOpacity = 1.0
        }

        // Phase 4: Fade out and finish
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
            withAnimation(.easeInOut(duration: 0.3)) {
                backgroundOpacity = 0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                onFinished()
            }
        }
    }
}
