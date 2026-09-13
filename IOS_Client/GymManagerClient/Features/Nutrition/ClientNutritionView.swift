import SwiftUI

struct ClientNutritionView: View {
    let plan: ClientNutritionPlan?
    let identity: ClientIdentity

    private var currentWeekday: Int { ClientDateLogic.weekday(for: Date()) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                ClientPageTitle("Nutrizione", eyebrow: "Piano alimentare", subtitle: "Consulta tutti i giorni del piano. Solo la giornata corrente può essere spuntata.")
                if let plan {
                    ReadOnlyPlanBadge()
                    VStack(alignment: .leading, spacing: 6) {
                        Text(plan.title).font(.system(.title2, design: .rounded, weight: .bold))
                        Text("\(plan.days.count) giornate disponibili")
                            .font(.subheadline).foregroundStyle(ClientClay.secondaryInk)
                    }
                    .clayCard()

                    if let notice = plan.detailNotice {
                        Label(notice, systemImage: "info.circle").font(.subheadline).clayCard()
                    }

                    Text("Giorni del piano").font(.title3.weight(.bold))
                    ForEach(plan.days) { day in
                        NavigationLink {
                            ClientNutritionDayDetailView(planTitle: plan.title, day: day, isCurrentDay: day.weekday == currentWeekday)
                        } label: {
                            dayRow(day)
                        }
                        .buttonStyle(.plain)
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

    private func dayRow(_ day: ClientNutritionDay) -> some View {
        let isToday = day.weekday == currentWeekday
        return HStack(spacing: 14) {
            Image(systemName: isToday ? "sun.max.fill" : "calendar")
                .font(.title2).foregroundStyle(isToday ? ClientClay.accent : ClientClay.secondaryInk)
                .frame(width: 34)
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(day.name).font(.headline).foregroundStyle(ClientClay.ink)
                    if isToday { ClientBadge(text: "Oggi", tint: ClientClay.accent) }
                }
                Text("\(day.meals.count) pasti · \(day.caloriesKcal.map { "\(Int($0.rounded())) kcal" } ?? "calorie non disponibili")")
                    .font(.caption).foregroundStyle(ClientClay.secondaryInk)
            }
            Spacer()
            Image(systemName: "chevron.right").font(.caption.weight(.bold)).foregroundStyle(ClientClay.secondaryInk)
        }
        .clayCard(padding: 15)
        .accessibilityElement(children: .combine)
        .accessibilityHint(isToday ? "Apre la giornata corrente, modificabile" : "Apre la giornata in sola lettura")
    }
}

private struct ClientNutritionDayDetailView: View {
    let planTitle: String
    let day: ClientNutritionDay
    let isCurrentDay: Bool
    @EnvironmentObject private var session: ClientSessionStore

    private var completedMeals: [ClientMeal] {
        guard isCurrentDay else { return [] }
        return day.meals.filter { session.activity.isMealCompleted($0.id) }
    }

    private var completedCalories: Double {
        completedMeals.compactMap(\.caloriesKcal).reduce(0, +)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(planTitle).font(.caption.weight(.bold)).foregroundStyle(ClientClay.accent)
                    Text(day.name).font(.system(.largeTitle, design: .rounded, weight: .bold))
                    ClientBadge(
                        text: isCurrentDay ? "Giornata corrente · puoi spuntare i pasti" : "Consultazione · sola lettura",
                        tint: isCurrentDay ? ClientClay.sage : ClientClay.secondaryInk,
                        symbol: isCurrentDay ? "checkmark.circle" : "lock.fill"
                    )
                }

                HStack(spacing: 17) {
                    ClientCaloriePie(
                        value: day.caloriesKcal == nil ? 0 : completedCalories,
                        total: day.caloriesKcal ?? 1,
                        valueText: day.caloriesKcal.map { "\(Int(completedCalories.rounded()))" } ?? "--",
                        detail: day.caloriesKcal.map { "di \(Int($0.rounded())) kcal" } ?? "kcal non disponibili"
                    )
                    VStack(alignment: .leading, spacing: 7) {
                        Text("Calorie della giornata").font(.headline)
                        Text(day.caloriesKcal.map { "Totale \(Int($0.rounded())) kcal" } ?? "Il piano non contiene calorie complete.")
                            .font(.subheadline).foregroundStyle(ClientClay.secondaryInk)
                        if isCurrentDay {
                            Text("\(completedMeals.count) / \(day.meals.count) pasti completati")
                                .font(.caption.weight(.semibold)).foregroundStyle(ClientClay.sage)
                        }
                    }
                }
                .clayCard()

                ForEach(day.meals) { meal in mealCard(meal) }
            }
            .padding(20)
        }
        .clientPage()
        .navigationTitle(day.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func mealCard(_ meal: ClientMeal) -> some View {
        let completed = isCurrentDay && session.activity.isMealCompleted(meal.id)
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                if isCurrentDay {
                    Button { session.toggleMealCompletion(meal.id) } label: {
                        Image(systemName: completed ? "checkmark.circle.fill" : "circle")
                            .font(.title2).foregroundStyle(completed ? ClientClay.sage : ClientClay.secondaryInk)
                            .frame(width: 48, height: 48).contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(completed ? "Segna \(meal.name) come da completare" : "Segna \(meal.name) come completato")
                } else {
                    Image(systemName: "lock.fill").foregroundStyle(ClientClay.secondaryInk).frame(width: 48, height: 48)
                        .accessibilityLabel("Pasto in sola lettura")
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(meal.name).font(.title3.weight(.semibold)).foregroundStyle(ClientClay.ink)
                    Text(meal.caloriesKcal.map { "\(Int($0.rounded())) kcal" } ?? "Calorie non disponibili")
                        .font(.caption.weight(.semibold)).foregroundStyle(ClientClay.secondaryInk)
                }
                Spacer()
            }
            Divider().opacity(0.45)
            ForEach(meal.foods) { food in
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(food.name)
                        Text(food.quantity.map { "\($0.formatted()) \(food.unit)" } ?? food.unit)
                            .font(.caption).foregroundStyle(ClientClay.secondaryInk)
                    }
                    Spacer()
                    Text(food.caloriesKcal.map { "\(Int($0.rounded())) kcal" } ?? "-- kcal")
                        .font(.caption).foregroundStyle(ClientClay.secondaryInk)
                }
                if food.id != meal.foods.last?.id { Divider().opacity(0.3) }
            }
        }
        .clayCard()
    }
}
