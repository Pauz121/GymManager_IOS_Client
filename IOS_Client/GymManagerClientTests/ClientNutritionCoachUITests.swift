import Foundation
import XCTest
@testable import GymManagerClient

/// Presentation/domain contracts, not rendered XCUITest acceptance or backend persistence evidence.
final class ClientNutritionCoachUITests: XCTestCase {
    typealias F = ClientNutritionCoachFixtures
    private func inputs() -> ClientNutritionCoachInputs {
        let p = F.profile()
        var i = ClientNutritionCoachInputs()
        i.age = p.age; i.biologicalSex = p.biologicalSex; i.heightCm = p.heightCm; i.weightKg = p.weightKg
        i.dailyActivity = p.activity?.dailyActivity; i.exerciseDays = p.activity?.exerciseDaysPerWeek
        i.phase = .maintenance; i.pattern = p.dietaryPattern; i.health = p.health
        i.dietarySafetyReviewed = true; i.mealCount = 4; i.dayCount = 1
        return i
    }
    private func generated(_ foods: [ClientFoodCatalogItem] = F.catalog()) throws -> ClientPersonalNutritionPlan {
        let i = inputs()
        return try ClientNutritionGenerator.generate(context: .init(mode: .standalone, profile: i.answers.coachProfile),
            answers: i.answers, catalog: foods, now: Date(timeIntervalSince1970: 0))
    }
    private func target(_ plan: ClientPersonalNutritionPlan) -> ClientNutritionSmartReplacement.Target {
        .init(dayID: plan.days[0].id, mealID: plan.days[0].meals[0].id, foodID: plan.days[0].meals[0].foods[0].id)
    }
    private func context(_ plan: ClientPersonalNutritionPlan) -> ClientNutritionCoachContext { .init(mode: .standalone, profile: plan.creationAnswers?.coachProfile) }
    // Same explicitly SYNTHETIC fixture boundary as NREP tests; no real source-review claim.
    private func breakfastOnly(_ row: ClientFoodCatalogItem) throws -> ClientFoodCatalogItem {
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(row)) as? [String: Any])
        var e = try XCTUnwrap(json["nutritionEvidence"] as? [String: Any]); e["allowedMeals"] = ["breakfast"]; json["nutritionEvidence"] = e
        return try JSONDecoder().decode(ClientFoodCatalogItem.self, from: JSONSerialization.data(withJSONObject: json))
    }
    private func candidate() throws -> ClientFoodCatalogItem {
        try breakfastOnly(F.food(20, role: .protein, kcal: 77.5, p: 15, c: 1, f: 1.5, min: 10, max: 500))
    }

    func testUI01AllRequiredInputsCollectableAndNeverImplicitHealth() throws {
        let empty = ClientNutritionCoachInputs()
        XCTAssertEqual(empty.missingStep(), .profile); XCTAssertNil(empty.health.healthyAdultAcknowledged)
        XCTAssertNil(empty.phase); XCTAssertNil(empty.pattern); XCTAssertNil(empty.exerciseDays)
        let full = inputs(); XCTAssertNil(full.missingStep()); XCTAssertEqual(full.eligibility(mode: .standalone), .allowed)
        XCTAssertEqual(full.answers.coachProfile, F.profile())
        for step in ClientNutritionCoachStep.allCases { XCTAssertTrue(full.canAdvance(from: step)) }
    }
    func testUI02ReuseKnownProfileWithoutGuessingMissingMeasures() {
        var i = ClientNutritionCoachInputs(); i.reuse(biologicalSex: .female)
        XCTAssertTrue(i.reusedSex); XCTAssertEqual(i.biologicalSex, .female)
        XCTAssertNil(i.age); XCTAssertNil(i.weightKg); XCTAssertNil(i.dailyActivity); XCTAssertNil(i.health.pregnantOrBreastfeeding)
        i.reuse(biologicalSex: .male); XCTAssertEqual(i.biologicalSex, .female)
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = Date(timeIntervalSince1970: 100000)
        i.reuse(weight: 75, recordedAt: now.addingTimeInterval(-86400), now: now, calendar: calendar)
        XCTAssertNil(i.weightKg)
        i.reuse(weight: 75, recordedAt: now.addingTimeInterval(-600), now: now, calendar: calendar)
        XCTAssertEqual(i.weightKg, 75); XCTAssertTrue(i.reusedWeight)
    }
    func testUI03MissingDataCorrectionPreservesOtherAnswers() {
        var i = inputs(); i.weightKg = nil
        XCTAssertEqual(i.eligibility(mode: .standalone), .missingRequiredProfile)
        XCTAssertEqual(ClientNutritionCoachFeedback.correction(.missingRequiredProfile, inputs: i), .profile)
        XCTAssertEqual(i.exerciseDays, 3); XCTAssertEqual(i.pattern, .omnivore)
    }
    func testUI04TrainerManagedDenialBeforeAnyGeneration() {
        XCTAssertEqual(inputs().eligibility(mode: .trainerConnected), .deniedTrainerManaged)
        XCTAssertEqual(ClientNutritionCoachInputs().eligibility(mode: .trainerConnected), .deniedTrainerManaged)
        XCTAssertThrowsError(try inputs().target(mode: .trainerConnected))
    }
    func testUI05TypedFailuresMapToHumanCorrectiveSteps() {
        let i = inputs()
        for reason in ClientNutritionGenerationEligibility.allPresentationReasons {
            XCTAssertFalse(reason.localizedDescription.isEmpty)
        }
        XCTAssertEqual(ClientNutritionCoachFeedback.correction(.allergyConflict, inputs: i), .safety)
        XCTAssertEqual(ClientNutritionCoachFeedback.correction(.energyTargetUnsafe, inputs: i), .goal)
        XCTAssertEqual(ClientNutritionCoachFeedback.correction(.incompatiblePreferences, inputs: i), .preferences)
        XCTAssertNil(ClientNutritionCoachFeedback.correction(.deniedTrainerManaged, inputs: i))
    }
    func testUI06TargetPreviewUsesExactExistingEnergyEngine() throws {
        let i = inputs(), preview = try i.target(mode: .standalone)
        let existing = try ClientNutritionCoachEnergy.calculate(profile: F.profile(), phase: .maintenance)
        XCTAssertEqual(preview, existing)
        XCTAssertEqual(ClientNutritionCoachFeedback.signed(0.001, unit: "g"), "0 g")
        XCTAssertEqual(ClientNutritionCoachFeedback.signed(1.2, unit: "g"), "+1 g")
    }
    func testUI07GeneratedPreviewHasActualMealsQuantitiesAndTargets() throws {
        let plan = try generated()
        XCTAssertEqual(plan.generationMetadata?.structuralSignature, try generated().generationMetadata?.structuralSignature)
        XCTAssertEqual(plan.days.count, 1); XCTAssertEqual(plan.days[0].meals.count, 4)
        XCTAssertTrue(plan.days[0].meals.allSatisfy { !$0.foods.isEmpty && !$0.name.isEmpty })
        XCTAssertTrue(plan.days[0].meals.flatMap(\.foods).allSatisfy { $0.quantityGrams > 0 && $0.nutritionEvidence != nil })
        XCTAssertEqual(plan.target, try inputs().target(mode: .standalone).target)
    }
    func testUI08AddFoodFilterUsesRealRoleAndOccasionBeforeSelection() throws {
        let plan = try generated(), t = target(plan)
        let rows = ClientNutritionCoachEditing.availableFoods(plan: plan, layout: plan.editProvenance?.nutritionLayout,
            dayID: t.dayID, mealID: t.mealID, role: .protein, catalog: F.catalog())
        XCTAssertTrue(rows.allSatisfy { $0.nutritionEvidence?.roles.contains(.protein) == true && $0.nutritionEvidence?.allowedMeals.contains(.breakfast) == true })
        XCTAssertFalse(rows.contains { $0.id == F.id(3) })
        XCTAssertFalse(rows.contains { plan.days[0].meals[0].foods.compactMap(\.catalogFoodID).contains($0.id) })
    }
    func testUI09AlternativesAreOrderedByActualScoreNotFakePercentage() throws {
        let rows = F.catalog() + [try candidate()], plan = try generated(rows)
        let proposals = try ClientNutritionSmartReplacement.alternatives(plan: plan, target: target(plan), catalog: rows, context: context(plan))
        XCTAssertFalse(proposals.isEmpty)
        for (a, b) in zip(proposals, proposals.dropFirst()) { XCTAssertLessThanOrEqual(a.score.value, b.score.value) }
    }
    func testUI10ReplacementQuantityIsSolvedNotCopied() throws {
        let item = try candidate(), rows = F.catalog() + [item], plan = try generated(rows)
        let proposal = try ClientNutritionSmartReplacement.proposal(plan: plan, target: target(plan), candidateID: item.id, catalog: rows, context: context(plan))
        XCTAssertNotEqual(proposal.original.quantityGrams, proposal.replacement.quantityGrams)
        XCTAssertEqual(proposal.original.quantityGrams * 2, proposal.replacement.quantityGrams)
        XCTAssertTrue(item.nutritionEvidence!.portion.contains(proposal.replacement.quantityGrams))
    }
    func testUI11AllergenTraceExcludedFromSelectableFoods() throws {
        var i = inputs(); i.allergies = [.peanuts]
        let unsafe = F.food(21, role: .protein, kcal: 155, p: 30, c: 2, f: 3, min: 20, max: 250, traces: [.peanuts])
        let rows = F.catalog() + [unsafe]
        let plan = try ClientNutritionGenerator.generate(context: .init(mode: .standalone, profile: i.answers.coachProfile), answers: i.answers, catalog: rows)
        let t = target(plan)
        let available = ClientNutritionCoachEditing.availableFoods(plan: plan, layout: plan.editProvenance?.nutritionLayout, dayID: t.dayID, mealID: t.mealID, role: .protein, catalog: rows)
        XCTAssertFalse(available.contains { $0.id == unsafe.id })
    }
    func testUI12VeganIncompatibilityExcluded() throws {
        var i = inputs(); i.pattern = .vegan
        let unsafe = F.food(22, role: .protein, kcal: 155, p: 30, c: 2, f: 3, min: 20, max: 250, patterns: [.omnivore])
        let rows = F.catalog() + [unsafe]
        let plan = try ClientNutritionGenerator.generate(context: .init(mode: .standalone, profile: i.answers.coachProfile), answers: i.answers, catalog: rows)
        let t = target(plan)
        XCTAssertFalse(ClientNutritionCoachEditing.availableFoods(plan: plan, layout: plan.editProvenance?.nutritionLayout, dayID: t.dayID, mealID: t.mealID, role: .protein, catalog: rows).contains { $0.id == unsafe.id })
    }
    func testUI13ManualQuantityRecalculatesMealAndDayAndRevalidates() throws {
        let plan = try generated(); var draft = plan
        let old = draft.days[0].meals[0].calories
        draft.days[0].meals[0].foods[0].quantityGrams += 10
        XCTAssertNotEqual(old, draft.days[0].meals[0].calories)
        XCTAssertEqual(draft.days[0].meals[0].calories, draft.days[0].meals[0].foods.reduce(0) { $0 + $1.calories })
        draft.days[0].meals[0].foods[0].quantityGrams = 10000
        let result = ClientNutritionCoachEditing.review(original: plan, draft: draft, layout: plan.editProvenance?.nutritionLayout, mode: .standalone, catalog: F.catalog())
        XCTAssertFalse(result.canSave); XCTAssertTrue(result.issues.contains(.portions))
    }
    func testUI14RebalanceDisclosureAndExplicitConsentRequired() throws {
        let item = try breakfastOnly(F.food(24, role: .protein, kcal: 165, p: 30, c: 2, f: 3, min: 20, max: 250))
        let rows = F.catalog() + [item], generated = try generated(rows)
        var layout = try XCTUnwrap(generated.editProvenance?.nutritionLayout)
        let share = generated.days[0].meals[0].calories / (generated.target!.calories * 1.245)
        let moved = layout.days[0].meals[0].energyShare - share
        layout.days[0].meals[1].energyShare += moved; layout.days[0].meals[0].energyShare = share
        let prepared = ClientNutritionCoachEditing.review(original: generated, draft: generated, layout: layout, mode: .standalone, catalog: rows)
        XCTAssertTrue(prepared.canSave)
        let plan = prepared.plan
        var policy = ClientNutritionReplacementPolicy(); policy.allowMealRebalance = true
        let proposal = try ClientNutritionSmartReplacement.proposal(plan: plan, target: target(plan), candidateID: item.id, catalog: rows, context: context(plan), policy: policy)
        XCTAssertTrue(proposal.requiresRebalanceConsent)
        XCTAssertTrue(proposal.additionalChanges.allSatisfy { !$0.explanation.isEmpty && $0.beforeGrams != $0.afterGrams })
        XCTAssertThrowsError(try ClientNutritionSmartReplacement.apply(proposal, to: plan, catalog: rows, context: context(plan)))
        XCTAssertNoThrow(try ClientNutritionSmartReplacement.apply(proposal, to: plan, catalog: rows, context: context(plan), acceptRebalance: true))
    }
    func testUI15EveryEditUsesStrictValidatorAndPreservesOriginalMetadata() throws {
        let plan = try generated(); var draft = plan
        draft.days[0].meals[0].name = "Il mio pasto"; draft.days[0].meals.swapAt(0, 1)
        let checked = ClientNutritionCoachEditing.review(original: plan, draft: draft, layout: plan.editProvenance?.nutritionLayout, mode: .standalone, catalog: F.catalog())
        XCTAssertTrue(checked.canSave); XCTAssertTrue(checked.plan.editProvenance?.hasUserEdits == true)
        XCTAssertEqual(checked.plan.generationMetadata, plan.generationMetadata)
        XCTAssertTrue(ClientNutritionCoachEditing.review(original: plan, draft: draft, layout: plan.editProvenance?.nutritionLayout, mode: .standalone, catalog: []).issues.contains(.catalog))
        draft.days[0].meals[0].foods[0].nutritionEvidence = nil
        XCTAssertFalse(ClientNutritionCoachEditing.review(original: plan, draft: draft, layout: plan.editProvenance?.nutritionLayout, mode: .standalone, catalog: F.catalog()).canSave)
    }
    func testUI16OwnerPinAndTrainerLinkRecheckBeforeSave() {
        let a = F.id(900), b = F.id(901)
        XCTAssertNoThrow(try ClientNutritionCoachOwnership.check(actualOwnerID: a, expectedOwnerID: a, mode: .standalone))
        XCTAssertThrowsError(try ClientNutritionCoachOwnership.check(actualOwnerID: b, expectedOwnerID: a, mode: .standalone))
        XCTAssertThrowsError(try ClientNutritionCoachOwnership.check(actualOwnerID: a, expectedOwnerID: a, mode: .trainerConnected))
        XCTAssertThrowsError(try ClientNutritionCoachOwnership.check(actualOwnerID: nil, expectedOwnerID: a, mode: nil))
        XCTAssertFalse(ClientNutritionCoachSaveState.localDraft.isConfirmed)
        XCTAssertFalse(ClientNutritionCoachSaveState.failure("Non sincronizzato").isConfirmed)
    }
    func testUI17EditedMetadataSurvivesPayloadJSONNotARealDatabaseTest() throws {
        let plan = try generated(); var draft = plan; draft.title = "Piano modificato"
        let checked = ClientNutritionCoachEditing.review(original: plan, draft: draft, layout: plan.editProvenance?.nutritionLayout, mode: .standalone, catalog: F.catalog())
        XCTAssertTrue(checked.canSave)
        let decoded = try JSONDecoder().decode(ClientPersonalNutritionPlan.self, from: JSONEncoder().encode(checked.plan))
        XCTAssertEqual(decoded.editProvenance, checked.plan.editProvenance); XCTAssertEqual(decoded.generationMetadata, plan.generationMetadata)
    }
    func testUI18BackwardDecodeWithoutCoachFields() throws {
        let plan = ClientNutritionDraft.newPlan(answers: .init(), now: Date(timeIntervalSince1970: 0))
        var row = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(plan)) as? [String: Any])
        row.removeValue(forKey: "generationMetadata"); row.removeValue(forKey: "editProvenance"); row.removeValue(forKey: "creationAnswers")
        let legacy = try JSONDecoder().decode(ClientPersonalNutritionPlan.self, from: JSONSerialization.data(withJSONObject: row))
        XCTAssertNil(legacy.editProvenance); XCTAssertNil(legacy.generationMetadata); XCTAssertEqual(legacy.days, plan.days)
    }
    func testUI19OldManualPlanKeepsExistingCopyAndNoCoachTarget() throws {
        let manual = ClientNutritionDraft.newPlan(answers: .init())
        XCTAssertEqual(manual.source, .manual); XCTAssertNil(manual.target); XCTAssertNil(manual.editProvenance)
        let row = F.catalog()[0]; let food = ClientNutritionCatalog.food(row, quantity: 100)
        let meal = ClientPersonalMeal(id: F.id(99), name: "Pasto", foods: [food]), copy = ClientNutritionDraft.copy(meal)
        XCTAssertNotEqual(copy.id, meal.id); XCTAssertNotEqual(copy.foods[0].id, food.id)
        XCTAssertEqual(copy.foods[0].quantityGrams, 100)
    }
    func testUI20FixedPlanAndCatalogHaveIdenticalSuggestedAlternatives() throws {
        let rows = F.catalog() + [try candidate()], plan = try generated(rows), t = target(plan)
        let a = try ClientNutritionSmartReplacement.alternatives(plan: plan, target: t, catalog: rows, context: context(plan))
        let b = try ClientNutritionSmartReplacement.alternatives(plan: plan, target: t, catalog: Array(rows.reversed()), context: context(plan))
        XCTAssertEqual(a.map(\.replacement), b.map(\.replacement)); XCTAssertEqual(a.map(\.score), b.map(\.score))
    }
}

private extension ClientNutritionGenerationEligibility {
    static var allPresentationReasons: [Self] {
        [.allowed,.deniedUnauthenticated,.deniedTrainerManaged,.underAge,.pregnancyOrBreastfeeding,.eatingDisorderRisk,
         .medicalConditionRequiresProfessional,.missingRequiredProfile,.invalidAnthropometrics,.unsupportedGoal,.energyTargetUnsafe,
         .insufficientFoodData,.allergyConflict,.incompatiblePreferences,.fitFailed,.invalidPlan]
    }
}
