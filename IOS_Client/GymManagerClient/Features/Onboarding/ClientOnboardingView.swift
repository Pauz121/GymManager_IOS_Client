import SwiftUI

struct ClientOnboardingView: View {
    enum Path: Hashable { case trainerCode, standalone, signIn }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Spacer(minLength: 28)
                    ZStack {
                        Circle().fill(ClientClay.accentSoft).frame(width: 88, height: 88)
                            .shadow(color: ClientClay.ink.opacity(0.08), radius: 14, x: 7, y: 9)
                        Image(systemName: "figure.mind.and.body").font(.system(size: 40, weight: .semibold)).foregroundStyle(ClientClay.accent)
                    }
                    ClientPageTitle("Il tuo percorso, ogni giorno.", eyebrow: "GymManager Client", subtitle: "Allenamento, nutrizione e progressi in uno spazio semplice, personale e sempre con te.")

                    VStack(spacing: 13) {
                        NavigationLink(value: Path.trainerCode) { Label("Ho un codice dal mio Trainer", systemImage: "link.badge.plus") }
                            .buttonStyle(ClayPrimaryButtonStyle())
                        NavigationLink(value: Path.standalone) { Label("Non ho un Trainer", systemImage: "figure.walk") }
                            .buttonStyle(ClaySecondaryButtonStyle())
                        NavigationLink(value: Path.signIn) { Text("Hai già un account? Accedi") }
                            .font(.subheadline.weight(.semibold)).foregroundStyle(ClientClay.accent).padding(.top, 5)
                    }
                    .clayCard()

                    #if DEBUG
                    DemoEntryButton()
                    #endif
                }
                .padding(20)
            }
            .clientPage()
            .navigationDestination(for: Path.self) { path in
                switch path {
                case .trainerCode: TrainerCodeView()
                case .standalone: StandaloneEntryView()
                case .signIn: ClientSignInView()
                }
            }
        }
    }
}

private struct TrainerCodeView: View {
    @State private var code = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                ClientPageTitle("Collegati al Trainer", eyebrow: "Percorso guidato", subtitle: "Il codice collegherà il tuo account alla scheda Cliente già creata dal professionista, senza duplicarla.")
                VStack(alignment: .leading, spacing: 12) {
                    TextField("Codice Trainer", text: $code).textInputAutocapitalization(.characters).textContentType(.oneTimeCode)
                        .padding(15).background(.white.opacity(0.72), in: RoundedRectangle(cornerRadius: 14))
                    Button("Collega il mio account") {}.buttonStyle(ClayPrimaryButtonStyle()).disabled(true)
                    Label("Attivazione sicura in preparazione. In questa fase nessun codice viene inviato o consumato.", systemImage: "lock.shield")
                        .font(.footnote).foregroundStyle(ClientClay.secondaryInk)
                }.clayCard()
                NavigationLink("Ho già ricevuto l’accesso · Accedi") { ClientSignInView() }
                    .buttonStyle(ClaySecondaryButtonStyle())
            }.padding(20)
        }.clientPage().navigationTitle("Codice Trainer").navigationBarTitleDisplayMode(.inline)
    }
}

private struct StandaloneEntryView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                ClientPageTitle("Inizia dal tuo spazio", eyebrow: "Modalità autonoma", subtitle: "L’Agenda personale sarà disponibile anche senza Trainer. I piani personali arriveranno nella Fase 2.")
                ClientEmptyState(symbol: "person.crop.circle.badge.plus", title: "Registrazione in preparazione", message: "Non creeremo un account finché il servizio sicuro non sarà attivo.")
                NavigationLink("Ho già un account · Accedi") { ClientSignInView() }.buttonStyle(ClayPrimaryButtonStyle())
            }.padding(20)
        }.clientPage().navigationTitle("Senza Trainer").navigationBarTitleDisplayMode(.inline)
    }
}

private struct ClientSignInView: View {
    @EnvironmentObject private var session: ClientSessionStore
    @State private var identifier = ""
    @State private var password = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                ClientPageTitle("Bentornato", eyebrow: "Accesso Cliente", subtitle: "Usa le credenziali del tuo account Cliente.")
                VStack(spacing: 14) {
                    TextField("Email o username", text: $identifier).textContentType(.username).textInputAutocapitalization(.never).autocorrectionDisabled()
                    SecureField("Password", text: $password).textContentType(.password)
                    Button { Task { await session.signIn(identifier: identifier, password: password) } } label: {
                        if session.isSubmitting { ProgressView().tint(.white) } else { Text("Accedi") }
                    }.buttonStyle(ClayPrimaryButtonStyle()).disabled(session.isSubmitting)
                }
                .textFieldStyle(.roundedBorder).clayCard()
            }.padding(20)
        }.clientPage().navigationTitle("Accesso").navigationBarTitleDisplayMode(.inline)
    }
}

#if DEBUG
private struct DemoEntryButton: View {
    @EnvironmentObject private var session: ClientSessionStore
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Account demo").font(.headline)
            Text("Dati sintetici, nessun accesso reale e nessuna password salvata.")
                .font(.caption).foregroundStyle(ClientClay.secondaryInk)
            Button { session.startDemo(.trainerConnected) } label: {
                Label("Demo · Cliente con Trainer", systemImage: "person.2.fill")
            }
            .buttonStyle(ClaySecondaryButtonStyle())
            Button { session.startDemo(.standalone) } label: {
                Label("Demo · Cliente autonomo", systemImage: "figure.walk")
            }
            .buttonStyle(ClaySecondaryButtonStyle())
        }
        .clayCard()
        .accessibilityHint("Apre dati fittizi e non crea una sessione reale")
    }
}
#endif
