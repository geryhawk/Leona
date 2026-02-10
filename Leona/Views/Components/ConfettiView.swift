import SwiftUI

struct ConfettiView: View {
    @State private var particles: [ConfettiParticle] = []
    @State private var isAnimating = false
    
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
        TimelineView(.animation) { timeline in
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
        Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { timer in
            for i in particles.indices {
                particles[i].y += particles[i].speed
                particles[i].x += particles[i].oscillation
                particles[i].rotation += Double.random(in: -5...5)
                
                if particles[i].y > UIScreen.main.bounds.height + 50 {
                    particles[i].y = CGFloat.random(in: -100...(-10))
                    particles[i].x = CGFloat.random(in: 0...UIScreen.main.bounds.width)
                }
            }
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
