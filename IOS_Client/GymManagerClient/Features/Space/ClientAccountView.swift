import PhotosUI
import SwiftUI

struct ClientAccountView: View {
    let identity: ClientIdentity
    let source: ClientDataSource
    @EnvironmentObject private var session: ClientSessionStore
    @EnvironmentObject private var avatarStore: ClientAvatarStore
    @State private var trainerCode = ""
    @State private var password = ""
    @State private var confirmation = ""
    @State private var selectedPhoto: PhotosPickerItem?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                ClientPageTitle("Account", eyebrow: "Profilo e sicurezza", subtitle: "Le tue informazioni e lo stato del percorso.")
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        ClientProfileAvatar(image: avatarStore.image(for: identity.authUserID), initials: initials)
                        VStack(alignment: .leading) { Text(identity.displayName).font(.title2.weight(.bold)); Text(identity.email ?? identity.username).font(.subheadline).foregroundStyle(ClientClay.secondaryInk) }
                    }
                    PhotosPicker(selection: $selectedPhoto, matching: .images) {
                        Label(avatarStore.image(for: identity.authUserID) == nil ? "Aggiungi foto profilo" : "Cambia foto profilo", systemImage: "photo.badge.plus")
                    }
                    .buttonStyle(ClaySecondaryButtonStyle())
                    if avatarStore.image(for: identity.authUserID) != nil {
                        Button(role: .destructive) {
                            do { try avatarStore.remove(userID: identity.authUserID) }
                            catch { session.notice = "Non è stato possibile rimuovere la foto profilo." }
                        } label: {
                            Label("Rimuovi foto", systemImage: "trash")
                        }
                        .font(.subheadline.weight(.semibold))
                    }
                    Text("La foto resta protetta su questo iPhone e non viene caricata sul profilo online.")
                        .font(.caption).foregroundStyle(ClientClay.secondaryInk)
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
        }
        .clientPage().navigationTitle("Account").navigationBarTitleDisplayMode(.inline)
        .task(id: identity.authUserID) { avatarStore.load(userID: identity.authUserID) }
        .onChange(of: selectedPhoto) { _, item in
            guard let item else { return }
            Task {
                do {
                    guard let data = try await item.loadTransferable(type: Data.self) else {
                        throw ClientAppError.message("La foto selezionata non contiene un’immagine leggibile.")
                    }
                    try avatarStore.save(data, userID: identity.authUserID)
                } catch {
                    session.notice = (error as? LocalizedError)?.errorDescription ?? "Non è stato possibile salvare la foto profilo."
                }
                selectedPhoto = nil
            }
        }
    }

    private var initials: String { "\(identity.firstName.first.map(String.init) ?? "")\(identity.lastName.first.map(String.init) ?? "")" }
}
