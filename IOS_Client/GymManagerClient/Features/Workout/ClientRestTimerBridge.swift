import SwiftUI

/// One app-scoped adapter, not one timer per view. No decrement loop.
struct ClientRestTimerBridge: View {
    @EnvironmentObject private var session: ClientSessionStore
    @EnvironmentObject private var liveActivity: ClientRestLiveActivityManager
    @Environment(\.scenePhase) private var scenePhase

    private var displayState: ClientRestActivityAttributes.ContentState? {
        guard let timer = session.activity.restTimer else { return nil }
        var exercises: [ClientExercise] = []
        if case .active(_, let snapshot, _) = session.state {
            exercises = snapshot.workout?.sessions.flatMap(\.exercises) ?? []
        }
        if exercises.isEmpty { exercises = session.personalContent.activeWorkout?.asClientPlan().sessions.flatMap(\.exercises) ?? [] }
        return .init(endsAt: timer.endsAt, pausedSeconds: timer.phase == .paused ? timer.remainingSeconds() : nil,
                     exerciseName: exercises.first { $0.id == timer.exerciseID }?.name,
                     nextSetNumber: timer.nextSetNumber, finished: false)
    }
    var body: some View {
        Color.clear.frame(width: 0, height: 0)
            .task(id: displayState) {
                let state = displayState
                await liveActivity.synchronize(state)
                guard let end = state?.endsAt else { return }
                let delay = max(0, end.timeIntervalSinceNow)
                do { try await Task.sleep(for: .seconds(delay)) } catch { return }
                session.finishRestTimerIfElapsed()
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { session.finishRestTimerIfElapsed() }
            }
    }
}
