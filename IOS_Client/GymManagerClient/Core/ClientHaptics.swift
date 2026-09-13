import UIKit

enum ClientHaptics {
    static func completedSet() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    static func timerFinished() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    static func workoutFinished() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    static func selection() {
        UISelectionFeedbackGenerator().selectionChanged()
    }
}
