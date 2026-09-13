import SwiftUI

struct ClientNutritionView: View {
    let plan: ClientNutritionPlan?
    let identity: ClientIdentity
    @EnvironmentObject private var session: ClientSessionStore

    private var today: ClientNutritionDay? {
        plan?.days.first { $0.weekday == ClientDateLogic.weekday(for: Date()) } ?? plan?.days.first
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                ClientPageTitle("Nutrizione", eyebrow: "Oggi", subtitle: "Segna con calma i pasti completati e consulta le quantità indicate.")
                if let plan {
                    ReadOnlyPlanBadge()
                    VStack(alignment: .leading, spacing: 8) {
                        Text(plan.title).font(.title2.weight(.bold))
                        if let today { Text(today.name).foregroundStyle(ClientClay.secondaryInk) }
                        if let today, !today.meals.isEmpty {
                            let completed = today.meals.filter { session.activity.isMealCompleted($0.id) }.count
                            ProgressView(value: Double(completed), total: Double(today.meals.count)).tint(ClientClay.sage)
                            Text("\(completed) / \(today.meals.count) pasti completati")
                                .font(.caption).foregroundStyle(ClientClay.secondaryInk)
                        }
                    }
                    .clayCard()

                    if let notice = plan.detailNotice {
                        Label(notice, systemImage: "info.circle").font(.subheadline).clayCard()
                    }

                    if let today, !today.meals.isEmpty {
                        ForEach(today.meals) { meal in mealCard(meal) }
                    } else {
                        ClientEmptyState(symbol: "leaf", title: "Dettagli non disponibili", message: "Il piano è pubblicato, ma i pasti di questa giornata non sono ancora consultabili.")
                    }
                } else {
                    ClientEmptyState(
                        symbol: "leaf",
                        title: "Nessun piano nutrizionale",
                        message: identity.mode == .standalone ? "I piani personali arriveranno nella prossima fase; puoi già usare la tua Agenda." : "Il professionista non ha ancora pubblicato un piano attivo."
                    )
                }
            }
            .padding(20)
        }
        .clientPage()
        .navigationTitle("Nutrizione")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func mealCard(_ meal: ClientMeal) -> some View {
        let completed = session.activity.isMealCompleted(meal.id)
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Button { session.toggleMealCompletion(meal.id) } label: {
                    Image(systemName: completed ? "checkmark.circle.fill" : "circle")
                        .font(.title2).foregroundStyle(completed ? ClientClay.sage : ClientClay.secondaryInk)
                        .frame(width: 48, height: 48)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(completed ? "Segna \(meal.name) come da completare" : "Segna \(meal.name) come completato")
                VStack(alignment: .leading, spacing: 2) {
                    Text(meal.name).font(.title3.weight(.semibold)).foregroundStyle(ClientClay.ink)
                    Text(completed ? "Pasto completato" : "Da completare")
                        .font(.caption).foregroundStyle(completed ? ClientClay.sage : ClientClay.secondaryInk)
                }
            }
            Divider().opacity(0.45)
            ForEach(meal.foods) { food in
                HStack {
                    Text(food.name)
                    Spacer()
                    Text(food.quantity.map { "\($0.formatted()) \(food.unit)" } ?? food.unit)
                        .foregroundStyle(ClientClay.secondaryInk)
                }
                if food.id != meal.foods.last?.id { Divider().opacity(0.3) }
            }
        }
        .clayCard()
    }
}
