import UIKit

/// Manager for haptic feedback that gracefully handles simulator limitations
enum HapticManager {
    
    /// Triggers a success haptic (only on real devices)
    static func success() {
        #if !targetEnvironment(simulator)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        #endif
    }
    
    /// Triggers an error haptic (only on real devices)
    static func error() {
        #if !targetEnvironment(simulator)
        UINotificationFeedbackGenerator().notificationOccurred(.error)
        #endif
    }
    
    /// Triggers a warning haptic (only on real devices)
    static func warning() {
        #if !targetEnvironment(simulator)
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
        #endif
    }
    
    /// Triggers an impact haptic with specified style (only on real devices)
    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        #if !targetEnvironment(simulator)
        UIImpactFeedbackGenerator(style: style).impactOccurred()
        #endif
    }
    
    /// Triggers a selection change haptic (only on real devices)
    static func selection() {
        #if !targetEnvironment(simulator)
        UISelectionFeedbackGenerator().selectionChanged()
        #endif
    }
}
