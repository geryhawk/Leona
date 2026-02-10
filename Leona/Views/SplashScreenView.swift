import SwiftUI

struct SplashScreenView: View {
    @State private var logoScale: CGFloat = 0.3
    @State private var logoOpacity: Double = 0
    @State private var textOpacity: Double = 0
    @State private var subtitleOpacity: Double = 0
    @State private var backgroundOpacity: Double = 1
    @State private var heartBeat = false
    
    let onFinished: () -> Void
    
    var body: some View {
        ZStack {
            // Solid opaque background - warm gradient
            LinearGradient(
                colors: [
                    Color(red: 0.98, green: 0.94, blue: 0.96),
                    Color(red: 0.95, green: 0.93, blue: 0.97),
                    Color(red: 0.96, green: 0.96, blue: 0.99)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 24) {
                Spacer()
                
                // Heart logo
                ZStack {
                    // Soft glow
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color.leonaPrimary.opacity(0.25), Color.clear],
                                center: .center,
                                startRadius: 20,
                                endRadius: 100
                            )
                        )
                        .frame(width: 200, height: 200)
                        .scaleEffect(logoScale * 1.2)
                        .opacity(logoOpacity * 0.5)
                    
                    // Heart icon
                    Image(systemName: "heart.fill")
                        .font(.system(size: 80, weight: .regular))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.leonaPrimaryLight, Color.leonaPrimary, Color.leonaPrimaryDark],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .scaleEffect(logoScale * (heartBeat ? 1.08 : 1.0))
                        .opacity(logoOpacity)
                        .shadow(color: Color.leonaPrimary.opacity(0.3), radius: 12, x: 0, y: 4)
                }
                
                // App name
                VStack(spacing: 8) {
                    Text("Leona")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.leonaPrimary, Color.leonaPrimaryDark],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .opacity(textOpacity)
                    
                    Text(String(localized: "onboarding_subtitle"))
                        .font(.title3.weight(.medium))
                        .foregroundStyle(.secondary)
                        .opacity(subtitleOpacity)
                }
                
                Spacer()
                Spacer()
            }
        }
        .opacity(backgroundOpacity)
        .onAppear {
            startAnimation()
        }
    }
    
    private func startAnimation() {
        // Phase 1: Logo appears with spring
        withAnimation(.spring(response: 0.7, dampingFraction: 0.6).delay(0.15)) {
            logoScale = 1.0
            logoOpacity = 1.0
        }
        
        // Phase 1b: Heart beat pulse
        withAnimation(.easeInOut(duration: 0.4).delay(0.7).repeatCount(3, autoreverses: true)) {
            heartBeat = true
        }
        
        // Phase 2: Text fades in
        withAnimation(.easeOut(duration: 0.5).delay(0.5)) {
            textOpacity = 1.0
        }
        
        // Phase 3: Subtitle fades in
        withAnimation(.easeOut(duration: 0.4).delay(0.8)) {
            subtitleOpacity = 1.0
        }
        
        // Phase 4: Transition out
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.easeInOut(duration: 0.35)) {
                backgroundOpacity = 0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                onFinished()
            }
        }
    }
}
