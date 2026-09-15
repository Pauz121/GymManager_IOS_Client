import SwiftUI

struct ClientNutritionView: View {
    let plan: ClientNutritionPlan?
    let identity: ClientIdentity
    @EnvironmentObject private var session: ClientSessionStore
    @State private var selectedWeekday: Int?

    private var currentWeekday: Int { ClientDateLogic.weekday(for: Date()) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let plan {
                    planHeader(plan)
                    weekSelector(plan)

                    if let notice = plan.detailNotice {
                        Label(notice, systemImage: "info.circle")
                            .font(.subheadline).foregroundStyle(ClientClay.secondaryInk).clayCard(padding: 14)
                    }

                    if let day = selectedDay(in: plan) {
                        currentDayHero(plan: plan, day: day)
                        ForEach(day.meals) { meal in
                            mealCard(meal, day: day)
                        }
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
        .onAppear { if let plan { selectPreferredDay(in: plan) } }
        .onChange(of: plan?.id) { _, _ in if let plan { selectPreferredDay(in: plan) } }
    }

    private func planHeader(_ plan: ClientNutritionPlan) -> some View {
        HStack(spacing: 13) {
            Image(systemName: "leaf.fill")
                .font(.title3).foregroundStyle(ClientClay.sage)
                .frame(width: 42, height: 42)
                .background(ClientClay.sage.opacity(0.13), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text("PIANO ATTIVO").font(.caption2.weight(.bold)).tracking(1).foregroundStyle(ClientClay.secondaryInk)
                Text(plan.title).font(.headline.weight(.bold)).foregroundStyle(ClientClay.ink).lineLimit(2)
                Text("Piano del Trainer · sola lettura").font(.caption).foregroundStyle(ClientClay.secondaryInk)
            }
            Spacer(minLength: 0)
        }
        .clayCard(padding: 14)
    }

    private func weekSelector(_ plan: ClientNutritionPlan) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Text("SETTIMANA").font(.caption.weight(.bold)).tracking(1).foregroundStyle(ClientClay.secondaryInk)
                Spacer()
                Text("\(plan.days.count) giorni").font(.caption).foregroundStyle(ClientClay.secondaryInk)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(plan.days) { day in
                        Button {
                            ClientHaptics.selection()
                            withAnimation(.snappy(duration: 0.22)) { selectedWeekday = day.weekday }
                        } label: {
                            dayPill(day)
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(selectedWeekday == day.weekday ? [.isSelected] : [])
                        .accessibilityHint(isCurrentDay(day) ? "Giornata corrente, pasti modificabili" : "Consulta i pasti in sola lettura")
                    }
                }
                .padding(.horizontal, 1).padding(.vertical, 5)
            }
        }
    }

    private func dayPill(_ day: ClientNutritionDay) -> some View {
        let isSelected = selectedWeekday == day.weekday
        let isToday = isCurrentDay(day)
        return VStack(spacing: 4) {
            Text(String(day.name.prefix(3)).uppercased()).font(.caption2.weight(.bold)).tracking(0.7)
            Text("\(day.meals.count)").font(.headline.monospacedDigit().weight(.bold))
            Text(isToday ? "OGGI" : "PASTI").font(.system(size: 9, weight: .bold))
        }
        .foregroundStyle(isSelected ? ClientClay.ink : ClientClay.secondaryInk)
        .frame(width: 72, minHeight: 72)
        .background(
            LinearGradient(
                colors: isSelected
                    ? [ClientClay.surfaceElevated, ClientClay.surfaceDeep]
                    : [ClientClay.surfaceDeep, ClientClay.surface],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(
                    isToday ? ClientClay.sage : isSelected ? ClientClay.accentSoft : ClientClay.border,
                    lineWidth: isToday && isSelected ? 3 : isToday || isSelected ? 2 : 1
                )
        }
        .shadow(color: isSelected ? (isToday ? ClientClay.sage : ClientClay.accent).opacity(0.18) : .clear, radius: 8, y: 4)
        .scaleEffect(isSelected ? 1.025 : 1)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(day.name), \(day.meals.count) pasti\(isToday ? ", oggi" : "")")
    }

    private func currentDayHero(plan: ClientNutritionPlan, day: ClientNutritionDay) -> some View {
        let current = isCurrentDay(day)
        let completed = completedMeals(in: day)
        let calories = completed.compactMap(\.caloriesKcal).reduce(0, +)
        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(day.name).font(.system(.title2, design: .rounded, weight: .heavy)).foregroundStyle(.white)
                    Text(current ? "Oggi · puoi spuntare i pasti" : "Consultazione · sola lettura")
                        .font(.caption.weight(.semibold)).foregroundStyle(current ? ClientClay.sage : .white.opacity(0.66))
                }
                Spacer()
                Image(systemName: current ? "checkmark.circle.fill" : "lock.fill")
                    .foregroundStyle(current ? ClientClay.sage : .white.opacity(0.65))
            }
            if let totalCalories = day.caloriesKcal {
                ViewThatFits {
                    HStack(spacing: 16) {
                        ClientCaloriePie(value: calories, total: totalCalories, valueText: "\(Int(calories.rounded()))", detail: "di \(Int(totalCalories.rounded())) kcal", size: 92)
                        progressCopy(completed: completed.count, total: day.meals.count, current: current)
                    }
                    VStack(alignment: .leading, spacing: 12) {
                        ClientCaloriePie(value: calories, total: totalCalories, valueText: "\(Int(calories.rounded()))", detail: "di \(Int(totalCalories.rounded())) kcal", size: 88)
                        progressCopy(completed: completed.count, total: day.meals.count, current: current)
                    }
                }
            } else {
                progressCopy(completed: completed.count, total: day.meals.count, current: current)
            }
        }
        .premiumCard(tint: current ? ClientClay.sage : ClientClay.accent)
    }

    private func progressCopy(completed: Int, total: Int, current: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(current ? "\(completed) / \(total) pasti completati" : "\(total) pasti previsti")
                .font(.headline).foregroundStyle(.white)
            ClientProgressSegmentBar(completed: completed, total: total, tint: ClientClay.sage)
            Text(current ? "Tocca il check accanto al pasto" : "Puoi consultare alimenti e quantità")
                .font(.caption).foregroundStyle(.white.opacity(0.66))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func mealCard(_ meal: ClientMeal, day: ClientNutritionDay) -> some View {
        let current = isCurrentDay(day)
        let completed = current && session.activity.isMealCompleted(meal.id)
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                if current {
                    Button {
                        withAnimation(.snappy(duration: 0.22)) { session.toggleMealCompletion(meal.id) }
                    } label: {
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
        .overlay { RoundedRectangle(cornerRadius: ClientClay.radius, style: .continuous).stroke(completed ? ClientClay.sage.opacity(0.38) : ClientClay.border) }
        .opacity(completed ? 0.90 : 1)
    }

    private func selectedDay(in plan: ClientNutritionPlan) -> ClientNutritionDay? {
        plan.days.first { $0.weekday == selectedWeekday }
            ?? plan.days.first { $0.weekday == currentWeekday }
            ?? plan.days.first
    }

    private func completedMeals(in day: ClientNutritionDay) -> [ClientMeal] {
        guard isCurrentDay(day) else { return [] }
        return day.meals.filter { session.activity.isMealCompleted($0.id) }
    }

    private func isCurrentDay(_ day: ClientNutritionDay) -> Bool { day.weekday == currentWeekday }

    private func selectPreferredDay(in plan: ClientNutritionPlan) {
        selectedWeekday = plan.days.first(where: { $0.weekday == currentWeekday })?.weekday ?? plan.days.first?.weekday
    }
}
