import UIKit

/// Light, friendly haptics. Callers check the profile's haptics setting.
@MainActor
enum Haptics {
    static func correct() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    /// Deliberately soft — a wrong answer should never feel like a buzz of failure.
    static func gentle() {
        UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.6)
    }

    static func tap() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
}
