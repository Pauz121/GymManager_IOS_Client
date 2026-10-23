import SwiftUI

struct ClientNutritionView: View {
    let snapshot: ClientSnapshot
    let identity: ClientIdentity
    @EnvironmentObject private var session: ClientSessionStore
    @State private var selectedWeekday: Int?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var currentWeekday: Int { ClientDateLogic.weekday(for: Date()) }
    private var plan: ClientNutritionPlan? { snapshot.nutrition }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let message = snapshot.contentState(for: .nutrition).failure {
                    ClientContentFailureCard(title: "Nutrizione", message: message, isRefreshing: session.isRefreshing) {
                        Task { await session.refresh() }
                    }
                }
                if identity.mode == .standalone {
                    ClientPersonalNutritionLibraryView(allowsEditing: true)
                } else if let plan {
                    planHeader(plan)
                    weekSelector(plan)

                    if let notice = plan.detailNotice {
                        Label(notice, systemImage: "info.circle")
                            .font(.subheadline).foregroundStyle(ClientClay.secondaryInk)
                    }

                    if let day = selectedDay(in: plan) {
                        currentDayHero(plan: plan, day: day)
                        ForEach(day.meals) { meal in
                            mealCard(meal, day: day, plan: plan)
                        }
                    }
                    ClientPersonalNutritionLibraryView(allowsEditing: false)
                } else if snapshot.contentState(for: .nutrition).failure != nil {
                    // The section error above remains visible, even when a cached
                    // plan is available; do not turn failure into an empty plan.
                    ClientPersonalNutritionLibraryView(allowsEditing: false)
                } else {
                    ClientEmptyState(
                        symbol: "leaf",
                        title: "Nessun piano Trainer",
                        message: "Il professionista non ha ancora pubblicato un piano attivo."
                    )
                    ClientPersonalNutritionLibraryView(allowsEditing: false)
                }
            }
            .padding(.horizontal, ClientClay.pagePadding).padding(.vertical, 18)
        }
        .clientPage()
        .refreshable { await session.refresh() }
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
                Text(plan.isEffective() ? "PIANO ATTIVO" : "PIANO PUBBLICATO").font(.caption2.weight(.bold)).tracking(1).foregroundStyle(ClientClay.secondaryInk)
                Text(plan.title).font(.headline.weight(.bold)).foregroundStyle(ClientClay.ink).lineLimit(2)
                Text(plan.isEffective() ? "Piano del Trainer · sola lettura" : "Disponibile dal \(plan.startsOn ?? "periodo indicato dal Trainer")")
                    .font(.caption).foregroundStyle(ClientClay.secondaryInk)
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
                            withAnimation(reduceMotion ? nil : .snappy(duration: 0.22)) { selectedWeekday = day.weekday }
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
            Text(isToday ? "OGGI" : "PASTI").font(.caption2.weight(.bold))
        }
        .foregroundStyle(isSelected ? ClientClay.ink : ClientClay.secondaryInk)
        .padding(.horizontal, 12).padding(.vertical, 10)
        .frame(minWidth: 72, minHeight: 72)
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
        let current = isCurrentDay(day) && plan.isEffective()
        let completed = completedMeals(in: day)
        let calories = completed.allSatisfy { $0.caloriesKcal != nil } ? completed.compactMap(\.caloriesKcal).reduce(0, +) : nil
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(day.name).font(.title3.weight(.bold)).foregroundStyle(ClientClay.ink)
                Spacer()
                Text(day.caloriesKcal.map { "\(Int($0.rounded())) kcal" } ?? "Kcal non disponibili")
                    .font(.subheadline.monospacedDigit()).foregroundStyle(ClientClay.secondaryInk)
            }
            Text(current ? "\(completed.count) / \(day.meals.count) pasti completati" : "Consultazione · sola lettura")
                .font(.subheadline).foregroundStyle(ClientClay.secondaryInk)
            if current {
                Text(calories.map { "\(Int($0.rounded())) kcal completate" } ?? "Calorie dei pasti completati non disponibili")
                    .font(.caption).foregroundStyle(ClientClay.secondaryInk)
            }
            if current { ClientProgressSegmentBar(completed: completed.count, total: day.meals.count, tint: ClientClay.sage) }
            Text("P · C · G: non forniti nel piano del Trainer")
                .font(.caption).foregroundStyle(ClientClay.secondaryInk)
        }
        .padding(.vertical, 8)
    }

    private func mealCard(_ meal: ClientMeal, day: ClientNutritionDay, plan: ClientNutritionPlan) -> some View {
        let current = isCurrentDay(day) && plan.isEffective()
        let completed = current && session.activity.isMealCompleted(meal.id)
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                if current {
                    Button {
                        withAnimation(reduceMotion ? nil : .snappy(duration: 0.22)) { session.toggleMealCompletion(meal.id) }
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
        .padding(.vertical, 12)
        .overlay(alignment: .bottom) { Divider() }
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
