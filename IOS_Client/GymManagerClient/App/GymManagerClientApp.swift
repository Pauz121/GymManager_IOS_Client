import SwiftUI

@main
struct GymManagerClientApp: App {
    @StateObject private var session = ClientSessionStore()
    @StateObject private var healthKit = HealthKitStepService()
    @StateObject private var runningLocation = RunningLocationService()
    @StateObject private var avatarStore = ClientAvatarStore()
    @StateObject private var runLiveActivity = ClientRunLiveActivityManager()
    @StateObject private var appearance = ClientAppearanceStore()
    @StateObject private var restPresentation = ClientRestTimerPresentation()
    @StateObject private var restLiveActivity = ClientRestLiveActivityManager()

    var body: some Scene {
        WindowGroup {
            ClientRootView()
                .background { ClientRestTimerBridge() }
                .environmentObject(session)
                .environmentObject(healthKit)
                .environmentObject(runningLocation)
                .environmentObject(avatarStore)
                .environmentObject(runLiveActivity)
                .environmentObject(appearance)
                .environmentObject(restPresentation)
                .environmentObject(restLiveActivity)
                .tint(ClientClay.accent)
                .task { await session.prepare() }
                .onOpenURL { url in
                    Task { await session.handleAuthCallback(url) }
                }
        }
    }
}
