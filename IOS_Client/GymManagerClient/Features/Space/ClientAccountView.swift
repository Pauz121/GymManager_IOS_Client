import SwiftUI

struct ClientAccountView: View {
    let identity: ClientIdentity
    let source: ClientDataSource
    @EnvironmentObject private var session: ClientSessionStore
    @State private var trainerCode = ""
    @State private var password = ""
    @State private var confirmation = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                ClientPageTitle("Account", eyebrow: "Profilo e sicurezza", subtitle: "Le tue informazioni e lo stato del percorso.")
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text(initials).font(.title2.weight(.bold)).foregroundStyle(.white).frame(width: 58, height: 58).background(ClientClay.accent, in: Circle())
                        VStack(alignment: .leading) { Text(identity.displayName).font(.title2.weight(.bold)); Text(identity.email ?? identity.username).font(.subheadline).foregroundStyle(ClientClay.secondaryInk) }
                    }
                    ClientBadge(text: identity.mode == .trainerConnected ? "Cliente seguito" : "Account personale", tint: identity.mode == .trainerConnected ? ClientClay.sage : ClientClay.warning)
                }.clayCard()

                VStack(alignment: .leading, spacing: 12) {
                    Text(identity.mode == .trainerConnected ? "Il mio Trainer" : "Collega un Trainer").font(.title3.weight(.bold))
                    if identity.mode == .trainerConnected {
                        Text(identity.trainerName ?? "Trainer collegato").font(.headline)
                        Label("Il collegamento è protetto e non può essere rimosso dall’app.", systemImage: "lock.shield").font(.footnote).foregroundStyle(ClientClay.secondaryInk)
                    } else {
                        Text("Hai ricevuto un codice? Il servizio di attivazione sicura arriverà nella Fase 2.").font(.subheadline).foregroundStyle(ClientClay.secondaryInk)
                        TextField("Codice Trainer", text: $trainerCode).textFieldStyle(.roundedBorder).textInputAutocapitalization(.characters)
                        Button("Collega il mio Trainer") {}.buttonStyle(ClaySecondaryButtonStyle()).disabled(true)
                        Text("Nessun codice viene inviato o consumato.").font(.caption).foregroundStyle(ClientClay.secondaryInk)
                    }
                }.clayCard()

                VStack(alignment: .leading, spacing: 12) {
                    Text("Sicurezza").font(.title3.weight(.bold))
                    if source == .live {
                        SecureField("Nuova password", text: $password).textContentType(.newPassword).textFieldStyle(.roundedBorder)
                        SecureField("Conferma password", text: $confirmation).textContentType(.newPassword).textFieldStyle(.roundedBorder)
                        Button("Aggiorna password") {
                            guard password == confirmation else { session.notice = "Le password non coincidono."; return }
                            Task { await session.updatePassword(password); password = ""; confirmation = "" }
                        }
                        .buttonStyle(ClaySecondaryButtonStyle())
                        .disabled(session.isSubmitting || password.isEmpty || confirmation.isEmpty)
                    } else {
                        Text("La demo non crea né modifica credenziali.").font(.subheadline).foregroundStyle(ClientClay.secondaryInk)
                    }
                }.clayCard()

                VStack(alignment: .leading, spacing: 12) {
                    Text("Preferenze").font(.title3.weight(.bold))
                    LabeledContent("Unità di misura", value: "kg · cm")
                    LabeledContent("Aspetto", value: "Chiaro")
                    LabeledContent("Notifiche", value: "Fase 2")
                }.clayCard()

                VStack(alignment: .leading, spacing: 12) {
                    Text("Privacy e assistenza").font(.title3.weight(.bold))
                    Text("I riferimenti ufficiali saranno collegati prima della pubblicazione.").font(.subheadline).foregroundStyle(ClientClay.secondaryInk)
                    Button("Privacy") {}.disabled(true)
                    Button("Termini") {}.disabled(true)
                    Button("Supporto") {}.disabled(true)
                }.clayCard()

                Button(role: .destructive) { Task { await session.signOut() } } label: { Label("Esci dal mio account", systemImage: "rectangle.portrait.and.arrow.right") }
                    .buttonStyle(ClaySecondaryButtonStyle())
            }.padding(20)
        }.clientPage().navigationTitle("Account").navigationBarTitleDisplayMode(.inline)
    }

    private var initials: String { "\(identity.firstName.first.map(String.init) ?? "")\(identity.lastName.first.map(String.init) ?? "")" }
}
