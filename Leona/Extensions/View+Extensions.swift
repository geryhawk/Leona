import SwiftUI

// MARK: - View Extensions

extension View {
    
    /// Apply a condition to a view modifier
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
    
    /// Slide in from bottom animation
    func slideInFromBottom(delay: Double = 0) -> some View {
        self.modifier(SlideInModifier(delay: delay))
    }
}

// MARK: - Custom Modifiers

struct SlideInModifier: ViewModifier {
    let delay: Double
    @State private var isVisible = false
    
    func body(content: Content) -> some View {
        content
            .offset(y: isVisible ? 0 : 30)
            .opacity(isVisible ? 1 : 0)
            .onAppear {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(delay)) {
                    isVisible = true
                }
            }
    }
}
