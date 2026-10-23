import Foundation

/// Typed editing contract, not a second Nutrition plan. Instance IDs preserve identity across reorder/rename.
struct ClientNutritionEditingLayout: Codable, Equatable, Sendable {
    struct FoodRole: Codable, Equatable, Sendable { var foodID: UUID; var role: ClientNutritionFoodRole }
    struct Meal: Codable, Equatable, Sendable {
        var mealID: UUID
        var occasion: ClientNutritionMealOccasion
        var energyShare: Double
        var proteinShare: Double
        var foodRoles: [FoodRole]
    }
    struct Day: Codable, Equatable, Sendable { var dayID: UUID; var meals: [Meal] }
    var days: [Day]

    static func generated(_ plan: ClientPersonalNutritionPlan) -> Self? {
        guard let answers = plan.creationAnswers else { return nil }
        let shares = ClientNutritionCoachRules.mealShares(answers.mealCount)
        guard !shares.isEmpty, plan.days.allSatisfy({ $0.meals.count == shares.count }) else { return nil }
        var result: [Day] = []
        for day in plan.days {
            var layouts: [Meal] = []
            for (index, meal) in day.meals.enumerated() {
                let roles = ClientNutritionGenerator.roles(index: index, count: answers.mealCount)
                guard roles.count == meal.foods.count else { return nil }
                layouts.append(Meal(mealID: meal.id, occasion: ClientNutritionGenerator.occasion(index: index, count: answers.mealCount),
                    energyShare: shares[index], proteinShare: 1 / Double(answers.mealCount),
                    foodRoles: zip(meal.foods, roles).map { FoodRole(foodID: $0.0.id, role: $0.1) }))
            }
            result.append(Day(dayID: day.id, meals: layouts))
        }
        return Self(days: result)
    }
    func meal(dayID: UUID, mealID: UUID) -> Meal? {
        days.first { $0.dayID == dayID }?.meals.first { $0.mealID == mealID }
    }
    func valid(for plan: ClientPersonalNutritionPlan) -> Bool {
        guard days.count == plan.days.count, Set(days.map(\.dayID)) == Set(plan.days.map(\.id)) else { return false }
        for day in plan.days {
            guard let specs = days.first(where: { $0.dayID == day.id })?.meals,
                  (3...6).contains(day.meals.count), specs.count == day.meals.count,
                  Set(specs.map(\.mealID)) == Set(day.meals.map(\.id)),
                  specs.allSatisfy({ $0.energyShare.isFinite && (0.05...0.50).contains($0.energyShare) &&
                      $0.proteinShare.isFinite && (0.10...0.50).contains($0.proteinShare) }),
                  abs(specs.reduce(0) { $0 + $1.energyShare } - 1) < 0.000001,
                  abs(specs.reduce(0) { $0 + $1.proteinShare } - 1) < 0.000001 else { return false }
            for meal in day.meals {
                guard let spec = specs.first(where: { $0.mealID == meal.id }),
                      (1...(spec.occasion == .snack ? 3 : 5)).contains(meal.foods.count),
                      spec.foodRoles.count == meal.foods.count,
                      Set(spec.foodRoles.map(\.foodID)) == Set(meal.foods.map(\.id)) else { return false }
            }
        }
        return true
    }
}
