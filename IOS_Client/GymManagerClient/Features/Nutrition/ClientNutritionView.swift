import SwiftUI

struct ClientNutritionView: View {
    let plan: ClientNutritionPlan?
    let identity: ClientIdentity
    private var today: ClientNutritionDay? { plan?.days.first { $0.weekday == ClientDateLogic.weekday(for: Date()) } ?? plan?.days.first }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                ClientPageTitle("Nutrizione", eyebrow: "La giornata", subtitle: "Il piano pubblicato dal professionista, senza tracker o modifiche.")
                if let plan {
                    ReadOnlyPlanBadge()
                    VStack(alignment: .leading, spacing: 5) { Text(plan.title).font(.title2.weight(.bold)); if let today { Text(today.name).foregroundStyle(ClientClay.secondaryInk) } }.clayCard()
                    if let notice = plan.detailNotice { Label(notice, systemImage: "info.circle").font(.subheadline).clayCard() }
                    if let today, !today.meals.isEmpty {
                        ForEach(today.meals) { meal in
                            VStack(alignment: .leading, spacing: 12) {
                                Label(meal.name, systemImage: "fork.knife").font(.title3.weight(.semibold)).foregroundStyle(ClientClay.sage)
                                ForEach(meal.foods) { food in
                                    HStack { Text(food.name); Spacer(); Text(food.quantity.map { "\($0.formatted()) \(food.unit)" } ?? food.unit).foregroundStyle(ClientClay.secondaryInk) }
                                    if food.id != meal.foods.last?.id { Divider().opacity(0.45) }
                                }
                            }.clayCard()
                        }
                    } else {
                        ClientEmptyState(symbol: "leaf", title: "Dettagli non disponibili", message: "Il piano è pubblicato, ma i pasti di questa giornata non sono ancora consultabili.")
                    }
                } else {
                    ClientEmptyState(symbol: "leaf", title: "Nessun piano nutrizionale", message: identity.mode == .standalone ? "I piani personali arriveranno nella Fase 2; puoi già usare la tua Agenda." : "Il professionista non ha ancora pubblicato un piano attivo.")
                }
            }.padding(20)
        }.clientPage().navigationTitle("Nutrizione").navigationBarTitleDisplayMode(.inline)
    }
}
