import SwiftUI

@main
struct GymManagerClientApp: App {
    @StateObject private var session = ClientSessionStore()
    @StateObject private var healthKit = HealthKitStepService()
    @StateObject private var runningLocation = RunningLocationService()

    var body: some Scene {
        WindowGroup {
            ClientRootView()
                .environmentObject(session)
                .environmentObject(healthKit)
                .environmentObject(runningLocation)
                .tint(ClientClay.accent)
                .task { await session.prepare() }
        }
    }
}
