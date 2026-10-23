import Foundation
import XCTest
@testable import GymManagerClient

final class ClientNutritionSmartReplacementTests: XCTestCase {
    typealias F = ClientNutritionCoachFixtures
    private func context(_ profile: ClientNutritionCoachProfile = F.profile()) -> ClientNutritionCoachContext {
        .init(mode: .standalone, profile: profile)
    }
    private func generated(_ catalog: [ClientFoodCatalogItem], profile: ClientNutritionCoachProfile = F.profile()) throws -> ClientPersonalNutritionPlan {
        try ClientNutritionGenerator.generate(context: context(profile), answers: F.answers(), catalog: catalog, now: Date(timeIntervalSince1970: 0))
    }
    private func target(_ plan: ClientPersonalNutritionPlan) -> ClientNutritionSmartReplacement.Target {
        .init(dayID: plan.days[0].id, mealID: plan.days[0].meals[0].id, foodID: plan.days[0].meals[0].foods[0].id)
    }
    /// Test-only metadata adaptation, NOT real catalog reviews or production data.
    private func breakfastOnly(_ item: ClientFoodCatalogItem) throws -> ClientFoodCatalogItem {
        var row = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(item)) as? [String: Any])
        var evidence = try XCTUnwrap(row["nutritionEvidence"] as? [String: Any])
        evidence["allowedMeals"] = ["breakfast"]
        row["nutritionEvidence"] = evidence
        return try JSONDecoder().decode(ClientFoodCatalogItem.self, from: JSONSerialization.data(withJSONObject: row))
    }
    private func diluted(_ index: Int = 20, step: Double = 10, piece: Double? = nil) throws -> ClientFoodCatalogItem {
        try breakfastOnly(F.food(index, role: .protein, kcal: 77.5, p: 15, c: 1, f: 1.5,
            min: step, max: 500, step: step, piece: piece))
    }
    func testNREP01SimilarProteinQuantityCalculatedRatherThanCopied() throws {
        let candidate = try diluted(), catalog = F.catalog() + [candidate]
        let plan = try generated(catalog)
        let proposed = try ClientNutritionSmartReplacement.proposal(plan: plan, target: target(plan),
            candidateID: candidate.id, catalog: catalog, context: context())
        XCTAssertNotEqual(proposed.replacement.quantityGrams, proposed.original.quantityGrams)
        XCTAssertEqual(proposed.replacement.quantityGrams, proposed.original.quantityGrams * 2)
        XCTAssertEqual(proposed.difference.protein, 0, accuracy: 0.00001)
        XCTAssertEqual(proposed.plan.source, .guided)
        XCTAssertEqual(proposed.plan.generationMetadata, plan.generationMetadata)
        XCTAssertTrue(proposed.plan.editProvenance?.hasUserEdits == true)
    }
    func testNREP02SameCaloriesWrongMacrosRanksLower() throws {
        let original = ClientNutritionTotals(calories: 232.5, protein: 45, carbs: 3, fat: 4.5)
        let near = ClientNutritionReplacementScore.calculate(original: original, candidate: original, source: .usda, policy: .init())
        let different = ClientNutritionReplacementScore.calculate(original: original,
            candidate: .init(calories: 232.5, protein: 22.5, carbs: 15, fat: 9), source: .usda, policy: .init())
        XCTAssertLessThan(near.value, different.value)
        let precise = try diluted()
        let lessSimilar = try breakfastOnly(F.food(21, role: .protein, kcal: 152, p: 26, c: 3, f: 4, min: 20, max: 250))
        let catalog = F.catalog() + [precise, lessSimilar], plan = try generated(catalog)
        let alternatives = try ClientNutritionSmartReplacement.alternatives(plan: plan, target: target(plan), catalog: catalog, context: context())
        let preciseIndex = try XCTUnwrap(alternatives.firstIndex { $0.replacement.catalogFoodID == precise.id })
        let otherIndex = try XCTUnwrap(alternatives.firstIndex { $0.replacement.catalogFoodID == lessSimilar.id })
        XCTAssertLessThan(preciseIndex, otherIndex)
    }
    func testNREP03AllergenCandidateRejected() throws {
        var profile = F.profile(); profile.allergies = [.peanuts]
        let unsafe = try breakfastOnly(F.food(21, role: .protein, kcal: 155, p: 30, c: 2, f: 3, min: 20, max: 250, traces: [.peanuts]))
        let catalog = F.catalog() + [unsafe], plan = try generated(catalog, profile: profile)
        XCTAssertThrowsError(try ClientNutritionSmartReplacement.proposal(plan: plan, target: target(plan),
            candidateID: unsafe.id, catalog: catalog, context: context(profile)))
    }
    func testNREP04VeganIncompatibleCandidateRejected() throws {
        var profile = F.profile(); profile.dietaryPattern = .vegan
        let animal = try breakfastOnly(F.food(22, role: .protein, kcal: 155, p: 30, c: 2, f: 3, min: 20, max: 250, patterns: [.omnivore]))
        let catalog = F.catalog() + [animal], plan = try generated(catalog, profile: profile)
        XCTAssertThrowsError(try ClientNutritionSmartReplacement.proposal(plan: plan, target: target(plan),
            candidateID: animal.id, catalog: catalog, context: context(profile)))
    }
    func testNREP05WholePiecePortionQuantization() throws {
        let candidate = try diluted(step: 50, piece: 50), catalog = F.catalog() + [candidate]
        let plan = try generated(catalog)
        let proposed = try ClientNutritionSmartReplacement.proposal(plan: plan, target: target(plan),
            candidateID: candidate.id, catalog: catalog, context: context())
        XCTAssertEqual(proposed.replacement.quantityGrams.truncatingRemainder(dividingBy: 50), 0)
        XCTAssertTrue(candidate.nutritionEvidence!.portion.contains(proposed.replacement.quantityGrams))
    }
    func testNREP06OutsidePortionCapacityRejected() throws {
        let candidate = try breakfastOnly(F.food(23, role: .protein, kcal: 7.75, p: 1.5, c: 0.1, f: 0.15, min: 10, max: 50))
        let catalog = F.catalog() + [candidate], plan = try generated(catalog)
        XCTAssertThrowsError(try ClientNutritionSmartReplacement.proposal(plan: plan, target: target(plan),
            candidateID: candidate.id, catalog: catalog, context: context())) {
            XCTAssertEqual($0 as? ClientSmartPlanEditError, .portionBoundsPreventMatch)
        }
    }
    func testNREP07MealStillInsideToleranceAndNoHiddenChanges() throws {
        let candidate = try diluted(), catalog = F.catalog() + [candidate], plan = try generated(catalog)
        let proposed = try ClientNutritionSmartReplacement.proposal(plan: plan, target: target(plan),
            candidateID: candidate.id, catalog: catalog, context: context())
        XCTAssertTrue(proposed.additionalChanges.isEmpty)
        XCTAssertEqual(Array(plan.days[0].meals[0].foods.dropFirst()), Array(proposed.plan.days[0].meals[0].foods.dropFirst()))
        XCTAssertEqual(Array(plan.days[0].meals.dropFirst()), Array(proposed.plan.days[0].meals.dropFirst()))
        XCTAssertTrue(ClientNutritionPlanValidator.inspect(proposed.plan, context: context(), catalog: catalog).isEmpty)
    }
    func testNREP08DailyTotalsRevalidated() throws {
        let candidate = try diluted(), catalog = F.catalog() + [candidate], plan = try generated(catalog)
        let proposed = try ClientNutritionSmartReplacement.proposal(plan: plan, target: target(plan),
            candidateID: candidate.id, catalog: catalog, context: context())
        let totals = proposed.plan.days[0].meals.reduce(ClientNutritionTotals()) { $0 + .meal($1) }
        XCTAssertTrue(ClientNutritionPlanValidator.dailyValid(totals, target: proposed.plan.target!))
        var invalid = proposed.plan
        invalid.days[0].meals[1].foods[0].quantityGrams = 10000
        let checked = ClientEditedNutritionPlanValidator().prepare(original: proposed.plan, edited: invalid, context: context(), catalog: catalog)
        XCTAssertFalse(checked.canSave)
        XCTAssertTrue(checked.issues.contains(.dayTotals))
    }
    func testNREP09RebalanceRequiredDisclosedAndExplicitConsentOnly() throws {
        // Synthetic stored energy differs modestly from4/4/9,which the actual5C quality rule allows.
        let candidate = try breakfastOnly(F.food(24, role: .protein, kcal: 165, p: 30, c: 2, f: 3, min: 20, max: 250))
        let catalog = F.catalog() + [candidate]
        let generated = try self.generated(catalog)
        var layout = try XCTUnwrap(generated.editProvenance?.nutritionLayout)
        let total = generated.days[0].meals[0].calories
        let lowShare = total / (generated.target!.calories * 1.245)
        let moved = layout.days[0].meals[0].energyShare - lowShare
        layout.days[0].meals[0].energyShare = lowShare
        layout.days[0].meals[1].energyShare += moved
        let prepared = ClientEditedNutritionPlanValidator().prepare(original: generated, edited: generated, layout: layout, context: context(), catalog: catalog)
        XCTAssertTrue(prepared.canSave)
        let plan = prepared.plan
        XCTAssertThrowsError(try ClientNutritionSmartReplacement.proposal(plan: plan, target: target(plan),
            candidateID: candidate.id, catalog: catalog, context: context()))
        var policy = ClientNutritionReplacementPolicy(); policy.allowMealRebalance = true
        let proposal = try ClientNutritionSmartReplacement.proposal(plan: plan, target: target(plan),
            candidateID: candidate.id, catalog: catalog, context: context(), policy: policy)
        XCTAssertTrue(proposal.requiresRebalanceConsent)
        XCTAssertFalse(proposal.additionalChanges.isEmpty)
        XCTAssertTrue(proposal.additionalChanges.allSatisfy { !$0.explanation.isEmpty && $0.beforeGrams != $0.afterGrams })
        XCTAssertThrowsError(try ClientNutritionSmartReplacement.apply(proposal, to: plan, catalog: catalog, context: context())) {
            XCTAssertEqual($0 as? ClientSmartPlanEditError, .rebalanceConsentRequired)
        }
        let accepted = try ClientNutritionSmartReplacement.apply(proposal, to: plan, catalog: catalog, context: context(), acceptRebalance: true)
        XCTAssertTrue(ClientNutritionPlanValidator.inspect(accepted, context: context(), catalog: catalog).isEmpty)
    }
    func testNREP10NoCompatibleReplacementExplicitFailure() throws {
        let catalog = F.catalog(), plan = try generated(catalog)
        // Fat slot has exactly one compatible fat source;the current food is not its own alternative.
        let t = ClientNutritionSmartReplacement.Target(dayID: plan.days[0].id, mealID: plan.days[0].meals[0].id, foodID: plan.days[0].meals[0].foods[3].id)
        XCTAssertThrowsError(try ClientNutritionSmartReplacement.alternatives(plan: plan, target: t, catalog: catalog, context: context())) {
            XCTAssertEqual($0 as? ClientSmartPlanEditError, .noCompatibleAlternative)
        }
    }
    func testRenameReorderAndDistributionEditableWithoutChangingGenerationProvenance() throws {
        let catalog = F.catalog(), original = try generated(catalog)
        var edited = original
        edited.days[0].meals[0].name = "Il mio primo pasto"
        edited.days[0].meals.swapAt(0, 1)
        edited.days[0].meals[1].foods.reverse()
        let result = ClientEditedNutritionPlanValidator().prepare(original: original, edited: edited, context: context(), catalog: catalog)
        XCTAssertTrue(result.canSave)
        XCTAssertEqual(result.plan.generationMetadata, original.generationMetadata)
        XCTAssertTrue(result.plan.editProvenance?.hasUserEdits == true)
        XCTAssertFalse(ClientNutritionPlanValidator.inspectCore(edited, context: context(), catalog: catalog).isEmpty)
    }
    func testDeterministicAlternativesAndStalePreviewRejected() throws {
        let candidate = try diluted(), catalog = F.catalog() + [candidate], plan = try generated(catalog)
        let a = try ClientNutritionSmartReplacement.alternatives(plan: plan, target: target(plan), catalog: catalog, context: context())
        let b = try ClientNutritionSmartReplacement.alternatives(plan: plan, target: target(plan), catalog: Array(catalog.reversed()), context: context())
        XCTAssertEqual(a.map { $0.replacement.catalogFoodID }, b.map { $0.replacement.catalogFoodID })
        XCTAssertEqual(a.map { $0.replacement.quantityGrams }, b.map { $0.replacement.quantityGrams })
        var changed = plan; changed.title = "Piano modificato"
        XCTAssertThrowsError(try ClientNutritionSmartReplacement.apply(a[0], to: changed, catalog: catalog, context: context())) {
            XCTAssertEqual($0 as? ClientSmartPlanEditError, .stalePreview)
        }
    }
    func testEditedMetadataAndLayoutSurviveJSONRoundTrip() throws {
        let catalog = F.catalog(), original = try generated(catalog)
        var edited = original; edited.days[0].meals[0].name = "Pasto personale"
        let result = ClientEditedNutritionPlanValidator().prepare(original: original, edited: edited, context: context(), catalog: catalog)
        XCTAssertTrue(result.canSave)
        let restored = try JSONDecoder().decode(ClientPersonalNutritionPlan.self, from: JSONEncoder().encode(result.plan))
        XCTAssertEqual(restored, result.plan)
        XCTAssertTrue(ClientNutritionPlanValidator.inspect(restored, context: context(), catalog: catalog).isEmpty)
        // JSON only,NOT server-save/reopen or RLS evidence.
    }
    func testExtremeDistributionAndForgedOriginRejected() throws {
        let catalog = F.catalog(), original = try generated(catalog)
        var layout = try XCTUnwrap(original.editProvenance?.nutritionLayout)
        layout.days[0].meals[0].proteinShare = 0.97
        for index in 1..<layout.days[0].meals.count { layout.days[0].meals[index].proteinShare = 0.01 }
        XCTAssertFalse(ClientEditedNutritionPlanValidator().prepare(original: original, edited: original,
            layout: layout, context: context(), catalog: catalog).canSave)
        var forged = original; forged.title = "Modifica non preparata"
        XCTAssertTrue(ClientNutritionPlanValidator.inspect(forged, context: context(), catalog: catalog).contains(.metadata))
    }
}
