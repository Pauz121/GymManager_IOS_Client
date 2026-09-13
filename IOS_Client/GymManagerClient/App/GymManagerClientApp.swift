import SwiftUI

@main
struct GymManagerClientApp: App {
    @StateObject private var session = ClientSessionStore()
    @StateObject private var healthKit = HealthKitStepService()
    @StateObject private var runningLocation = RunningLocationService()
    @StateObject private var avatarStore = ClientAvatarStore()
    @StateObject private var runLiveActivity = ClientRunLiveActivityManager()

    var body: some Scene {
        WindowGroup {
            ClientRootView()
                .environmentObject(session)
                .environmentObject(healthKit)
                .environmentObject(runningLocation)
                .environmentObject(avatarStore)
                .environmentObject(runLiveActivity)
                .tint(ClientClay.accent)
                .task { await session.prepare() }
        }
    }
}
