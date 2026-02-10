import SwiftUI

struct ConfettiView: View {
    @State private var particles: [ConfettiParticle] = []
    @State private var animationTimer: Timer?
    
    let colors: [Color] = [.pink, .purple, .blue, .orange, .yellow, .green, .red, .mint]
    
    struct ConfettiParticle: Identifiable {
        let id = UUID()
        var x: CGFloat
        var y: CGFloat
        var rotation: Double
        var scale: CGFloat
        var color: Color
        var shape: Int // 0: circle, 1: rectangle, 2: star
        var speed: CGFloat
        var oscillation: CGFloat
    }
    
    var body: some View {
        TimelineView(.animation) { _ in
            Canvas { context, size in
                for particle in particles {
                    let rect = CGRect(
                        x: particle.x - 4 * particle.scale,
                        y: particle.y - 4 * particle.scale,
                        width: 8 * particle.scale,
                        height: particle.shape == 1 ? 12 * particle.scale : 8 * particle.scale
                    )
                    
                    context.fill(
                        Path(ellipseIn: rect),
                        with: .color(particle.color)
                    )
                }
            }
        }
        .onAppear {
            generateParticles()
            startAnimation()
        }
        .onDisappear {
            animationTimer?.invalidate()
            animationTimer = nil
        }
    }
    
    private func generateParticles() {
        particles = (0..<80).map { _ in
            ConfettiParticle(
                x: CGFloat.random(in: 0...UIScreen.main.bounds.width),
                y: CGFloat.random(in: -200...0),
                rotation: Double.random(in: 0...360),
                scale: CGFloat.random(in: 0.5...1.5),
                color: colors.randomElement() ?? .pink,
                shape: Int.random(in: 0...2),
                speed: CGFloat.random(in: 2...6),
                oscillation: CGFloat.random(in: -2...2)
            )
        }
    }
    
    private func startAnimation() {
        animationTimer?.invalidate()
        animationTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { _ in
            var updated = particles
            for i in updated.indices {
                updated[i].y += updated[i].speed
                updated[i].x += updated[i].oscillation
                updated[i].rotation += Double.random(in: -5...5)
                
                if updated[i].y > UIScreen.main.bounds.height + 50 {
                    updated[i].y = CGFloat.random(in: -100...(-10))
                    updated[i].x = CGFloat.random(in: 0...UIScreen.main.bounds.width)
                }
            }
            particles = updated
        }
    }
}

// MARK: - Celebration Modifier

struct CelebrationModifier: ViewModifier {
    @Binding var isPresented: Bool
    
    func body(content: Content) -> some View {
        content.overlay {
            if isPresented {
                ConfettiView()
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                    .transition(.opacity)
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                            withAnimation {
                                isPresented = false
                            }
                        }
                    }
            }
        }
    }
}

extension View {
    func celebration(isPresented: Binding<Bool>) -> some View {
        modifier(CelebrationModifier(isPresented: isPresented))
    }
}
