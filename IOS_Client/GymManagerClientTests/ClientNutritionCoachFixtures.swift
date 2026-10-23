import Foundation
@testable import GymManagerClient

/// SYNTHETIC TEST RECORDS ONLY. Never a production seed, CREA/USDA record or safe ingredient claim.
enum ClientNutritionCoachFixtures {
    static func answers() -> ClientNutritionCreationAnswers {
        var value = ClientNutritionCreationAnswers()
        value.mealCount = 4; value.dayCount = 1
        return value
    }
    static func profile() -> ClientNutritionCoachProfile {
        ClientNutritionCoachProfile(age: 30, biologicalSex: .male, weightKg: 75, heightCm: 180,
            activity: .init(dailyActivity: .mixed, exerciseDaysPerWeek: 3),
            health: .init(healthyAdultAcknowledged: true, pregnantOrBreastfeeding: false,
                          eatingDisorderRisk: false, clinicalNutritionRequired: false),
            dietaryPattern: .omnivore, allergies: [], intolerances: [], excludedFoodIDs: [])
    }
    static func id(_ index: Int) -> UUID {
        UUID(uuidString: String(format: "20000000-0000-0000-0000-%012d", index))!
    }
    static func food(_ index: Int, role: ClientNutritionFoodRole, kcal: Double, p: Double, c: Double, f: Double,
                     min: Double, max: Double, step: Double = 10,
                     patterns: Set<ClientNutritionDietPattern> = Set(ClientNutritionDietPattern.allCases),
                     allergens: Set<ClientNutritionAllergen> = [], traces: Set<ClientNutritionAllergen> = [],
                     intolerance: Set<ClientNutritionIntolerance> = [], piece: Double? = nil) -> ClientFoodCatalogItem {
        // Source/provenance are test inputs to exercise admission, NOT claims about real providers.
        let evidence = ClientNutritionFoodEvidence(reviewVersion: ClientNutritionCoachRules.foodReviewVersion,
            reviewReference: "SYNTHETIC-REVIEW-TEST-ONLY", canonicalID: id(index), source: .usda,
            sourceID: "SYNTHETIC-\(index)", sourceURL: "https://example.test/fixture/\(index)",
            datasetRevision: "synthetic-v1", cacheProvenance: "XCTest-fixture", cacheRevision: "synthetic-cache-v1",
            sourceServingAmount: 100, sourceServingUnit: "g", foodState: "synthetic-state",
            roles: [role], allowedMeals: Set(ClientNutritionMealOccasion.allCases),
            compatiblePatterns: patterns, assessedAllergens: Set(ClientNutritionAllergen.allCases),
            containsAllergens: allergens, traceAllergens: traces,
            assessedIntolerances: Set(ClientNutritionIntolerance.allCases), incompatibleIntolerances: intolerance,
            portion: .init(minimumGrams: min, maximumGrams: max, stepGrams: step))
        return ClientFoodCatalogItem(id: id(index), name: "Synthetic fixture \(index)", caloriesPer100g: kcal,
            proteinPer100g: p, carbsPer100g: c, fatPer100g: f, provider: "usda", gramsPerPiece: piece,
            nutritionEvidence: evidence)
    }
    static func catalog() -> [ClientFoodCatalogItem] {
        [
            food(1, role: .protein, kcal: 155, p: 30, c: 2, f: 3, min: 20, max: 250),
            food(2, role: .carbohydrate, kcal: 337, p: 2, c: 80, f: 1, min: 10, max: 200),
            food(3, role: .fat, kcal: 900, p: 0, c: 0, f: 100, min: 5, max: 40, step: 5),
            food(4, role: .vegetable, kcal: 28, p: 2, c: 5, f: 0, min: 100, max: 300),
            food(5, role: .fruit, kcal: 60, p: 0, c: 15, f: 0, min: 100, max: 250),
            food(6, role: .protein, kcal: 146, p: 28, c: 4, f: 2, min: 20, max: 250)
        ]
    }
}
