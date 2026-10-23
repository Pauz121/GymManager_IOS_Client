import Foundation

struct ClientNutritionGenerationMetadata: Codable, Equatable, Sendable {
    let generatorVersion: String
    let profile: ClientNutritionCoachProfile
    let energy: ClientNutritionEnergyCalculation
    let catalogFingerprint: String
    let variation: Int
    let dailyEnergyTolerance: Double
    let dailyMacroTolerance: Double
    let mealEnergyTolerance: Double
    let mealProteinTolerance: Double
    let rationale: [String]
    var structuralSignature: String
}

enum ClientNutritionPlanIssue: String, Hashable, Sendable {
    case eligibility, metadata, target, catalog, food, preference, portions, days, meals, mealTotals, dayTotals, duplicate
}

enum ClientNutritionPlanValidator {
    static func inspect(_ plan: ClientPersonalNutritionPlan, context: ClientNutritionCoachContext,
                        catalog: [ClientFoodCatalogItem]) -> Set<ClientNutritionPlanIssue> {
        if plan.editProvenance != nil && !ClientEditedNutritionPlanValidator.hasValidContract(plan) {
            return inspectCore(plan, context: context, catalog: catalog).union([.metadata])
        }
        if plan.editProvenance?.hasUserEdits == true {
            return ClientEditedNutritionPlanValidator().inspect(plan, context: context, catalog: catalog).issues
        }
        return inspectCore(plan, context: context, catalog: catalog)
    }
    /// Shared hard rules. Only a validated explicit editing layout changes presentation/distribution checks.
    static func inspectCore(_ plan: ClientPersonalNutritionPlan, context: ClientNutritionCoachContext,
                            catalog: [ClientFoodCatalogItem], editingLayout: ClientNutritionEditingLayout? = nil) -> Set<ClientNutritionPlanIssue> {
        if let editingLayout {
            guard ClientEditedNutritionPlanValidator.hasValidContract(plan),
                  plan.editProvenance?.nutritionLayout == editingLayout else { return [.metadata] }
        }
        var issues = Set<ClientNutritionPlanIssue>()
        guard let answers = plan.creationAnswers, let profile = context.profile else { return [.eligibility] }
        guard ClientNutritionCoachPolicy.evaluate(context, answers: answers) == .allowed else { return [.eligibility] }
        guard let energy = try? ClientNutritionCoachEnergy.calculate(profile: profile, phase: answers.phase) else { return [.target] }
        guard let metadata = plan.generationMetadata else { return [.metadata] }
        let admitted = ClientNutritionFoodPolicy.admit(catalog, profile: profile, excluded: Set(answers.excludedFoodIDs))
        let byID = Dictionary(uniqueKeysWithValues: admitted.map { ($0.id, $0) })
        if answers.coachProfile != profile || metadata.generatorVersion != ClientNutritionCoachRules.version ||
            metadata.profile != profile || metadata.energy != energy || !(0...1000).contains(metadata.variation) ||
            metadata.dailyEnergyTolerance != ClientNutritionCoachRules.dailyEnergyTolerance ||
            metadata.dailyMacroTolerance != ClientNutritionCoachRules.dailyMacroTolerance ||
            metadata.mealEnergyTolerance != ClientNutritionCoachRules.mealEnergyTolerance ||
            metadata.mealProteinTolerance != ClientNutritionCoachRules.mealProteinTolerance ||
            metadata.rationale != ClientNutritionGenerator.explanations(energy: energy, profile: profile) ||
            (editingLayout == nil && metadata.structuralSignature != signature(plan)) { issues.insert(.metadata) }
        if metadata.catalogFingerprint != ClientNutritionFoodPolicy.fingerprint(admitted) { issues.insert(.catalog) }
        if plan.source != .guided || plan.target != energy.target || !ClientNutritionCoachEnergy.validMacros(energy.target) {
            issues.insert(.target)
        }
        if ClientNutritionDraft.validationMessage(plan) != nil { issues.insert(.food) }
        let weekdays = answers.dayCount == 7 ? Array(1...7) : [profile.referenceWeekday]
        let actualWeekdays = editingLayout == nil ? plan.days.map(\.weekday) : plan.days.map(\.weekday).sorted()
        if actualWeekdays != weekdays || Set(plan.days.map(\.id)).count != plan.days.count { issues.insert(.days) }
        if let editingLayout, !editingLayout.valid(for: plan) { return issues.union([.meals]) }
        if plan.title.count > 160 { issues.insert(.metadata) }
        let shares = ClientNutritionCoachRules.mealShares(answers.mealCount)
        var usedInstances = Set<UUID>()
        usedInstances.insert(plan.id)
        for day in plan.days {
            if !usedInstances.insert(day.id).inserted { issues.insert(.duplicate) }
            if editingLayout == nil && (day.meals.count != answers.mealCount || day.meals.map(\.name) != ClientNutritionDraft.mealNames(count: answers.mealCount)) {
                issues.insert(.meals); continue
            }
            var dayTotals = ClientNutritionTotals()
            for (index, meal) in day.meals.enumerated() {
                if !usedInstances.insert(meal.id).inserted { issues.insert(.duplicate) }
                let spec = editingLayout?.meal(dayID: day.id, mealID: meal.id)
                let occasion = spec?.occasion ?? ClientNutritionGenerator.occasion(index: index, count: answers.mealCount)
                let snack = occasion == .snack
                let expectedRoles = spec == nil ? ClientNutritionGenerator.roles(index: index, count: answers.mealCount) : []
                if spec == nil && meal.foods.count != expectedRoles.count { issues.insert(.meals) }
                if meal.name.count > 80 || day.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || day.name.count > 80 { issues.insert(.meals) }
                var mealIDs = Set<UUID>()
                for (foodIndex, food) in meal.foods.enumerated() {
                    guard usedInstances.insert(food.id).inserted else { issues.insert(.duplicate); continue }
                    guard let id = food.catalogFoodID, let item = byID[id], let e = item.nutritionEvidence else {
                        issues.insert(.catalog); continue
                    }
                    if !mealIDs.insert(id).inserted { issues.insert(.duplicate) }
                    if food.name != item.name || food.caloriesPer100g != item.caloriesPer100g ||
                        food.proteinPer100g != item.proteinPer100g || food.carbsPer100g != item.carbsPer100g ||
                        food.fatPer100g != item.fatPer100g || food.gramsPerPiece != item.gramsPerPiece ||
                        food.nutritionEvidence != e { issues.insert(.food) }
                    if !ClientNutritionFoodPolicy.compatible(item, profile: profile) || answers.excludedFoodIDs.contains(id) {
                        issues.insert(.preference)
                    }
                    if !e.allowedMeals.contains(occasion) {
                        issues.insert(.food)
                    }
                    let role = spec?.foodRoles.first(where: { $0.foodID == food.id })?.role ??
                        (foodIndex < expectedRoles.count ? expectedRoles[foodIndex] : nil)
                    if role == nil || !ClientNutritionGenerator.matches(item, role: role!) {
                        issues.insert(.food)
                    }
                    if !e.portion.contains(food.quantityGrams) { issues.insert(.portions) }
                    if let piece = item.gramsPerPiece,
                       abs(food.quantityGrams / piece - (food.quantityGrams / piece).rounded()) > 0.000001 { issues.insert(.portions) }
                }
                if !(snack ? (1...3) : (editingLayout == nil ? (3...5) : (1...5))).contains(meal.foods.count) { issues.insert(.meals) }
                let totals = ClientNutritionTotals.meal(meal)
                let allocated: ClientNutritionTotals
                if let spec {
                    allocated = ClientNutritionTotals(calories: energy.target.calories * spec.energyShare,
                        protein: energy.target.protein * spec.proteinShare, carbs: energy.target.carbs * spec.energyShare,
                        fat: energy.target.fat * spec.energyShare)
                } else {
                    allocated = ClientNutritionPortionSolver.mealTarget(energy.target, share: shares[index], mealCount: answers.mealCount)
                }
                if !ClientNutritionPortionSolver.relative(totals.calories, allocated.calories, tolerance: ClientNutritionCoachRules.mealEnergyTolerance) ||
                    !ClientNutritionPortionSolver.relative(totals.protein, allocated.protein, tolerance: ClientNutritionCoachRules.mealProteinTolerance) {
                    issues.insert(.mealTotals)
                }
                dayTotals = dayTotals + totals
            }
            if !dailyValid(dayTotals, target: energy.target) { issues.insert(.dayTotals) }
            // Tolerances never silently expand the configured sports protein range.
            let proteinRate = dayTotals.protein / energy.weightKg
            let proteinRange = energy.activityEvidence.exerciseDaysPerWeek > 0 ? (1.4...2.0) : (0.83...1.2)
            if !proteinRange.contains(proteinRate) { issues.insert(.dayTotals) }
        }
        return issues
    }

    static func dailyValid(_ totals: ClientNutritionTotals, target: ClientNutritionTarget) -> Bool {
        let energyOK = ClientNutritionPortionSolver.relative(totals.calories, target.calories, tolerance: ClientNutritionCoachRules.dailyEnergyTolerance)
        let macroOK = zip([totals.protein, totals.carbs, totals.fat], [target.protein, target.carbs, target.fat]).allSatisfy {
            ClientNutritionPortionSolver.relative($0.0, $0.1, tolerance: ClientNutritionCoachRules.dailyMacroTolerance)
        }
        guard totals.calories >= ClientNutritionCoachRules.minimumEnergy, totals.calories <= ClientNutritionCoachRules.maximumEnergy,
              totals.calories > 0 else { return false }
        return energyOK && macroOK && (0.20...0.35).contains(totals.fat * 9 / totals.calories)
    }

    /// Ordered plan fields, sorted enum/UUID sets and length-delimited input header. No timestamps/instance IDs.
    static func signature(_ plan: ClientPersonalNutritionPlan) -> String {
        guard let m = plan.generationMetadata, let a = plan.creationAnswers else { return "" }
        let p = m.profile
        let header = [
            m.generatorVersion, m.catalogFingerprint, String(m.variation), String(p.age ?? -1),
            p.biologicalSex?.rawValue ?? "", String(p.heightCm ?? -1), String(p.weightKg ?? -1),
            p.activity?.dailyActivity.rawValue ?? "", String(p.activity?.exerciseDaysPerWeek ?? -1),
            String(p.activity?.reliableAverageSteps ?? -1), String(p.referenceWeekday),
            String(describing: p.health.healthyAdultAcknowledged), String(describing: p.health.pregnantOrBreastfeeding),
            String(describing: p.health.eatingDisorderRisk), String(describing: p.health.clinicalNutritionRequired),
            p.dietaryPattern.rawValue, p.allergies.map(\.rawValue).sorted().joined(separator: ","),
            p.intolerances.map(\.rawValue).sorted().joined(separator: ","),
            p.excludedFoodIDs.map(\.uuidString).sorted().joined(separator: ","),
            a.phase.rawValue, String(a.mealCount), String(a.dayCount),
            a.excludedFoodIDs.map(\.uuidString).sorted().joined(separator: ",")
        ]
        let days = plan.days.map { day -> String in
            let meals = day.meals.map { meal in
                meal.name + ":" + meal.foods.map { food in
                    (food.catalogFoodID?.uuidString ?? "") + "@" + String(food.quantityGrams)
                }.joined(separator: ";")
            }.joined(separator: "|")
            return String(day.weekday) + ":" + day.name + ":" + meals
        }.joined(separator: "\n")
        return ClientNutritionFoodPolicy.digest(header.map { String($0.utf8.count) + ":" + $0 }.joined() + "\n" + days)
    }
}
