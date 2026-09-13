import SwiftUI

struct PersonalSpaceView: View {
    let identity: ClientIdentity
    let snapshot: ClientSnapshot
    let source: ClientDataSource

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                ClientPageTitle("Il tuo spazio", eyebrow: "Personale", subtitle: "Agenda privata, novità del percorso e account.")
                VStack(alignment: .leading, spacing: 8) {
                    Text(identity.displayName).font(.title2.weight(.bold))
                    ClientBadge(text: identity.mode == .trainerConnected ? "Collegato al Trainer" : "Profilo autonomo", tint: identity.mode == .trainerConnected ? ClientClay.sage : ClientClay.warning, symbol: "person.2.fill")
                }.clayCard()
                destination("La mia Agenda", detail: "Attività e promemoria salvati solo su questo dispositivo", symbol: "checklist") { PersonalAgendaView(appointments: snapshot.appointments) }
                destination("Aggiornamenti", detail: "Le novità del tuo percorso · non è una chat", symbol: "bell.badge") { ClientUpdatesView(updates: snapshot.updates) }
                destination("Account", detail: "Profilo, Trainer, sicurezza e assistenza", symbol: "person.crop.circle") { ClientAccountView(identity: identity, source: source) }
            }.padding(20)
        }.clientPage().navigationTitle("Spazio").navigationBarTitleDisplayMode(.inline)
    }

    private func destination<Destination: View>(_ title: String, detail: String, symbol: String, @ViewBuilder destination: () -> Destination) -> some View {
        NavigationLink(destination: destination()) {
            HStack(spacing: 14) {
                Image(systemName: symbol).font(.title2).foregroundStyle(ClientClay.accent).frame(width: 32)
                VStack(alignment: .leading, spacing: 4) { Text(title).font(.headline).foregroundStyle(ClientClay.ink); Text(detail).font(.caption).foregroundStyle(ClientClay.secondaryInk) }
                Spacer(); Image(systemName: "chevron.right").foregroundStyle(ClientClay.secondaryInk)
            }.clayCard()
        }.buttonStyle(.plain)
    }
}
