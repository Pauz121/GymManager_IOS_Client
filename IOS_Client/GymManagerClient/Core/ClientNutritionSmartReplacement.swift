import Foundation

struct ClientNutritionReplacementPolicy: Sendable {
    var objective: ClientNutritionFitObjective = .replacement
    var sourcePenalty = 0.01
    var maximumItemEnergyDistance = 0.25
    var maximumRoleNutrientDistance = 0.30
    var allowMealRebalance = false
    var maximumOtherFoodSteps = 1
    var isValid: Bool {
        objective.isValid && sourcePenalty.isFinite && (0...0.05).contains(sourcePenalty) &&
            maximumItemEnergyDistance.isFinite && (0...0.25).contains(maximumItemEnergyDistance) &&
            maximumRoleNutrientDistance.isFinite && (0...0.30).contains(maximumRoleNutrientDistance) &&
            (0...1).contains(maximumOtherFoodSteps)
    }
}

struct ClientNutritionReplacementScore: Equatable, Sendable {
    let nutrientDistance: Double
    let sourcePenalty: Double
    var value: Double { nutrientDistance + sourcePenalty }
    static func calculate(original: ClientNutritionTotals, candidate: ClientNutritionTotals,
                          source: ClientNutritionFoodSource, policy: ClientNutritionReplacementPolicy) -> Self {
        Self(nutrientDistance: ClientNutritionPortionSolver.score(candidate, original, objective: policy.objective),
             sourcePenalty: Double(source.priority) * policy.sourcePenalty)
    }
}

struct ClientNutritionReplacementDifference: Equatable, Sendable {
    let before: ClientNutritionTotals
    let after: ClientNutritionTotals
    var calories: Double { after.calories - before.calories }
    var protein: Double { after.protein - before.protein }
    var carbs: Double { after.carbs - before.carbs }
    var fat: Double { after.fat - before.fat }
}

struct ClientNutritionRebalanceChange: Equatable, Sendable {
    let foodID: UUID
    let name: String
    let beforeGrams: Double
    let afterGrams: Double
    /// UI5D must display this disclosure before consent, not hidden automatic recalibration.
    var explanation: String {
        "Per mantenere i macro del pasto, \(name): \(beforeGrams.formatted(.number.precision(.fractionLength(0...1)))) g → \(afterGrams.formatted(.number.precision(.fractionLength(0...1)))) g."
    }
}

enum ClientNutritionSmartReplacement {
    struct Target: Equatable, Sendable { let dayID: UUID; let mealID: UUID; let foodID: UUID }
    struct Proposal: Sendable {
        let parentPlanID: UUID
        let parentSignature: String
        let catalogFingerprint: String
        let target: Target
        let original: ClientPersonalFood
        let replacement: ClientPersonalFood
        let difference: ClientNutritionReplacementDifference
        let score: ClientNutritionReplacementScore
        let additionalChanges: [ClientNutritionRebalanceChange]
        let plan: ClientPersonalNutritionPlan
        let policy: ClientNutritionReplacementPolicy
        var requiresRebalanceConsent: Bool { !additionalChanges.isEmpty }
    }

    static func alternatives(plan original: ClientPersonalNutritionPlan, target: Target, catalog: [ClientFoodCatalogItem],
                             context: ClientNutritionCoachContext, policy: ClientNutritionReplacementPolicy = .init()) throws -> [Proposal] {
        guard let answers = original.creationAnswers else { throw ClientSmartPlanEditError.invalidOriginal }
        let eligibility = ClientNutritionCoachPolicy.evaluate(context, answers: answers)
        guard eligibility == .allowed else { throw eligibility }
        guard policy.isValid, ClientNutritionPlanValidator.inspect(original, context: context, catalog: catalog).isEmpty else {
            throw ClientSmartPlanEditError.invalidOriginal
        }
        let baseline = ClientPlanEditing.beginNutrition(original)
        guard let profile = context.profile,
              let layout = baseline.editProvenance?.nutritionLayout else { throw ClientSmartPlanEditError.invalidOriginal }
        let admitted = ClientNutritionFoodPolicy.admit(catalog, profile: profile, excluded: Set(answers.excludedFoodIDs))
        let sourceFingerprint = ClientNutritionFoodPolicy.fingerprint(admitted)
        let proposals = admitted.compactMap {
            try? proposal(plan: baseline, target: target, candidateID: $0.id, catalog: catalog, context: context, policy: policy)
        }.sorted {
            if $0.score.value != $1.score.value { return $0.score.value < $1.score.value }
            return ($0.replacement.catalogFoodID?.uuidString ?? "") < ($1.replacement.catalogFoodID?.uuidString ?? "")
        }
        guard !proposals.isEmpty else { throw ClientSmartPlanEditError.noCompatibleAlternative }
        // Assertions are not acceptance. Every returned proposal already passed the independent full-plan validator.
        guard proposals.allSatisfy({ $0.catalogFingerprint == sourceFingerprint && $0.parentSignature ==
            ClientSmartPlanFingerprint.nutrition(original, layout: layout) }) else { throw ClientSmartPlanEditError.invalidOriginal }
        return proposals
    }

    /// Also supports an explicitly searched real catalog candidate. Different roles stay blocked.
    static func proposal(plan original: ClientPersonalNutritionPlan, target: Target, candidateID: UUID,
                         catalog: [ClientFoodCatalogItem], context: ClientNutritionCoachContext,
                         policy: ClientNutritionReplacementPolicy = .init()) throws -> Proposal {
        guard let answers = original.creationAnswers else { throw ClientSmartPlanEditError.invalidOriginal }
        let eligibility = ClientNutritionCoachPolicy.evaluate(context, answers: answers)
        guard eligibility == .allowed else { throw eligibility }
        guard policy.isValid, ClientNutritionPlanValidator.inspect(original, context: context, catalog: catalog).isEmpty,
              let profile = context.profile else { throw ClientSmartPlanEditError.invalidOriginal }
        let baseline = ClientPlanEditing.beginNutrition(original)
        guard let layout = baseline.editProvenance?.nutritionLayout,
              let day = baseline.days.firstIndex(where: { $0.id == target.dayID }),
              let meal = baseline.days[day].meals.firstIndex(where: { $0.id == target.mealID }),
              let index = baseline.days[day].meals[meal].foods.firstIndex(where: { $0.id == target.foodID }),
              let spec = layout.meal(dayID: target.dayID, mealID: target.mealID),
              let role = spec.foodRoles.first(where: { $0.foodID == target.foodID })?.role,
              let parentSignature = ClientSmartPlanFingerprint.nutrition(original, layout: layout),
              let energy = baseline.target else { throw ClientSmartPlanEditError.missingTarget }
        let admitted = ClientNutritionFoodPolicy.admit(catalog, profile: profile, excluded: Set(answers.excludedFoodIDs))
        let beforeMeal = baseline.days[day].meals[meal]
        let beforeFood = beforeMeal.foods[index]
        let used = Set(beforeMeal.foods.enumerated().filter { $0.offset != index }.compactMap { $0.element.catalogFoodID })
        guard candidateID != beforeFood.catalogFoodID, !used.contains(candidateID),
              let candidate = admitted.first(where: { $0.id == candidateID }), let evidence = candidate.nutritionEvidence,
              evidence.allowedMeals.contains(spec.occasion), ClientNutritionGenerator.matches(candidate, role: role) else {
            throw ClientSmartPlanEditError.noCompatibleAlternative
        }
        let before = ClientNutritionTotals(calories: beforeFood.calories, protein: beforeFood.protein, carbs: beforeFood.carbs, fat: beforeFood.fat)
        let fitted = ClientNutritionPortionSolver.fit([
            .init(item: candidate, role: role, bounds: evidence.portion, grams: evidence.portion.minimumGrams)
        ], target: before, objective: policy.objective)
        guard let portion = fitted.first, similarEnough(before, .food(candidate, grams: portion.grams), role: role, policy: policy) else {
            throw ClientSmartPlanEditError.portionBoundsPreventMatch
        }
        var edited = baseline
        edited.days[day].meals[meal].foods[index] = food(candidate, grams: portion.grams, slotID: beforeFood.id)
        var result = ClientEditedNutritionPlanValidator().prepare(original: baseline, edited: edited, context: context, catalog: catalog)
        if !result.canSave && policy.allowMealRebalance {
            let byID = Dictionary(uniqueKeysWithValues: admitted.map { ($0.id, $0) })
            var portions: [ClientNutritionSolvedPortion] = []
            for (offset, item) in edited.days[day].meals[meal].foods.enumerated() {
                guard let id = item.catalogFoodID, let row = byID[id], let e = row.nutritionEvidence,
                      let foodRole = spec.foodRoles.first(where: { $0.foodID == item.id })?.role else { throw ClientSmartPlanEditError.invalidEdit }
                let bounds: ClientNutritionPortionBounds
                if offset == index {
                    // Keep the offered replacement quantity fixed; ONLY disclosed sibling-food steps may change.
                    bounds = .init(minimumGrams: item.quantityGrams, maximumGrams: item.quantityGrams, stepGrams: e.portion.stepGrams)
                }
                else {
                    let delta = e.portion.stepGrams * Double(policy.maximumOtherFoodSteps)
                    bounds = .init(minimumGrams: max(e.portion.minimumGrams, item.quantityGrams - delta),
                        maximumGrams: min(e.portion.maximumGrams, item.quantityGrams + delta), stepGrams: e.portion.stepGrams)
                }
                portions.append(.init(item: row, role: foodRole, bounds: bounds, grams: item.quantityGrams))
            }
            let targetMeal = ClientNutritionTotals(calories: energy.calories * spec.energyShare,
                protein: energy.protein * spec.proteinShare, carbs: energy.carbs * spec.energyShare, fat: energy.fat * spec.energyShare)
            let rebalanced = ClientNutritionPortionSolver.fit(portions, target: targetMeal)
            guard rebalanced.count == beforeMeal.foods.count else { throw ClientSmartPlanEditError.invalidEdit }
            edited.days[day].meals[meal].foods = zip(beforeMeal.foods, rebalanced).map {
                food($0.1.item, grams: $0.1.grams, slotID: $0.0.id)
            }
            result = ClientEditedNutritionPlanValidator().prepare(original: baseline, edited: edited, context: context, catalog: catalog)
        }
        guard result.canSave else { throw ClientSmartPlanEditError.invalidEdit }
        let replacement = result.plan.days[day].meals[meal].foods[index]
        let after = ClientNutritionTotals(calories: replacement.calories, protein: replacement.protein, carbs: replacement.carbs, fat: replacement.fat)
        guard similarEnough(before, after, role: role, policy: policy) else { throw ClientSmartPlanEditError.portionBoundsPreventMatch }
        let changes = zip(beforeMeal.foods, result.plan.days[day].meals[meal].foods).compactMap { pair -> ClientNutritionRebalanceChange? in
            guard pair.0.id != beforeFood.id, pair.0.quantityGrams != pair.1.quantityGrams else { return nil }
            return .init(foodID: pair.0.id, name: pair.0.name, beforeGrams: pair.0.quantityGrams, afterGrams: pair.1.quantityGrams)
        }
        guard changes.isEmpty || policy.allowMealRebalance else { throw ClientSmartPlanEditError.rebalanceConsentRequired }
        return Proposal(parentPlanID: original.id, parentSignature: parentSignature,
            catalogFingerprint: ClientNutritionFoodPolicy.fingerprint(admitted), target: target, original: beforeFood,
            replacement: replacement, difference: .init(before: before, after: after),
            score: .calculate(original: before, candidate: after, source: evidence.source, policy: policy),
            additionalChanges: changes, plan: result.plan, policy: policy)
    }

    static func apply(_ proposal: Proposal, to current: ClientPersonalNutritionPlan, catalog: [ClientFoodCatalogItem],
                      context: ClientNutritionCoachContext, acceptRebalance: Bool = false) throws -> ClientPersonalNutritionPlan {
        let anchored = ClientPlanEditing.beginNutrition(current)
        guard current.id == proposal.parentPlanID, let layout = anchored.editProvenance?.nutritionLayout,
              ClientSmartPlanFingerprint.nutrition(current, layout: layout) == proposal.parentSignature,
              let profile = context.profile, let answers = current.creationAnswers,
              let candidateID = proposal.replacement.catalogFoodID else { throw ClientSmartPlanEditError.stalePreview }
        let admitted = ClientNutritionFoodPolicy.admit(catalog, profile: profile, excluded: Set(answers.excludedFoodIDs))
        guard ClientNutritionFoodPolicy.fingerprint(admitted) == proposal.catalogFingerprint else { throw ClientSmartPlanEditError.stalePreview }
        let fresh = try self.proposal(plan: current, target: proposal.target, candidateID: candidateID,
            catalog: catalog, context: context, policy: proposal.policy)
        guard fresh.original == proposal.original, fresh.replacement == proposal.replacement,
              fresh.additionalChanges == proposal.additionalChanges else { throw ClientSmartPlanEditError.stalePreview }
        guard !fresh.requiresRebalanceConsent || acceptRebalance else { throw ClientSmartPlanEditError.rebalanceConsentRequired }
        var confirmedDraft = fresh.plan
        confirmedDraft.updatedAt = Date()
        return confirmedDraft // Local edit only, NEVER a server-save confirmation.
    }

    private static func similarEnough(_ a: ClientNutritionTotals, _ b: ClientNutritionTotals,
                                      role: ClientNutritionFoodRole, policy: ClientNutritionReplacementPolicy) -> Bool {
        let energyDistance = abs(a.calories - b.calories) / max(policy.objective.minimumScales[0], a.calories)
        let axis: Int
        switch role {
        case .protein, .dairyAlternative: axis = 1
        case .carbohydrate, .fruit: axis = 2
        case .fat: axis = 3
        case .vegetable, .mixed: axis = 0
        }
        let roleDistance = abs(a.vector[axis] - b.vector[axis]) / max(policy.objective.minimumScales[axis], a.vector[axis])
        return energyDistance <= policy.maximumItemEnergyDistance && roleDistance <= policy.maximumRoleNutrientDistance
    }
    private static func food(_ item: ClientFoodCatalogItem, grams: Double, slotID: UUID) -> ClientPersonalFood {
        ClientPersonalFood(id: slotID, catalogFoodID: item.id, name: item.name, quantityGrams: grams,
            caloriesPer100g: item.caloriesPer100g, proteinPer100g: item.proteinPer100g,
            carbsPer100g: item.carbsPer100g, fatPer100g: item.fatPer100g,
            gramsPerPiece: item.gramsPerPiece, nutritionEvidence: item.nutritionEvidence)
    }
}
