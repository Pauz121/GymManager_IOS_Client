import SwiftUI

struct ClientUpdatesView: View {
    let updates: [ClientUpdate]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                ClientPageTitle("Aggiornamenti", eyebrow: "Il percorso evolve", subtitle: "Una bacheca di novità in sola lettura. Questa sezione non è una chat.")
                if updates.isEmpty {
                    ClientEmptyState(symbol: "bell", title: "Nessuna novità", message: "Le pubblicazioni e gli appuntamenti più recenti compariranno qui.")
                } else {
                    ForEach(updates) { update in
                        HStack(alignment: .top, spacing: 14) {
                            Image(systemName: symbol(for: update.kind)).font(.title3.weight(.semibold)).foregroundStyle(ClientClay.accent)
                                .frame(width: 42, height: 42).background(ClientClay.accent.opacity(0.11), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                            VStack(alignment: .leading, spacing: 5) {
                                Text(update.date.formatted(date: .abbreviated, time: .omitted)).font(.caption).foregroundStyle(ClientClay.secondaryInk)
                                Text(update.title).font(.headline)
                                Text(update.detail).font(.subheadline).foregroundStyle(ClientClay.secondaryInk)
                            }
                        }.clayCard()
                    }
                }
            }.padding(.horizontal, ClientClay.pagePadding).padding(.vertical, 18)
        }.clientPage().navigationTitle("Aggiornamenti").navigationBarTitleDisplayMode(.inline)
    }

    private func symbol(for kind: ClientUpdateKind) -> String {
        switch kind { case .workout: "dumbbell.fill"; case .nutrition: "leaf.fill"; case .appointment: "calendar" }
    }
}
