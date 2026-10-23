import SwiftUI

struct ClientRootView: View {
    @EnvironmentObject private var session: ClientSessionStore
    @EnvironmentObject private var appearance: ClientAppearanceStore

    var body: some View {
        Group {
            switch session.state {
            case .loading:
                ZStack {
                    ClientClay.canvas.ignoresSafeArea()
                    VStack(spacing: 16) {
                        Image(systemName: "figure.strengthtraining.traditional")
                            .font(.system(size: 46, weight: .semibold)).foregroundStyle(ClientClay.accent)
                        if session.readPhase == .idle {
                            Text("Caricamento in pausa").foregroundStyle(ClientClay.secondaryInk)
                            Button("Riprova") { Task { await session.prepare() } }
                        } else {
                            ProgressView("Prepariamo il tuo spazio…").tint(ClientClay.accent)
                        }
                    }
                }
            case .onboarding:
                ClientOnboardingView()
            case .emailConfirmation(let email):
                ClientEmailConfirmationView(email: email)
            case .active(let identity, let snapshot, let source):
                ClientTabView(identity: identity, snapshot: snapshot, source: source)
                    .clientFloatingRestTimer()
                    .fullScreenCover(isPresented: Binding(
                        get: { session.shouldOfferTrainerCode },
                        set: { _ in }
                    )) {
                        ClientTrainerInvitationView()
                            .interactiveDismissDisabled()
                    }
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
        // Phase7 adoption completed in source: sheets and navigation inherit the
        // same preference; System delegates to iOS instead of a second override.
        .clientAppearance(appearance.preference)
        .alert("GymManager", isPresented: Binding(
            get: { session.notice != nil },
            set: { if !$0 { session.notice = nil } }
        )) { Button("OK", role: .cancel) { session.notice = nil } } message: {
            Text(session.notice ?? "")
        }
    }
}
