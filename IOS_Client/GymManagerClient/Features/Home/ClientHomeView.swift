import SwiftUI

struct ClientHomeView: View {
    let identity: ClientIdentity
    let snapshot: ClientSnapshot
    @Binding var selectedTab: ClientTab
    @EnvironmentObject private var session: ClientSessionStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                ClientPageTitle("Ciao, \(identity.firstName)", eyebrow: Date.now.formatted(.dateTime.weekday(.wide).day().month(.wide)), subtitle: "Ecco il tuo spazio per oggi.")
                ClientBadge(
                    text: identity.mode == .trainerConnected ? "Percorso con Trainer" : "Profilo autonomo",
                    tint: identity.mode == .trainerConnected ? ClientClay.sage : ClientClay.warning,
                    symbol: identity.mode == .trainerConnected ? "person.2.fill" : "figure.walk"
                )

                if let workout = snapshot.workout {
                    Button { selectedTab = .workout } label: {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack { Label("Allenamento di oggi", systemImage: "dumbbell.fill"); Spacer(); Image(systemName: "arrow.right") }
                                .font(.headline).foregroundStyle(ClientClay.accent)
                            Text(workout.sessions.first(where: { $0.id == workout.todaySessionID })?.name ?? workout.title)
                                .font(.system(.title2, design: .rounded, weight: .bold)).foregroundStyle(ClientClay.ink)
                            Text("Settimana \(workout.currentWeek) · consulta la tua scheda").font(.subheadline).foregroundStyle(ClientClay.secondaryInk)
                        }.clayCard()
                    }.buttonStyle(.plain)
                } else {
                    ClientEmptyState(symbol: "dumbbell", title: "Nessuna scheda per oggi", message: identity.mode == .standalone ? "Collega un Trainer per ricevere un piano professionale." : "Il Trainer non ha ancora pubblicato una scheda attiva.")
                }

                if let nutrition = snapshot.nutrition {
                    Button { selectedTab = .nutrition } label: {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack { Label("Nutrizione", systemImage: "leaf.fill"); Spacer(); Image(systemName: "arrow.right") }.font(.headline).foregroundStyle(ClientClay.sage)
                            Text(nutrition.title).font(.title3.weight(.semibold)).foregroundStyle(ClientClay.ink)
                            Text("Apri i pasti previsti per la giornata").font(.subheadline).foregroundStyle(ClientClay.secondaryInk)
                        }.clayCard()
                    }.buttonStyle(.plain)
                }

                if let next = snapshot.appointments.first {
                    VStack(alignment: .leading, spacing: 8) {
                        ClientBadge(text: "Fissato dal Trainer", tint: ClientClay.accent, symbol: "calendar.badge.clock")
                        Text(next.title).font(.headline)
                        Text(next.startsAt.formatted(date: .abbreviated, time: .shortened)).foregroundStyle(ClientClay.secondaryInk)
                        if let location = next.location { Label(location, systemImage: "mappin.and.ellipse").font(.subheadline) }
                    }.clayCard()
                }

                if let task = session.agenda.first(where: { !$0.isCompleted }) {
                    Button { selectedTab = .space } label: {
                        HStack { Image(systemName: "checklist").foregroundStyle(ClientClay.sage); VStack(alignment: .leading) { Text("Dalla tua Agenda").font(.caption).foregroundStyle(ClientClay.secondaryInk); Text(task.title).font(.headline).foregroundStyle(ClientClay.ink) }; Spacer(); Image(systemName: "arrow.right") }.clayCard()
                    }.buttonStyle(.plain)
                }

                ForEach(snapshot.warnings, id: \.self) { warning in
                    Label(warning, systemImage: "exclamationmark.triangle.fill").font(.footnote).foregroundStyle(ClientClay.warning).clayCard(padding: 14)
                }
            }.padding(20)
        }
        .clientPage().navigationTitle("Oggi").navigationBarTitleDisplayMode(.inline)
        .refreshable { await session.refresh() }
    }
}
