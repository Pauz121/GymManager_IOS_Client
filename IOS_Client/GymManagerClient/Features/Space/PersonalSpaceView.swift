import SwiftUI

struct PersonalSpaceView: View {
    let identity: ClientIdentity
    let snapshot: ClientSnapshot
    let source: ClientDataSource
    @EnvironmentObject private var session: ClientSessionStore
    @EnvironmentObject private var avatarStore: ClientAvatarStore
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                ClientPageTitle("Il tuo spazio", eyebrow: "Personale", subtitle: "Agenda privata, novità del percorso e account.")
                profileLink
                emailVerificationCard
                destination("La mia Agenda", detail: "Attività e promemoria salvati solo su questo dispositivo", symbol: "checklist") { PersonalAgendaView(appointments: snapshot.appointments) }
                destination("Aggiornamenti", detail: "Le novità del tuo percorso · non è una chat", symbol: "bell.badge") { ClientUpdatesView(updates: snapshot.updates) }
            }.padding(.horizontal, ClientClay.pagePadding).padding(.vertical, 18)
        }
        .clientPage().navigationTitle("Spazio").navigationBarTitleDisplayMode(.inline)
        .task(id: identity.authUserID) {
            guard source == .live else { return }
            await session.refreshEmailVerification()
        }
        .onChange(of: scenePhase) { _, phase in
            guard source == .live, phase == .active else { return }
            Task { await session.refreshEmailVerification() }
        }
    }

    private var profileLink: some View {
        NavigationLink {
            ClientAccountView(identity: identity, source: source)
        } label: {
            HStack(spacing: 12) {
                ClientProfileAvatar(
                    image: avatarStore.image(for: identity.authUserID),
                    initials: initials,
                    size: 44
                )
                VStack(alignment: .leading, spacing: 3) {
                    Text(identity.displayName)
                        .font(.headline.weight(.bold)).foregroundStyle(ClientClay.ink)
                        .lineLimit(1)
                    Text(identity.email ?? identity.username)
                        .font(.caption).foregroundStyle(ClientClay.secondaryInk)
                        .lineLimit(1)
                    HStack(spacing: 8) {
                        Label(
                            identity.mode == .trainerConnected ? "Trainer collegato" : "Profilo autonomo",
                            systemImage: identity.mode == .trainerConnected ? "person.2.fill" : "person.fill"
                        )
                        .foregroundStyle(identity.mode == .trainerConnected ? ClientClay.sage : ClientClay.warning)
                        if case .verified = session.emailVerificationStatus {
                            Label("Email verificata", systemImage: "checkmark.seal.fill")
                                .foregroundStyle(ClientClay.sage)
                        }
                    }
                    .font(.caption2.weight(.semibold))
                    .lineLimit(1)
                }
                Spacer(minLength: 4)
                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.bold)).foregroundStyle(ClientClay.secondaryInk)
            }
            .padding(13)
            .frame(maxWidth: .infinity, minHeight: 68, alignment: .leading)
            .background(ClientClay.surfaceElevated, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay { RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(ClientClay.border) }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint("Apre profilo, Trainer e sicurezza")
    }

    @ViewBuilder
    private var emailVerificationCard: some View {
        if source == .live, case .unverified(let email) = session.emailVerificationStatus {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 11) {
                    Image(systemName: "envelope.badge.fill")
                        .font(.headline).foregroundStyle(ClientClay.warning)
                        .frame(width: 38, height: 38)
                        .background(ClientClay.warning.opacity(0.13), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Email non verificata").font(.headline).foregroundStyle(ClientClay.ink)
                        Text(email).font(.caption.weight(.semibold)).foregroundStyle(ClientClay.warning).lineLimit(1)
                        Text("Conferma l’indirizzo per completare e proteggere il profilo.")
                            .font(.caption).foregroundStyle(ClientClay.secondaryInk)
                    }
                }
                Button {
                    Task { await session.resendEmailVerification(to: email) }
                } label: {
                    Label("Invia email di conferma", systemImage: "paperplane.fill")
                        .font(.subheadline.weight(.bold))
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(ClientClay.warning.opacity(0.13), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                }
                .buttonStyle(.plain)
                .foregroundStyle(ClientClay.warning)
                .disabled(session.isSubmitting)
            }
            .clayCard(padding: 14)
        }
    }

    private var initials: String {
        "\(identity.firstName.first.map(String.init) ?? "")\(identity.lastName.first.map(String.init) ?? "")"
    }

    private func destination<Destination: View>(_ title: String, detail: String, symbol: String, @ViewBuilder destination: () -> Destination) -> some View {
        NavigationLink(destination: destination()) {
            HStack(spacing: 14) {
                Image(systemName: symbol).font(.title3.weight(.semibold)).foregroundStyle(ClientClay.accent)
                    .frame(width: 40, height: 40).background(ClientClay.accent.opacity(0.11), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                VStack(alignment: .leading, spacing: 4) { Text(title).font(.headline).foregroundStyle(ClientClay.ink); Text(detail).font(.caption).foregroundStyle(ClientClay.secondaryInk) }
                Spacer(); Image(systemName: "chevron.right").foregroundStyle(ClientClay.secondaryInk)
            }.clayCard()
        }.buttonStyle(.plain)
    }
}
