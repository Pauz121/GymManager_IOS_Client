import SwiftUI

@main
struct GymManagerClientApp: App {
    @StateObject private var session = ClientSessionStore()

    var body: some Scene {
        WindowGroup {
            ClientRootView()
                .environmentObject(session)
                .tint(ClientClay.accent)
                .task { await session.prepare() }
        }
    }
}
