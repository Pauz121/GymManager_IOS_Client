import SwiftUI

struct ClientRootView: View {
    @EnvironmentObject private var session: ClientSessionStore

    var body: some View {
        Group {
            switch session.state {
            case .loading:
                ZStack {
                    ClientClay.canvas.ignoresSafeArea()
                    VStack(spacing: 16) {
                        Image(systemName: "figure.strengthtraining.traditional")
                            .font(.system(size: 46, weight: .semibold)).foregroundStyle(ClientClay.accent)
                        ProgressView("Prepariamo il tuo spazio…").tint(ClientClay.accent)
                    }
                }
            case .onboarding:
                ClientOnboardingView()
            case .active(let identity, let snapshot, let source):
                ClientTabView(identity: identity, snapshot: snapshot, source: source)
            case .failure(let message):
                ZStack {
                    ClientClay.canvas.ignoresSafeArea()
                    VStack(spacing: 18) {
                        ClientFailureView(message: message) { Task { await session.prepare() } }
                        Button("Torna all’accesso") { session.showOnboarding() }
                    }
                    .padding()
                }
            }
        }
        .preferredColorScheme(.light)
        .alert("GymManager", isPresented: Binding(
            get: { session.notice != nil },
            set: { if !$0 { session.notice = nil } }
        )) { Button("OK", role: .cancel) { session.notice = nil } } message: {
            Text(session.notice ?? "")
        }
    }
}
