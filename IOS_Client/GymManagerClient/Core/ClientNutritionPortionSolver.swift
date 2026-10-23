import Foundation

struct ClientNutritionTotals: Equatable, Sendable {
    var calories = 0.0
    var protein = 0.0
    var carbs = 0.0
    var fat = 0.0
    var vector: [Double] { [calories, protein, carbs, fat] }
    static func + (a: Self, b: Self) -> Self {
        Self(calories: a.calories + b.calories, protein: a.protein + b.protein, carbs: a.carbs + b.carbs, fat: a.fat + b.fat)
    }
    static func food(_ item: ClientFoodCatalogItem, grams: Double) -> Self {
        Self(calories: item.caloriesPer100g * grams / 100,
             protein: (item.proteinPer100g ?? 0) * grams / 100,
             carbs: (item.carbsPer100g ?? 0) * grams / 100, fat: (item.fatPer100g ?? 0) * grams / 100)
    }
    static func meal(_ meal: ClientPersonalMeal) -> Self {
        Self(calories: meal.calories, protein: meal.protein, carbs: meal.carbs, fat: meal.fat)
    }
}

struct ClientNutritionSolvedPortion: Sendable {
    let item: ClientFoodCatalogItem
    let role: ClientNutritionFoodRole
    let bounds: ClientNutritionPortionBounds
    var grams: Double
}

struct ClientNutritionFitObjective: Sendable {
    let weights: [Double]
    let minimumScales: [Double]
    static let generation = Self(weights: [4, 1, 1, 1], minimumScales: [1, 1, 1, 1])
    static let replacement = Self(weights: [4, 3, 2, 2], minimumScales: [25, 5, 5, 3])
    var isValid: Bool {
        weights.count == 4 && minimumScales.count == 4 &&
            weights.allSatisfy { $0.isFinite && (0.1...100).contains($0) } &&
            minimumScales.allSatisfy { $0.isFinite && (0.1...1000).contains($0) }
    }
}

enum ClientNutritionPortionSolver {
    static func mealTarget(_ target: ClientNutritionTarget, share: Double, mealCount: Int) -> ClientNutritionTotals {
        // Equal daily protein share, energy/carb/fat follow inherited meal energy shares.
        ClientNutritionTotals(calories: target.calories * share, protein: target.protein / Double(mealCount),
                              carbs: target.carbs * share, fat: target.fat * share)
    }
    static func totals(_ portions: [ClientNutritionSolvedPortion]) -> ClientNutritionTotals {
        portions.reduce(ClientNutritionTotals()) { $0 + .food($1.item, grams: $1.grams) }
    }
    static func relative(_ actual: Double, _ target: Double, tolerance: Double) -> Bool {
        actual.isFinite && target.isFinite && target > 0 && abs(actual - target) / target <= tolerance + 0.0000001
    }
    static func score(_ actual: ClientNutritionTotals, _ target: ClientNutritionTotals,
                      objective: ClientNutritionFitObjective = .generation) -> Double {
        guard objective.isValid else { return .infinity }
        return zip(actual.vector, target.vector).enumerated().reduce(0) { value, pair in
            value + objective.weights[pair.offset] * pow((pair.element.0 - pair.element.1) /
                max(objective.minimumScales[pair.offset], pair.element.1), 2)
        }
    }

    /// Bounded coordinate descent on a convex quadratic, no dependency/randomness/network.
    /// Optimize continuous grams, quantize ONCE, then locally repair on that same discrete lattice.
    static func fit(_ input: [ClientNutritionSolvedPortion], target: ClientNutritionTotals,
                    objective: ClientNutritionFitObjective = .generation) -> [ClientNutritionSolvedPortion] {
        guard objective.isValid, target.vector.allSatisfy({ $0.isFinite && $0 >= 0 }),
              input.allSatisfy({ $0.bounds.isValid && $0.grams.isFinite }) else { return [] }
        var portions = input
        for _ in 0..<40 {
            var changed = false
            for index in portions.indices {
                let current = totals(portions).vector
                let derivative = ClientNutritionTotals.food(portions[index].item, grams: 1).vector
                var numerator = 0.0, denominator = 0.0
                for axis in 0..<4 {
                    let weight = objective.weights[axis] / pow(max(objective.minimumScales[axis], target.vector[axis]), 2)
                    numerator += weight * derivative[axis] * (current[axis] - target.vector[axis])
                    denominator += weight * derivative[axis] * derivative[axis]
                }
                guard denominator > 0 else { continue }
                let next = min(portions[index].bounds.maximumGrams,
                               max(portions[index].bounds.minimumGrams, portions[index].grams - numerator / denominator))
                changed = changed || abs(next - portions[index].grams) > 0.000001
                portions[index].grams = next
            }
            if !changed { break }
        }
        for index in portions.indices {
            let bounds = portions[index].bounds
            portions[index].grams = min(bounds.maximumGrams, max(bounds.minimumGrams,
                (portions[index].grams / bounds.stepGrams).rounded() * bounds.stepGrams))
        }
        for _ in 0..<160 {
            var best = portions
            var bestScore = score(totals(portions), target, objective: objective)
            for index in portions.indices {
                for direction in [-1.0, 1.0] {
                    var candidate = portions
                    candidate[index].grams += direction * candidate[index].bounds.stepGrams
                    guard candidate[index].bounds.contains(candidate[index].grams) else { continue }
                    let proposed = score(totals(candidate), target, objective: objective)
                    if proposed < bestScore - 0.00000001 { best = candidate; bestScore = proposed }
                }
            }
            guard zip(best, portions).contains(where: { abs($0.0.grams - $0.1.grams) > 0.000001 }) else { break }
            portions = best
        }
        return portions
    }

    /// Repair whole-day residuals without destroying per-meal fit; all changes remain quantized.
    static func refineDay(_ input: [[ClientNutritionSolvedPortion]], targets: [ClientNutritionTotals],
                          daily: ClientNutritionTarget) -> [[ClientNutritionSolvedPortion]] {
        let target = ClientNutritionTotals(calories: daily.calories, protein: daily.protein, carbs: daily.carbs, fat: daily.fat)
        func dayScore(_ values: [[ClientNutritionSolvedPortion]]) -> Double {
            let sum = values.reduce(ClientNutritionTotals()) { $0 + totals($1) }
            return 4 * score(sum, target) + zip(values, targets).reduce(0) { $0 + score(totals($1.0), $1.1) }
        }
        var values = input
        for _ in 0..<160 {
            var best = values
            var bestScore = dayScore(values)
            for meal in values.indices {
                for index in values[meal].indices {
                    for direction in [-1.0, 1.0] {
                        var candidate = values
                        candidate[meal][index].grams += direction * candidate[meal][index].bounds.stepGrams
                        guard candidate[meal][index].bounds.contains(candidate[meal][index].grams) else { continue }
                        let proposed = dayScore(candidate)
                        if proposed < bestScore - 0.00000001 { best = candidate; bestScore = proposed }
                    }
                }
            }
            guard bestScore < dayScore(values) - 0.00000001 else { break }
            values = best
        }
        return values
    }
}
