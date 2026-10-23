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
        Form {
            Section("Profilo") {
                HStack(spacing: 14) {
                    ClientProfileAvatar(image: avatarStore.image(for: identity.authUserID), initials: initials, size: 48)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(identity.displayName).font(.headline).foregroundStyle(ClientClay.ink)
                        Text(identity.email ?? identity.username).font(.subheadline).foregroundStyle(ClientClay.secondaryInk)
                    }
                }
                LabeledContent("Nome utente", value: identity.username)
                LabeledContent("Modalità", value: identity.mode == .trainerConnected ? "Cliente seguito" : "Account personale")
                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    Label(avatarStore.image(for: identity.authUserID) == nil ? "Aggiungi foto profilo" : "Cambia foto profilo", systemImage: "photo.badge.plus")
                        .frame(minHeight: 44)
                }
                if avatarStore.image(for: identity.authUserID) != nil {
                    Button("Rimuovi foto", role: .destructive) {
                        do { try avatarStore.remove(userID: identity.authUserID) }
                        catch { session.notice = "Non è stato possibile rimuovere la foto profilo." }
                    }.frame(minHeight: 44)
                }
                Text("La foto è salvata solo su questo iPhone. Nome e dati account sono attualmente in sola lettura.")
                    .font(.footnote).foregroundStyle(ClientClay.secondaryInk)
            }
            Section("Trainer") {
                if identity.mode == .trainerConnected {
                    Label(identity.trainerName ?? "Trainer collegato", systemImage: "person.crop.circle.badge.checkmark")
                        .font(.headline)
                    Text("Allenamento e nutrizione sono gestiti dal Trainer. I tuoi piani personali precedenti restano nello storico.")
                        .font(.subheadline).foregroundStyle(ClientClay.secondaryInk)
                    Label("Il collegamento non può essere rimosso dall’app.", systemImage: "lock.shield")
                        .font(.footnote).foregroundStyle(ClientClay.secondaryInk)
                } else {
                    Text("Nessun Trainer collegato").font(.headline)
                    if source == .live {
                        TrainerCodeEntryForm(code: $trainerCode, actionTitle: "Collega il mio Trainer") {
                            await session.connectTrainer(code: trainerCode)
                        }
                    } else {
                        Text("La demo non invia né consuma codici reali.").font(.footnote)
                    }
                }
            }
            Section("Preferenze") {
                NavigationLink { ClientAppearanceView() } label: { Label("Aspetto", systemImage: "circle.lefthalf.filled") }
                LabeledContent("Unità di misura", value: "kg · cm")
            }
            Section("Sicurezza") {
                if source == .live {
                    DisclosureGroup("Cambia password") {
                        SecureField("Nuova password", text: $password).textContentType(.newPassword)
                        SecureField("Conferma password", text: $confirmation).textContentType(.newPassword)
                        Button("Aggiorna password") {
                            guard password == confirmation else { session.notice = "Le password non coincidono."; return }
                            Task { await session.updatePassword(password); password = ""; confirmation = "" }
                        }
                        .frame(minHeight: 44)
                        .disabled(session.isSubmitting || password.isEmpty || confirmation.isEmpty)
                    }
                } else {
                    Text("La demo non modifica credenziali.").font(.subheadline)
                }
            }
            Section("Privacy e assistenza") {
                NavigationLink { ClientAccountInformationView(topic: .privacy) } label: { Label("Privacy", systemImage: "hand.raised") }
                NavigationLink { ClientAccountInformationView(topic: .support) } label: { Label("Supporto", systemImage: "questionmark.circle") }
            }
            Section {
                NavigationLink { ClientAccountInformationView(topic: .deletion) } label: {
                    Label("Elimina account", systemImage: "trash").foregroundStyle(ClientClay.color(.error))
                }
                Button(role: .destructive) { Task { await session.signOut() } } label: {
                    Label("Esci dal mio account", systemImage: "rectangle.portrait.and.arrow.right").frame(minHeight: 44)
                }
            } footer: {
                Text("Eliminazione: percorso server Client non ancora disponibile. Nessuna cancellazione viene simulata sul dispositivo.")
            }
        }
        .scrollContentBackground(.hidden)
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
