import Foundation

enum ClientPersonalNutritionSource: String, Codable, Sendable { case manual, guided }
enum ClientNutritionActivity: String, Codable, CaseIterable, Hashable, Sendable {
    case sedentary, light, active, veryActive
    var coefficient: Double {
        switch self { case .sedentary: 1.2; case .light: 1.375; case .active: 1.55; case .veryActive: 1.725 }
    }
    var title: String {
        switch self { case .sedentary: "Sedentario"; case .light: "Leggermente attivo"; case .active: "Attivo"; case .veryActive: "Molto attivo" }
    }
}

struct ClientNutritionCreationAnswers: Codable, Equatable, Sendable {
    var coachProfile: ClientNutritionCoachProfile? = nil
    var age: Int? = nil
    var biologicalSex: ClientBiologicalSex? = nil
    var heightCm: Double? = nil
    var weightKg: Double? = nil
    var activity: ClientNutritionActivity = .light
    var phase: ClientNutritionPhase = .maintenance
    var mealCount = 4
    var dayCount = 7
    var vegetarian = false
    var excludedFoodIDs: [UUID] = []
    var hasAllergiesOrMedicalNeeds = false
    var healthyAdultConfirmed = false
}

struct ClientNutritionTarget: Codable, Equatable, Sendable {
    let restingKcal: Double
    let estimatedKcal: Double
    let calories: Double
    let protein: Double
    let carbs: Double
    let fat: Double
}

enum ClientNutritionCatalog {
    static func normalize(
        id: UUID, name: String, servingAmount: Double, servingUnit: String,
        calories: Double?, protein: Double?, carbs: Double?, fat: Double?,
        category: String?, provider: String?, gramsPerPiece: Double?,
        nutritionEvidence: ClientNutritionFoodEvidence? = nil
    ) -> ClientFoodCatalogItem? {
        guard servingAmount.isFinite, servingAmount > 0, let calories, calories.isFinite, calories >= 0 else { return nil }
        let unit = servingUnit.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let pieceWeight: Double?
        let referenceGrams: Double
        switch unit {
        case "g", "gr", "grams", "grammi": referenceGrams = servingAmount; pieceWeight = nil
        case "pz", "piece", "pieces", "pezzi":
            guard let gramsPerPiece, gramsPerPiece.isFinite, gramsPerPiece > 0 else { return nil }
            referenceGrams = servingAmount * gramsPerPiece; pieceWeight = gramsPerPiece
        default: return nil // Do not assume ml, pieces or unknown portions weigh one gram.
        }
        guard referenceGrams.isFinite, referenceGrams > 0 else { return nil }
        let factor = 100 / referenceGrams
        let normalizedCalories = calories * factor
        guard normalizedCalories.isFinite, normalizedCalories <= 1000 else { return nil }
        func validMacro(_ value: Double?) -> Double? {
            value.flatMap { $0.isFinite && $0 >= 0 && ($0 * factor).isFinite ? $0 * factor : nil }
        }
        return ClientFoodCatalogItem(
            id: id, name: name, caloriesPer100g: normalizedCalories,
            proteinPer100g: validMacro(protein), carbsPer100g: validMacro(carbs), fatPer100g: validMacro(fat),
            category: category, provider: provider, gramsPerPiece: pieceWeight, nutritionEvidence: nutritionEvidence
        )
    }

    static func food(_ item: ClientFoodCatalogItem, quantity: Double) -> ClientPersonalFood {
        let grams = item.gramsPerPiece.map { max(1, quantity.rounded()) * $0 } ?? max(1, quantity)
        return ClientPersonalFood(
            id: UUID(), catalogFoodID: item.id, name: item.name, quantityGrams: grams,
            caloriesPer100g: item.caloriesPer100g, proteinPer100g: item.proteinPer100g,
            carbsPer100g: item.carbsPer100g, fatPer100g: item.fatPer100g, gramsPerPiece: item.gramsPerPiece
        )
    }
}

enum ClientNutritionDraft {
    static let weekdays = ["Lunedì", "Martedì", "Mercoledì", "Giovedì", "Venerdì", "Sabato", "Domenica"]
    static func mealNames(count: Int) -> [String] {
        switch count {
        case 3: ["Colazione", "Pranzo", "Cena"]
        case 4: ["Colazione", "Pranzo", "Merenda", "Cena"]
        case 5: ["Colazione", "Spuntino", "Pranzo", "Merenda", "Cena"]
        default: ["Colazione", "Spuntino", "Pranzo", "Merenda", "Cena", "Spuntino serale"]
        }
    }

    static func newPlan(answers: ClientNutritionCreationAnswers, now: Date = Date()) -> ClientPersonalNutritionPlan {
        let weekdays = answers.dayCount == 1 ? [ClientDateLogic.weekday(for: now)] : Array(1...7)
        return ClientPersonalNutritionPlan(
            id: UUID(), title: "La mia alimentazione", status: .active,
            days: weekdays.map { weekday in
                ClientPersonalNutritionDay(id: UUID(), weekday: weekday, name: Self.weekdays[weekday - 1], meals:
                    mealNames(count: answers.mealCount).map { ClientPersonalMeal(id: UUID(), name: $0, foods: []) })
            }, createdAt: now, updatedAt: now, source: .manual, creationAnswers: answers
        )
    }

    static func copy(_ meal: ClientPersonalMeal) -> ClientPersonalMeal {
        var copy = meal; copy.id = UUID()
        copy.foods = meal.foods.map { var item = $0; item.id = UUID(); return item }
        return copy
    }

    static func copyDay(_ source: ClientPersonalNutritionDay, into destination: inout ClientPersonalNutritionDay) {
        // Preserve the destination day/weekday; only its meals are replaced after UI confirmation.
        destination.meals = source.meals.map(copy)
    }

    static func resize(_ plan: inout ClientPersonalNutritionPlan, answers: ClientNutritionCreationAnswers, selectedDayID: UUID?) {
        if answers.dayCount == 1 {
            if let day = plan.days.first(where: { $0.id == selectedDayID }) ?? plan.days.first { plan.days = [day] }
        } else {
            let existing = plan.days
            plan.days = (1...7).map { weekday in
                existing.first(where: { $0.weekday == weekday }) ?? ClientPersonalNutritionDay(
                    id: UUID(), weekday: weekday, name: weekdays[weekday - 1], meals: []
                )
            }
        }
        let names = mealNames(count: answers.mealCount)
        for index in plan.days.indices {
            if plan.days[index].meals.count > names.count { plan.days[index].meals.removeLast(plan.days[index].meals.count - names.count) }
            while plan.days[index].meals.count < names.count {
                plan.days[index].meals.append(ClientPersonalMeal(id: UUID(), name: names[plan.days[index].meals.count], foods: []))
            }
        }
        plan.creationAnswers = answers
    }

    static func validationMessage(_ plan: ClientPersonalNutritionPlan) -> String? {
        guard plan.title.trimmingCharacters(in: .whitespacesAndNewlines).count >= 2 else { return "Dai un nome al piano." }
        guard !plan.days.isEmpty else { return "Aggiungi almeno una giornata." }
        for day in plan.days {
            guard !day.meals.isEmpty else { return "Aggiungi i pasti a \(day.name)." }
            for meal in day.meals {
                guard !meal.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, !meal.foods.isEmpty else {
                    return "Completa \(meal.name.isEmpty ? "il pasto" : meal.name) in \(day.name)."
                }
                for food in meal.foods {
                    guard food.quantityGrams.isFinite, food.quantityGrams > 0 else { return "Controlla la quantità di \(food.name)." }
                    if let pieceWeight = food.gramsPerPiece {
                        guard pieceWeight > 0, abs(food.quantityGrams / pieceWeight - (food.quantityGrams / pieceWeight).rounded()) < 0.0001 else {
                            return "Scegli pezzi interi per \(food.name)."
                        }
                    }
                }
            }
        }
        return nil
    }
}
