import SwiftUI

struct ClientNutritionView: View {
    let plan: ClientNutritionPlan?
    let identity: ClientIdentity
    @EnvironmentObject private var session: ClientSessionStore

    private var currentWeekday: Int { ClientDateLogic.weekday(for: Date()) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                ClientPageTitle("Nutrizione", eyebrow: "Piano alimentare", subtitle: "Consulta tutti i giorni del piano. Solo la giornata corrente può essere spuntata.")
                if let plan {
                    ReadOnlyPlanBadge()
                    if let currentDay = plan.days.first(where: { $0.weekday == currentWeekday }) {
                        NavigationLink {
                            ClientNutritionDayDetailView(planTitle: plan.title, day: currentDay, isCurrentDay: true)
                        } label: {
                            currentDayHero(plan: plan, day: currentDay)
                        }
                        .buttonStyle(.plain)
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("PIANO ATTIVO").font(.caption.weight(.bold)).tracking(1.2).foregroundStyle(.white.opacity(0.62))
                            Text(plan.title).font(.system(.title2, design: .rounded, weight: .heavy)).foregroundStyle(.white)
                            Text("Oggi non è prevista una giornata specifica.").font(.subheadline).foregroundStyle(.white.opacity(0.68))
                        }
                        .premiumCard(tint: ClientClay.sage)
                    }

                    if let notice = plan.detailNotice {
                        Label(notice, systemImage: "info.circle").font(.subheadline).clayCard()
                    }

                    ClientSectionHeader(title: "Giorni del piano", detail: "\(plan.days.count) disponibili", symbol: "calendar")
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(plan.days) { day in
                                NavigationLink {
                                    ClientNutritionDayDetailView(planTitle: plan.title, day: day, isCurrentDay: day.weekday == currentWeekday)
                                } label: {
                                    dayPill(day)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                } else {
                    ClientEmptyState(
                        symbol: "leaf",
                        title: "Nessun piano nutrizionale",
                        message: identity.mode == .standalone ? "I piani personali arriveranno nella prossima fase; puoi già usare la tua Agenda." : "Il professionista non ha ancora pubblicato un piano attivo."
                    )
                }
            }
            .padding(.horizontal, ClientClay.pagePadding).padding(.vertical, 18)
        }
        .clientPage()
        .navigationTitle("Nutrizione")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func currentDayHero(plan: ClientNutritionPlan, day: ClientNutritionDay) -> some View {
        let completedMeals = day.meals.filter { session.activity.isMealCompleted($0.id) }
        let completedCalories = completedMeals.compactMap(\.caloriesKcal).reduce(0, +)

        return VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(plan.title.uppercased()).font(.caption.weight(.bold)).tracking(1.1).foregroundStyle(.white.opacity(0.62))
                    Text(day.name).font(.system(.largeTitle, design: .rounded, weight: .heavy)).foregroundStyle(.white)
                    Text("OGGI · \(completedMeals.count) DI \(day.meals.count) PASTI")
                        .font(.caption.weight(.bold)).tracking(0.8).foregroundStyle(ClientClay.sage)
                }
                Spacer()
                Image(systemName: "leaf.fill").font(.title2).foregroundStyle(ClientClay.sage)
                    .frame(width: 48, height: 48).background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
            }
            if let calories = day.caloriesKcal {
                ViewThatFits {
                    HStack(spacing: 18) {
                        ClientCaloriePie(value: completedCalories, total: calories, valueText: "\(Int(completedCalories.rounded()))", detail: "di \(Int(calories.rounded())) kcal", size: 104)
                        nutritionProgressCopy(completed: completedMeals.count, total: day.meals.count)
                    }
                    VStack(alignment: .leading, spacing: 12) {
                        ClientCaloriePie(value: completedCalories, total: calories, valueText: "\(Int(completedCalories.rounded()))", detail: "di \(Int(calories.rounded())) kcal", size: 96)
                        nutritionProgressCopy(completed: completedMeals.count, total: day.meals.count)
                    }
                }
            } else {
                nutritionProgressCopy(completed: completedMeals.count, total: day.meals.count)
            }
            Label("Apri la giornata", systemImage: "arrow.up.right")
                .font(.subheadline.weight(.bold)).foregroundStyle(ClientClay.accentSoft)
        }
        .premiumCard(tint: ClientClay.sage)
        .accessibilityHint("Apre i pasti della giornata corrente")
    }

    private func nutritionProgressCopy(completed: Int, total: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(completed == total && total > 0 ? "Giornata completata" : "\(max(0, total - completed)) pasti da completare")
                .font(.headline).foregroundStyle(.white)
            ClientProgressSegmentBar(completed: completed, total: total, tint: ClientClay.sage)
            Text("\(completed) / \(total) completati").font(.caption.weight(.semibold)).foregroundStyle(.white.opacity(0.66))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func dayPill(_ day: ClientNutritionDay) -> some View {
        let isToday = day.weekday == currentWeekday
        return VStack(spacing: 6) {
            Text(String(day.name.prefix(3)).uppercased()).font(.caption.weight(.bold)).tracking(0.8)
            Image(systemName: isToday ? "sun.max.fill" : "calendar").font(.title3)
            Text("\(day.meals.count) pasti").font(.caption2.weight(.semibold))
        }
        .foregroundStyle(isToday ? .white : ClientClay.secondaryInk)
        .frame(width: 92).frame(minHeight: 86)
        .background(isToday ? ClientClay.accent : ClientClay.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(isToday ? ClientClay.accentSoft.opacity(0.46) : ClientClay.border) }
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
                dayHero

                ForEach(day.meals) { meal in mealCard(meal) }
            }
            .padding(.horizontal, ClientClay.pagePadding).padding(.vertical, 18)
        }
        .clientPage()
        .navigationTitle(day.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var dayHero: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(planTitle.uppercased()).font(.caption.weight(.bold)).tracking(1.1).foregroundStyle(.white.opacity(0.62))
                    Text(day.name).font(.system(.largeTitle, design: .rounded, weight: .heavy)).foregroundStyle(.white)
                    ClientBadge(
                        text: isCurrentDay ? "Oggi · puoi spuntare i pasti" : "Consultazione · sola lettura",
                        tint: isCurrentDay ? ClientClay.sage : ClientClay.inkSoft,
                        symbol: isCurrentDay ? "checkmark.circle" : "lock.fill"
                    )
                }
                Spacer()
                Image(systemName: isCurrentDay ? "leaf.fill" : "eye.fill").font(.title2).foregroundStyle(isCurrentDay ? ClientClay.sage : ClientClay.accentSoft)
            }
            if let calories = day.caloriesKcal {
                ViewThatFits {
                    HStack(spacing: 18) {
                        ClientCaloriePie(value: completedCalories, total: calories, valueText: "\(Int(completedCalories.rounded()))", detail: "di \(Int(calories.rounded())) kcal")
                        dayProgressCopy
                    }
                    VStack(alignment: .leading, spacing: 12) {
                        ClientCaloriePie(value: completedCalories, total: calories, valueText: "\(Int(completedCalories.rounded()))", detail: "di \(Int(calories.rounded())) kcal", size: 96)
                        dayProgressCopy
                    }
                }
            } else {
                dayProgressCopy
            }
        }
        .premiumCard(tint: isCurrentDay ? ClientClay.sage : ClientClay.accent)
    }

    private var dayProgressCopy: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(day.caloriesKcal.map { "Totale \(Int($0.rounded())) kcal" } ?? "Calorie non disponibili")
                .font(.headline).foregroundStyle(.white)
            ClientProgressSegmentBar(completed: completedMeals.count, total: day.meals.count, tint: ClientClay.sage)
            Text(isCurrentDay ? "\(completedMeals.count) / \(day.meals.count) pasti completati" : "\(day.meals.count) pasti in sola lettura")
                .font(.caption.weight(.semibold)).foregroundStyle(.white.opacity(0.68))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
                    Text(meal.caloriesKcal.map { "\(Int($0.rounded())) kcal" } ?? "\(meal.foods.count) alimenti")
                        .font(.caption.weight(.semibold)).foregroundStyle(ClientClay.secondaryInk)
                }
                Spacer()
            }
            Divider().overlay(ClientClay.border)
            ForEach(meal.foods) { food in
                HStack(alignment: .firstTextBaseline) {
                    Text(food.name).foregroundStyle(ClientClay.ink)
                    Spacer(minLength: 12)
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(food.quantity.map { "\($0.formatted()) \(food.unit)" } ?? food.unit)
                            .font(.subheadline.weight(.semibold)).foregroundStyle(ClientClay.inkSoft)
                        if let calories = food.caloriesKcal {
                            Text("\(Int(calories.rounded())) kcal").font(.caption).foregroundStyle(ClientClay.secondaryInk)
                        }
                    }
                }
                if food.id != meal.foods.last?.id { Divider().overlay(ClientClay.border) }
            }
        }
        .clayCard()
        .overlay {
            RoundedRectangle(cornerRadius: ClientClay.radius, style: .continuous)
                .stroke(completed ? ClientClay.sage.opacity(0.38) : ClientClay.border, lineWidth: 1)
        }
        .opacity(completed ? 0.90 : 1)
    }
}
