import Foundation
import XCTest
@testable import GymManagerClient

final class ClientNutritionCoachEngineTests: XCTestCase {
    typealias F = ClientNutritionCoachFixtures
    private func generate(_ profile: ClientNutritionCoachProfile = F.profile(),
                          answers: ClientNutritionCreationAnswers = F.answers(),
                          foods: [ClientFoodCatalogItem] = F.catalog()) throws -> ClientPersonalNutritionPlan {
        try ClientNutritionGenerator.generate(context: .init(mode: .standalone, profile: profile),
            answers: answers, catalog: foods, now: Date(timeIntervalSince1970: 0))
    }
    private func assertValid(_ plan: ClientPersonalNutritionPlan, _ profile: ClientNutritionCoachProfile,
                             foods: [ClientFoodCatalogItem] = F.catalog(), file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(ClientNutritionPlanValidator.inspect(plan, context: .init(mode: .standalone, profile: profile), catalog: foods).isEmpty,
                      file: file, line: line)
    }
    func testN01AdultMaleMaintenanceFourMeals() throws {
        let plan = try generate()
        assertValid(plan, F.profile())
        XCTAssertEqual(plan.days[0].meals.count, 4)
        XCTAssertEqual(plan.generationMetadata?.energy.estimatedRMR, 1730)
    }
    func testN02AdultFemaleMaintenanceThreeMeals() throws {
        var profile = F.profile(); profile.biologicalSex = .female; profile.weightKg = 60; profile.heightCm = 165
        var answers = F.answers(); answers.mealCount = 3
        let plan = try generate(profile, answers: answers)
        assertValid(plan, profile)
        XCTAssertEqual(plan.days[0].meals.count, 3)
    }
    func testN03ResistanceMuscleGainFourMeals() throws {
        var answers = F.answers(); answers.phase = .bulk
        let plan = try generate(answers: answers)
        let e = try XCTUnwrap(plan.generationMetadata?.energy)
        XCTAssertEqual(e.proteinGramsPerKg, 1.8)
        XCTAssertEqual(e.calorieTarget, (e.estimatedMaintenance * 1.05 / 10).rounded() * 10)
        assertValid(plan, F.profile())
    }
    func testN04FemaleResistanceFatLoss() throws {
        var profile = F.profile(); profile.biologicalSex = .female; profile.weightKg = 65; profile.heightCm = 170
        var answers = F.answers(); answers.phase = .cut
        let plan = try generate(profile, answers: answers)
        XCTAssertEqual(plan.generationMetadata?.energy.proteinGramsPerKg, 2)
        assertValid(plan, profile)
    }
    func testN05VegetarianMaintenance() throws {
        var profile = F.profile(); profile.dietaryPattern = .vegetarian
        let plan = try generate(profile)
        assertValid(plan, profile)
        XCTAssertTrue(plan.days.flatMap(\.meals).flatMap(\.foods).allSatisfy {
            $0.nutritionEvidence?.compatiblePatterns.contains(.vegetarian) == true
        })
    }
    func testN06VeganGainCompatibleCatalog() throws {
        var profile = F.profile(); profile.dietaryPattern = .vegan
        var answers = F.answers(); answers.phase = .bulk
        let plan = try generate(profile, answers: answers)
        assertValid(plan, profile)
        XCTAssertTrue(plan.days.flatMap(\.meals).flatMap(\.foods).allSatisfy {
            $0.nutritionEvidence?.compatiblePatterns.contains(.vegan) == true
        })
    }
    func testN07LactoseIntoleranceHardExclusion() throws {
        var profile = F.profile(); profile.intolerances = [.lactose]
        let milk = F.food(9, role: .protein, kcal: 155, p: 30, c: 2, f: 3, min: 20, max: 250, intolerance: [.lactose])
        let catalog = F.catalog() + [milk]
        let plan = try generate(profile, foods: catalog)
        assertValid(plan, profile, foods: catalog)
        XCTAssertFalse(plan.days.flatMap(\.meals).flatMap(\.foods).contains { $0.catalogFoodID == milk.id })
    }
    func testN08FoodAllergyIncludesTraces() throws {
        var profile = F.profile(); profile.allergies = [.peanuts]
        let unsafe = F.food(10, role: .protein, kcal: 155, p: 30, c: 2, f: 3, min: 20, max: 250, traces: [.peanuts])
        let catalog = F.catalog() + [unsafe]
        let plan = try generate(profile, foods: catalog)
        XCTAssertFalse(plan.days.flatMap(\.meals).flatMap(\.foods).contains { $0.catalogFoodID == unsafe.id })
        assertValid(plan, profile, foods: catalog)
    }
    func testN09MultipleExplicitExclusions() throws {
        var profile = F.profile(); profile.excludedFoodIDs = [F.id(6), F.id(77)]
        var answers = F.answers(); answers.excludedFoodIDs = [F.id(78)]
        let plan = try generate(profile, answers: answers)
        XCTAssertTrue(plan.days.flatMap(\.meals).flatMap(\.foods).compactMap(\.catalogFoodID).allSatisfy {
            ![F.id(6), F.id(77), F.id(78)].contains($0)
        })
        assertValid(plan, profile)
    }
    func testN10UnsafeLowTargetRejectedWithoutClamp() {
        var profile = F.profile(); profile.biologicalSex = .female; profile.age = 70
        profile.weightKg = 40; profile.heightCm = 140; profile.activity = .init(dailyActivity: .seated, exerciseDaysPerWeek: 0)
        XCTAssertThrowsError(try generate(profile)) {
            XCTAssertEqual($0 as? ClientNutritionGenerationEligibility, .energyTargetUnsafe)
        }
    }
    func testN11TrainerConnectedDeniedBeforeProfileCalculation() {
        XCTAssertThrowsError(try ClientNutritionGenerator.generate(context: .init(mode: .trainerConnected, profile: nil),
            answers: F.answers(), catalog: F.catalog())) {
            XCTAssertEqual($0 as? ClientNutritionGenerationEligibility, .deniedTrainerManaged)
        }
    }
    func testN12MissingAnthropometricsDenied() {
        var profile = F.profile(); profile.heightCm = nil
        XCTAssertThrowsError(try generate(profile)) { XCTAssertEqual($0 as? ClientNutritionGenerationEligibility, .missingRequiredProfile) }
    }
    func testN13SameInputsAndCatalogPermutationSameStructuralSignature() throws {
        let a = try generate(), b = try generate(foods: Array(F.catalog().reversed()))
        XCTAssertEqual(a.generationMetadata?.structuralSignature, b.generationMetadata?.structuralSignature)
        XCTAssertNotEqual(a.id, b.id)
        XCTAssertEqual(a.generationMetadata?.catalogFingerprint, b.generationMetadata?.catalogFingerprint)
    }
    func testN14MissingMacroNotAdmittedAsZero() {
        var catalog = F.catalog()
        let good = catalog.removeFirst()
        let invalid = ClientFoodCatalogItem(id: good.id, name: good.name, caloriesPer100g: good.caloriesPer100g,
            proteinPer100g: nil, carbsPer100g: good.carbsPer100g, fatPer100g: good.fatPer100g,
            provider: good.provider, nutritionEvidence: good.nutritionEvidence)
        XCTAssertFalse(ClientNutritionFoodPolicy.valid(invalid))
        XCTAssertFalse(ClientNutritionFoodPolicy.admit(catalog + [invalid], profile: F.profile(), excluded: []).contains { $0.id == good.id })
    }
    func testN15InsufficientCatalogExplicitFailure() {
        XCTAssertThrowsError(try generate(foods: [])) { XCTAssertEqual($0 as? ClientNutritionGenerationEligibility, .insufficientFoodData) }
        XCTAssertThrowsError(try generate(foods: [F.catalog()[0]]))
    }
    func testN16EveryDayInsideExplicitTolerances() throws {
        var answers = F.answers(); answers.dayCount = 7
        let plan = try generate(answers: answers)
        assertValid(plan, F.profile())
        XCTAssertEqual(plan.days.map(\.weekday), Array(1...7))
        let target = try XCTUnwrap(plan.target)
        for day in plan.days {
            let totals = day.meals.reduce(ClientNutritionTotals()) { $0 + .meal($1) }
            XCTAssertTrue(ClientNutritionPlanValidator.dailyValid(totals, target: target))
        }
    }

    func testMifflinKnownMaleAndFemaleValuesAndPrecision() throws {
        XCTAssertEqual(try ClientNutritionCoachEnergy.rmr(age: 30, sex: .male, weightKg: 75, heightCm: 180), 1730)
        XCTAssertEqual(try ClientNutritionCoachEnergy.rmr(age: 30, sex: .female, weightKg: 60, heightCm: 165), 1320.25)
        var profile = F.profile(); profile.biologicalSex = .female; profile.weightKg = 60; profile.heightCm = 165
        let result = try ClientNutritionCoachEnergy.calculate(profile: profile, phase: .maintenance)
        XCTAssertEqual(result.estimatedRMR, 1320.25)
        XCTAssertEqual(result.target.restingKcal, 1320)
    }
    func testInvalidRMRInputs() {
        for kg in [-1.0, 0, .nan, .infinity, 121] {
            XCTAssertThrowsError(try ClientNutritionCoachEnergy.rmr(age: 30, sex: .male, weightKg: kg, heightCm: 180))
        }
        for cm in [0.0, .nan, 221] { XCTAssertThrowsError(try ClientNutritionCoachEnergy.rmr(age: 30, sex: .male, weightKg: 75, heightCm: cm)) }
        for age in [0, 17, 79] { XCTAssertThrowsError(try ClientNutritionCoachEnergy.rmr(age: age, sex: .male, weightKg: 75, heightCm: 180)) }
    }
    func testExplicitHealthGatesAndMinor() {
        var profile = F.profile(); profile.health.pregnantOrBreastfeeding = true
        XCTAssertEqual(ClientNutritionCoachPolicy.evaluate(.init(mode: .standalone, profile: profile), answers: F.answers()), .pregnancyOrBreastfeeding)
        profile = F.profile(); profile.health.eatingDisorderRisk = true
        XCTAssertEqual(ClientNutritionCoachPolicy.evaluate(.init(mode: .standalone, profile: profile), answers: F.answers()), .eatingDisorderRisk)
        profile = F.profile(); profile.health.clinicalNutritionRequired = true
        XCTAssertEqual(ClientNutritionCoachPolicy.evaluate(.init(mode: .standalone, profile: profile), answers: F.answers()), .medicalConditionRequiresProfessional)
        profile = F.profile(); profile.health.pregnantOrBreastfeeding = nil
        XCTAssertEqual(ClientNutritionCoachPolicy.evaluate(.init(mode: .standalone, profile: profile), answers: F.answers()), .missingRequiredProfile)
        profile = F.profile(); profile.age = 17
        XCTAssertEqual(ClientNutritionCoachPolicy.evaluate(.init(mode: .standalone, profile: profile), answers: F.answers()), .underAge)
    }
    func testActivityEvidenceNotOnlyWorkoutCount() {
        let seated = ClientNutritionActivityEvidence(dailyActivity: .seated, exerciseDaysPerWeek: 0)
        let physical = ClientNutritionActivityEvidence(dailyActivity: .physical, exerciseDaysPerWeek: 0)
        XCTAssertEqual(seated.category, .sedentary)
        XCTAssertEqual(physical.category, .active)
        XCTAssertNotEqual(seated.category.coefficient, physical.category.coefficient)
    }
    func testMacroArithmeticReferencesAndRemainingCarbs() throws {
        let e = try ClientNutritionCoachEnergy.calculate(profile: F.profile(), phase: .maintenance)
        XCTAssertEqual(e.target.protein, 120)
        XCTAssertEqual(e.target.fat * 9 / e.target.calories, 0.30, accuracy: 0.000001)
        XCTAssertEqual(e.target.protein * 4 + e.target.carbs * 4 + e.target.fat * 9, e.target.calories, accuracy: 0.000001)
        XCTAssertTrue(ClientNutritionCoachEnergy.validMacros(e.target))
    }
    func testExactPortionArithmeticAndQuantizedBounds() {
        let item = F.catalog()[0]
        let totals = ClientNutritionTotals.food(item, grams: 150)
        XCTAssertEqual(totals.calories, 232.5)
        XCTAssertEqual(totals.protein, 45)
        XCTAssertEqual(totals.carbs, 3)
        XCTAssertEqual(totals.fat, 4.5)
        XCTAssertTrue(item.nutritionEvidence!.portion.contains(150))
        XCTAssertFalse(item.nutritionEvidence!.portion.contains(151))
    }
    func testUnknownUnreviewedAndConflictingFoodRejected() {
        let old = ClientFoodCatalogItem(id: F.id(90), name: "unknown", caloriesPer100g: 100, proteinPer100g: 10, carbsPer100g: 15, fatPer100g: 0)
        XCTAssertFalse(ClientNutritionFoodPolicy.valid(old))
        var conflict = F.catalog()[0]
        conflict = ClientFoodCatalogItem(id: conflict.id, name: "different snapshot", caloriesPer100g: conflict.caloriesPer100g,
            proteinPer100g: conflict.proteinPer100g, carbsPer100g: conflict.carbsPer100g, fatPer100g: conflict.fatPer100g,
            provider: conflict.provider, nutritionEvidence: conflict.nutritionEvidence)
        XCTAssertFalse(ClientNutritionFoodPolicy.admit(F.catalog() + [conflict], profile: F.profile(), excluded: []).contains { $0.id == conflict.id })
    }
    func testValidatorRejectsTamperedQuantitiesMetadataNutrientsAndTarget() throws {
        let original = try generate()
        var altered = original; altered.days[0].meals[0].foods[0].quantityGrams += 1
        XCTAssertFalse(ClientNutritionPlanValidator.inspect(altered, context: .init(mode: .standalone, profile: F.profile()), catalog: F.catalog()).isEmpty)
        altered = original; altered.generationMetadata = nil
        XCTAssertEqual(ClientNutritionPlanValidator.inspect(altered, context: .init(mode: .standalone, profile: F.profile()), catalog: F.catalog()), [.metadata])
        altered = original; altered.days[0].meals[0].foods[0].caloriesPer100g = 999
        XCTAssertTrue(ClientNutritionPlanValidator.inspect(altered, context: .init(mode: .standalone, profile: F.profile()), catalog: F.catalog()).contains(.food))
        altered = original; altered.target = nil
        XCTAssertTrue(ClientNutritionPlanValidator.inspect(altered, context: .init(mode: .standalone, profile: F.profile()), catalog: F.catalog()).contains(.target))
    }
    func testMetadataJSONRoundTripAndLegacyOptionalFields() throws {
        let original = try generate()
        let data = try JSONEncoder().encode(original)
        XCTAssertEqual(try JSONDecoder().decode(ClientPersonalNutritionPlan.self, from: data), original)
        var old = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        old.removeValue(forKey: "generationMetadata")
        let decoded = try JSONDecoder().decode(ClientPersonalNutritionPlan.self, from: JSONSerialization.data(withJSONObject: old))
        XCTAssertNil(decoded.generationMetadata)
        XCTAssertEqual(decoded.days, original.days)
        // Serialization test only, NOT real save/reopen/RLS acceptance.
    }
    func testFiveAndSixMealsCompactAndDeterministic() throws {
        for count in [5, 6] {
            var answers = F.answers(); answers.mealCount = count
            let plan = try generate(answers: answers)
            assertValid(plan, F.profile())
            XCTAssertTrue(plan.days[0].meals.allSatisfy { (1...4).contains($0.foods.count) })
        }
    }
    func testDirectLegacyGenerateCannotAssertOwnerContext() {
        XCTAssertThrowsError(try ClientNutritionGenerator.generate(answers: F.answers(), catalog: F.catalog())) {
            XCTAssertEqual($0 as? ClientNutritionGenerationEligibility, .missingRequiredProfile)
        }
    }
    func testPriorLowRelativeWeightCutGuardPreserved() {
        var profile = F.profile(); profile.biologicalSex = .female
        profile.weightKg = 50; profile.heightCm = 165
        var answers = F.answers(); answers.phase = .cut
        XCTAssertThrowsError(try generate(profile, answers: answers)) {
            XCTAssertEqual($0 as? ClientNutritionGenerationEligibility, .energyTargetUnsafe)
        }
        profile.weightKg = 35; profile.heightCm = 220
        XCTAssertEqual(ClientNutritionCoachPolicy.evaluate(.init(mode: .standalone, profile: profile), answers: F.answers()), .invalidAnthropometrics)
    }
    func testPieceQuantizationUsesWholeRealMetadataUnits() {
        let item = F.food(30, role: .protein, kcal: 155, p: 30, c: 2, f: 3, min: 50, max: 250, step: 50, piece: 50)
        XCTAssertTrue(ClientNutritionFoodPolicy.valid(item))
        let solved = ClientNutritionPortionSolver.fit([
            .init(item: item, role: .protein, bounds: item.nutritionEvidence!.portion, grams: 50)
        ], target: .init(calories: 232.5, protein: 45, carbs: 3, fat: 4.5))
        XCTAssertEqual(solved[0].grams, 150)
        XCTAssertEqual(solved[0].grams / 50, 3)
    }
    func testVeganReviewCannotContradictKnownMilkIngredient() {
        let contradictory = F.food(31, role: .protein, kcal: 155, p: 30, c: 2, f: 3, min: 20, max: 250, allergens: [.milk])
        XCTAssertFalse(ClientNutritionFoodPolicy.valid(contradictory))
    }
}
