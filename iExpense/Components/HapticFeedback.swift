import SwiftUI

/// Utility for providing haptic feedback
enum HapticFeedback {
    /// Trigger impact haptic feedback
    static func impact(style: UIImpactFeedbackGenerator.FeedbackStyle = .light) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred()
    }
    
    /// Trigger selection haptic feedback
    static func selection() {
        let generator = UISelectionFeedbackGenerator()
        generator.selectionChanged()
    }
    
    /// Trigger notification haptic feedback
    static func notification(type: UINotificationFeedbackGenerator.FeedbackType) {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(type)
    }
    
    /// Trigger success notification
    static func success() {
        notification(type: .success)
    }
    
    /// Trigger error notification
    static func error() {
        notification(type: .error)
    }
    
    /// Trigger warning notification
    static func warning() {
        notification(type: .warning)
    }
} 