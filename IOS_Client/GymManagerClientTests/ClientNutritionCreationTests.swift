import Foundation
import XCTest
@testable import GymManagerClient

final class ClientNutritionCreationTests: XCTestCase {
    func testGramServingNormalizationUsesActualReferenceAmount() throws {
        let item = try XCTUnwrap(normalized(unit: "g", serving: 50, calories: 100, pieceWeight: nil))
        XCTAssertEqual(item.caloriesPer100g, 200)
        XCTAssertEqual(item.proteinPer100g, 20)
        XCTAssertNil(item.gramsPerPiece)
    }

    func testPieceServingUsesTrustedGramMetadataAndWholePieces() throws {
        let item = try XCTUnwrap(normalized(unit: "pz", serving: 1, calories: 70, pieceWeight: 50))
        XCTAssertEqual(item.caloriesPer100g, 140)
        let food = ClientNutritionCatalog.food(item, quantity: 2)
        XCTAssertEqual(food.quantityGrams, 100)
        XCTAssertEqual(food.calories, 140)
        XCTAssertEqual(food.asClientFood().unit, "pz")
        XCTAssertEqual(food.asClientFood().quantity, 2)
    }

    func testUnknownPieceWeightAndMilliliterDensityAreNotInvented() {
        XCTAssertNil(normalized(unit: "pz", serving: 1, calories: 70, pieceWeight: nil))
        XCTAssertNil(normalized(unit: "ml", serving: 100, calories: 70, pieceWeight: nil))
        XCTAssertNil(normalized(unit: "g", serving: 0, calories: 70, pieceWeight: nil))
    }

    func testMissingMacroIsNotInventedAsCatalogZero() throws {
        let item = try XCTUnwrap(ClientNutritionCatalog.normalize(id: UUID(), name: "Test", servingAmount: 100, servingUnit: "g", calories: 50, protein: nil, carbs: 10, fat: 0, category: nil, provider: nil, gramsPerPiece: nil))
        XCTAssertNil(item.proteinPer100g)
        XCTAssertEqual(item.fatPer100g, 0)
    }

    func testMealNamesAndWeeklyDraftUseExistingPayload() {
        var answers = ClientNutritionCreationAnswers()
        answers.mealCount = 5; answers.dayCount = 7
        let plan = ClientNutritionDraft.newPlan(answers: answers)
        XCTAssertEqual(plan.source, .manual)
        XCTAssertEqual(plan.days.map(\.weekday), Array(1...7))
        XCTAssertEqual(plan.days[0].meals.map(\.name), ["Colazione", "Spuntino", "Pranzo", "Merenda", "Cena"])
    }

    func testCopyDayPreservesDestinationAndCreatesIndependentNestedIDs() throws {
        var answers = ClientNutritionCreationAnswers(); answers.dayCount = 7
        var plan = ClientNutritionDraft.newPlan(answers: answers)
        let item = try XCTUnwrap(normalized(unit: "g", serving: 100, calories: 100, pieceWeight: nil))
        plan.days[0].meals[0].foods = [ClientNutritionCatalog.food(item, quantity: 100)]
        let source = plan.days[0]
        let destinationID = plan.days[1].id
        ClientNutritionDraft.copyDay(source, into: &plan.days[1])
        XCTAssertEqual(plan.days[1].id, destinationID)
        XCTAssertEqual(plan.days[1].weekday, 2)
        XCTAssertNotEqual(plan.days[1].meals[0].id, source.meals[0].id)
        XCTAssertNotEqual(plan.days[1].meals[0].foods[0].id, source.meals[0].foods[0].id)
        XCTAssertEqual(plan.days[1].meals[0].calories, source.meals[0].calories)
    }

    func testLegacyNutritionPayloadStillDecodesWithoutCreationFields() throws {
        let plan = ClientNutritionDraft.newPlan(answers: ClientNutritionCreationAnswers())
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(plan)) as? [String: Any])
        object.removeValue(forKey: "source"); object.removeValue(forKey: "creationAnswers"); object.removeValue(forKey: "target")
        let decoded = try JSONDecoder().decode(ClientPersonalNutritionPlan.self, from: JSONSerialization.data(withJSONObject: object))
        XCTAssertEqual(decoded.days, plan.days)
        XCTAssertNil(decoded.creationAnswers)
        XCTAssertNil(decoded.target)
    }

    private func normalized(unit: String, serving: Double, calories: Double, pieceWeight: Double?) -> ClientFoodCatalogItem? {
        ClientNutritionCatalog.normalize(id: UUID(), name: "Alimento test", servingAmount: serving, servingUnit: unit, calories: calories, protein: 10, carbs: 10, fat: 5, category: nil, provider: nil, gramsPerPiece: pieceWeight)
    }

    func testMifflinEstimateMatchesDesktopCoefficients() throws {
        var answers = ClientNutritionCreationAnswers()
        answers.age = 30; answers.biologicalSex = .male; answers.heightCm = 180; answers.weightKg = 75
        answers.activity = .active; answers.healthyAdultConfirmed = true
        let target = try ClientNutritionGenerator.target(for: answers)
        XCTAssertEqual(target.restingKcal, 1730)
        XCTAssertEqual(target.estimatedKcal, 2682)
        XCTAssertEqual(target.calories, 2680)
    }

    func testCutAndBulkRemainModestRelativeToMaintenance() throws {
        var answers = ClientNutritionCreationAnswers()
        answers.age = 30; answers.biologicalSex = .male; answers.heightCm = 180; answers.weightKg = 75
        answers.healthyAdultConfirmed = true
        let baseline = try ClientNutritionGenerator.target(for: answers)
        answers.phase = .cut
        XCTAssertEqual(try ClientNutritionGenerator.target(for: answers).calories, (baseline.estimatedKcal * 0.9 / 10).rounded() * 10)
        answers.phase = .bulk
        XCTAssertEqual(try ClientNutritionGenerator.target(for: answers).calories, (baseline.estimatedKcal * 1.05 / 10).rounded() * 10)
    }

    func testAllergyAndMinorGuardFailClosedWithoutInventingSuitability() {
        var answers = ClientNutritionCreationAnswers()
        answers.age = 16; answers.biologicalSex = .female; answers.heightCm = 165; answers.weightKg = 60
        answers.healthyAdultConfirmed = true
        XCTAssertThrowsError(try ClientNutritionGenerator.target(for: answers))
        answers.age = 25; answers.hasAllergiesOrMedicalNeeds = true
        XCTAssertThrowsError(try ClientNutritionGenerator.target(for: answers))
    }

    func testResizePreservesExistingMealAndFoodIDs() throws {
        var answers = ClientNutritionCreationAnswers(); answers.dayCount = 1
        var plan = ClientNutritionDraft.newPlan(answers: answers)
        let item = try XCTUnwrap(normalized(unit: "g", serving: 100, calories: 100, pieceWeight: nil))
        plan.days[0].meals[0].foods = [ClientNutritionCatalog.food(item, quantity: 100)]
        let day = plan.days[0]
        answers.dayCount = 7
        ClientNutritionDraft.resize(&plan, answers: answers, selectedDayID: day.id)
        XCTAssertEqual(plan.days.first(where: { $0.id == day.id }), day)
        XCTAssertEqual(plan.days.count, 7)
    }

    func testGuidedPlanUsesCatalogIDsRoundedGramsAndEditablePayload() throws {
        // Phase5C intentionally denies the legacy owner-less API; real context/IDs/portions
        // are covered by N01–N16 in ClientNutritionCoachEngineTests. No UI authorization in5C.
        XCTAssertThrowsError(try ClientNutritionGenerator.generate(answers: ClientNutritionCreationAnswers(), catalog: fixtureCatalog())) {
            XCTAssertEqual($0 as? ClientNutritionGenerationEligibility, .missingRequiredProfile)
        }
    }

    func testEmptyCatalogDoesNotCreateFictionalFoods() {
        var answers = ClientNutritionCreationAnswers()
        answers.age = 30; answers.biologicalSex = .male; answers.heightCm = 180; answers.weightKg = 75
        answers.healthyAdultConfirmed = true
        XCTAssertThrowsError(try ClientNutritionGenerator.generate(answers: answers, catalog: []))
    }

    private func fixtureCatalog() -> [ClientFoodCatalogItem] {
        let rows: [(String, String, Double, Double, Double, Double)] = [
            ("Yogurt test", "Latticini", 74, 10, 4, 2),
            ("Proteina test", "Proteine animali", 138, 30, 0, 2),
            ("Cereale test", "Carboidrati", 341, 8, 75, 1),
            ("Frutto test", "Frutta", 60, 0, 15, 0),
            ("Verdura test", "Verdura", 28, 2, 5, 0),
            ("Grasso test", "Grassi", 900, 0, 0, 100)
        ]
        return rows.enumerated().map { index, row in
            ClientFoodCatalogItem(id: UUID(uuidString: "10000000-0000-0000-0000-00000000000\(index)")!, name: row.0,
                                  caloriesPer100g: row.2, proteinPer100g: row.3, carbsPer100g: row.4, fatPer100g: row.5, category: row.1)
        }
    }
}
