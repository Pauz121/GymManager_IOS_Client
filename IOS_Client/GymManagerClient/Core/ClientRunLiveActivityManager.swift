import ActivityKit
import Combine
import Foundation

@MainActor
final class ClientRunLiveActivityManager: ObservableObject {
    @Published private(set) var isActive = false

    private var activity: Activity<ClientRunActivityAttributes>?
    private var lastUpdateAt = Date.distantPast
    private var lastDistanceMeters: Double = 0

    init() {
        activity = Activity<ClientRunActivityAttributes>.activities.first
        isActive = activity != nil
    }

    func start(planTitle: String, elapsedSeconds: TimeInterval = 0) async {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        if let existing = Activity<ClientRunActivityAttributes>.activities.first {
            activity = existing
            isActive = true
            return
        }
        let state = makeState(distanceMeters: 0, elapsedSeconds: elapsedSeconds, isPaused: false, displayMode: "pace")
        do {
            activity = try Activity.request(
                attributes: ClientRunActivityAttributes(planTitle: planTitle),
                content: ActivityContent(state: state, staleDate: nil),
                pushType: nil
            )
            isActive = true
        } catch {
            isActive = false
        }
    }

    func update(
        elapsedSeconds: TimeInterval,
        distanceMeters: Double,
        isPaused: Bool,
        displayMode: String,
        force: Bool = false
    ) async {
        guard let currentActivity = activity else { return }
        // Xcode 26.4 marks ActivityKit update/end as @concurrent while
        // Activity itself is not Sendable. ActivityKit owns synchronization;
        // keep the escape hatch limited to this immutable SDK reference.
        nonisolated(unsafe) let activityForUpdate = currentActivity
        let now = Date()
        guard force || now.timeIntervalSince(lastUpdateAt) >= 5 || abs(distanceMeters - lastDistanceMeters) >= 20 else { return }
        let state = makeState(
            distanceMeters: distanceMeters,
            elapsedSeconds: elapsedSeconds,
            isPaused: isPaused,
            displayMode: displayMode
        )
        await activityForUpdate.update(ActivityContent(state: state, staleDate: now.addingTimeInterval(30)))
        lastUpdateAt = now
        lastDistanceMeters = distanceMeters
    }

    func end(elapsedSeconds: TimeInterval, distanceMeters: Double, displayMode: String) async {
        guard let currentActivity = activity else { return }
        nonisolated(unsafe) let activityForEnd = currentActivity
        let finalState = makeState(
            distanceMeters: distanceMeters,
            elapsedSeconds: elapsedSeconds,
            isPaused: true,
            displayMode: displayMode
        )
        await activityForEnd.end(
            ActivityContent(state: finalState, staleDate: nil),
            dismissalPolicy: .after(Date().addingTimeInterval(120))
        )
        self.activity = nil
        isActive = false
    }

    private func makeState(
        distanceMeters: Double,
        elapsedSeconds: TimeInterval,
        isPaused: Bool,
        displayMode: String
    ) -> ClientRunActivityAttributes.ContentState {
        let safeElapsed = max(0, Int(elapsedSeconds.rounded()))
        let distanceKm = distanceMeters / 1_000
        let pace = distanceKm > 0.02 ? Int((Double(safeElapsed) / distanceKm).rounded()) : nil
        let speed = safeElapsed > 0 ? distanceKm / (Double(safeElapsed) / 3_600) : nil
        return .init(
            distanceMeters: max(0, distanceMeters),
            elapsedSeconds: safeElapsed,
            timerAnchor: isPaused ? nil : Date().addingTimeInterval(-Double(safeElapsed)),
            averagePaceSecondsPerKm: pace,
            averageSpeedKmh: speed,
            displayMode: displayMode,
            isPaused: isPaused
        )
    }
}
