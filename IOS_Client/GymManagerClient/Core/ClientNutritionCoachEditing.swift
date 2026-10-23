import Foundation

/// Draft operations for the existing editor. Invalid intermediate edits stay local and recoverable.
enum ClientNutritionCoachEditing {
    static func review(original: ClientPersonalNutritionPlan, draft: ClientPersonalNutritionPlan,
                       layout: ClientNutritionEditingLayout?, mode: ClientConnectionMode?, catalog: [ClientFoodCatalogItem]) -> ClientEditedNutritionPlanValidator.Result {
        let context = ClientNutritionCoachContext(mode: mode, profile: original.creationAnswers?.coachProfile)
        let originalIssues = ClientNutritionPlanValidator.inspect(original, context: context, catalog: catalog)
        guard originalIssues.isEmpty else { return .init(plan: draft, issues: originalIssues) }
        return ClientEditedNutritionPlanValidator().prepare(original: original, edited: draft, layout: layout, context: context, catalog: catalog)
    }
    static func availableFoods(plan: ClientPersonalNutritionPlan, layout: ClientNutritionEditingLayout?, dayID: UUID, mealID: UUID,
                               role: ClientNutritionFoodRole, catalog: [ClientFoodCatalogItem]) -> [ClientFoodCatalogItem] {
        guard let profile = plan.creationAnswers?.coachProfile, let answers = plan.creationAnswers,
              let spec = layout?.meal(dayID: dayID, mealID: mealID),
              let meal = plan.days.first(where: { $0.id == dayID })?.meals.first(where: { $0.id == mealID }) else { return [] }
        let used = Set(meal.foods.compactMap(\.catalogFoodID))
        return ClientNutritionFoodPolicy.admit(catalog, profile: profile, excluded: Set(answers.excludedFoodIDs))
            .filter { !used.contains($0.id) && $0.nutritionEvidence?.allowedMeals.contains(spec.occasion) == true && ClientNutritionGenerator.matches($0, role: role) }
            .sorted { $0.id.uuidString < $1.id.uuidString }
    }
    static func add(_ item: ClientFoodCatalogItem, grams: Double, role: ClientNutritionFoodRole,
                    day: Int, meal: Int, plan: inout ClientPersonalNutritionPlan, layout: inout ClientNutritionEditingLayout) throws {
        guard plan.days.indices.contains(day), plan.days[day].meals.indices.contains(meal),
              let d = layout.days.firstIndex(where: { $0.dayID == plan.days[day].id }),
              let m = layout.days[d].meals.firstIndex(where: { $0.mealID == plan.days[day].meals[meal].id }),
              let evidence = item.nutritionEvidence, evidence.portion.contains(grams),
              availableFoods(plan: plan, layout: layout, dayID: plan.days[day].id, mealID: plan.days[day].meals[meal].id,
                role: role, catalog: [item]).contains(where: { $0.id == item.id }) else { throw ClientSmartPlanEditError.invalidEdit }
        let food = ClientPersonalFood(id: UUID(), catalogFoodID: item.id, name: item.name, quantityGrams: grams,
            caloriesPer100g: item.caloriesPer100g, proteinPer100g: item.proteinPer100g, carbsPer100g: item.carbsPer100g,
            fatPer100g: item.fatPer100g, gramsPerPiece: item.gramsPerPiece, nutritionEvidence: evidence)
        plan.days[day].meals[meal].foods.append(food)
        layout.days[d].meals[m].foodRoles.append(.init(foodID: food.id, role: role))
    }
    static func remove(foodID: UUID, day: Int, meal: Int, plan: inout ClientPersonalNutritionPlan, layout: inout ClientNutritionEditingLayout) {
        plan.days[day].meals[meal].foods.removeAll { $0.id == foodID }
        for d in layout.days.indices { for m in layout.days[d].meals.indices { layout.days[d].meals[m].foodRoles.removeAll { $0.foodID == foodID } } }
    }
    static func move(foodID: UUID, day: Int, from: Int, to: Int, plan: inout ClientPersonalNutritionPlan, layout: inout ClientNutritionEditingLayout) throws {
        guard plan.days.indices.contains(day), plan.days[day].meals.indices.contains(from), plan.days[day].meals.indices.contains(to), from != to,
              let index = plan.days[day].meals[from].foods.firstIndex(where: { $0.id == foodID }),
              let d = layout.days.firstIndex(where: { $0.dayID == plan.days[day].id }),
              let source = layout.days[d].meals.firstIndex(where: { $0.mealID == plan.days[day].meals[from].id }),
              let destination = layout.days[d].meals.firstIndex(where: { $0.mealID == plan.days[day].meals[to].id }),
              let role = layout.days[d].meals[source].foodRoles.first(where: { $0.foodID == foodID }) else { throw ClientSmartPlanEditError.missingTarget }
        let food = plan.days[day].meals[from].foods.remove(at: index)
        plan.days[day].meals[to].foods.append(food)
        layout.days[d].meals[source].foodRoles.removeAll { $0.foodID == foodID }
        layout.days[d].meals[destination].foodRoles.append(role)
        // No hidden quantity/target change. Validator reports incompatible occasion or totals.
    }
    static func copyMeal(day: Int, meal: Int, plan: inout ClientPersonalNutritionPlan, layout: inout ClientNutritionEditingLayout) throws {
        let original = plan.days[day].meals[meal]
        guard let d = layout.days.firstIndex(where: { $0.dayID == plan.days[day].id }),
              var spec = layout.days[d].meals.first(where: { $0.mealID == original.id }) else { throw ClientSmartPlanEditError.missingTarget }
        let copy = ClientNutritionDraft.copy(original)
        spec.mealID = copy.id
        let roles = spec.foodRoles
        spec.foodRoles = zip(original.foods, copy.foods).compactMap { before, after in
            roles.first(where: { $0.foodID == before.id }).map { .init(foodID: after.id, role: $0.role) }
        }
        plan.days[day].meals.insert(copy, at: meal + 1); layout.days[d].meals.append(spec)
        // Distribution remains explicit and may be invalid until the user adjusts it.
    }
    static func copyDay(from: Int, to: Int, plan: inout ClientPersonalNutritionPlan, layout: inout ClientNutritionEditingLayout) throws {
        guard from != to, plan.days.indices.contains(from), plan.days.indices.contains(to),
              let originalSpec = layout.days.first(where: { $0.dayID == plan.days[from].id }),
              let target = layout.days.firstIndex(where: { $0.dayID == plan.days[to].id }) else { throw ClientSmartPlanEditError.missingTarget }
        let sourceMeals = plan.days[from].meals
        var copied = plan.days[to]; ClientNutritionDraft.copyDay(plan.days[from], into: &copied)
        var specs: [ClientNutritionEditingLayout.Meal] = []
        for (before, after) in zip(sourceMeals, copied.meals) {
            guard var spec = originalSpec.meals.first(where: { $0.mealID == before.id }) else { throw ClientSmartPlanEditError.missingTarget }
            let roles = spec.foodRoles
            spec.mealID = after.id
            spec.foodRoles = zip(before.foods, after.foods).compactMap { old, new in roles.first(where: { $0.foodID == old.id }).map { .init(foodID: new.id, role: $0.role) } }
            specs.append(spec)
        }
        plan.days[to] = copied; layout.days[target].meals = specs
    }
}

extension ClientNutritionFoodRole {
    var title: String {
        switch self { case .protein: "Fonte proteica"; case .carbohydrate: "Fonte di carboidrati"; case .fat: "Fonte di grassi"; case .vegetable: "Verdura"; case .fruit: "Frutta"; case .dairyAlternative: "Latticini e alternative"; case .mixed: "Alimento misto" }
    }
}
