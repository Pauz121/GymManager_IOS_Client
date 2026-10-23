import ActivityKit
import Combine
import Foundation
import UserNotifications

/// Presentation adapter only; timer truth remains session.activity.restTimer.
@MainActor
final class ClientRestLiveActivityManager: ObservableObject {
    private var queue: Task<Void, Never>?
    private let notificationID = "gymmanager.rest.finished"

    func synchronize(_ state: ClientRestActivityAttributes.ContentState?) async {
        let previous = queue
        let operation = Task { @MainActor [weak self] in
            await previous?.value
            guard let self else { return }
            await self.apply(state)
        }
        queue = operation
        await operation.value
    }

    private func apply(_ state: ClientRestActivityAttributes.ContentState?) async {
        let notifications = UNUserNotificationCenter.current()
        notifications.removePendingNotificationRequests(withIdentifiers: [notificationID])
        let existing = Activity<ClientRestActivityAttributes>.activities
        guard let state else {
            for current in existing {
                nonisolated(unsafe) let activityForEnd = current // Same SDK boundary as existing Running manager.
                let old = current.content.state
                let final = ClientRestActivityAttributes.ContentState(endsAt: nil, pausedSeconds: nil,
                    exerciseName: old.exerciseName, nextSetNumber: old.nextSetNumber, finished: true)
                await activityForEnd.end(ActivityContent(state: final, staleDate: nil), dismissalPolicy: .immediate)
            }
            return
        }
        if let end = state.endsAt, end > Date() {
            let settings = await notifications.notificationSettings()
            if settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional {
                let content = UNMutableNotificationContent()
                content.title = "Recupero terminato"
                content.body = "Pronto per la prossima serie."
                if settings.soundSetting == .enabled { content.sound = .default }
                let request = UNNotificationRequest(identifier: notificationID, content: content,
                    trigger: UNTimeIntervalNotificationTrigger(timeInterval: max(1, end.timeIntervalSinceNow), repeats: false))
                try? await notifications.add(request)
            }
        }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        if let current = existing.first {
            nonisolated(unsafe) let activityForUpdate = current
            await activityForUpdate.update(ActivityContent(state: state, staleDate: state.endsAt))
            // Defensive cleanup of old duplicates of THIS type only; running untouched.
            for duplicate in existing.dropFirst() {
                nonisolated(unsafe) let duplicateForEnd = duplicate
                await duplicateForEnd.end(nil, dismissalPolicy: .immediate)
            }
        } else {
            do {
                _ = try Activity.request(attributes: ClientRestActivityAttributes(title: "GymManager · Recupero"),
                                         content: ActivityContent(state: state, staleDate: state.endsAt), pushType: nil)
            } catch {
                // Live Activity is optional; never fail the real workout/timer.
                #if DEBUG
                ClientLoadDiagnostics.record("WORKOUT", requestID: UUID(), event: "failure", stage: "rest_live_activity", code: "unavailable")
                #endif
            }
        }
    }
}
