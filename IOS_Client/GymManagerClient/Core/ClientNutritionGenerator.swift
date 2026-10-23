import Foundation

/// Evolution of the existing rule-based generator, never an LLM/clinical diet or parallel plan.
enum ClientNutritionGenerator {
    /// Compatibility for the existing estimate-only UI. Generation requires explicit owner context.
    static func target(for answers: ClientNutritionCreationAnswers) throws -> ClientNutritionTarget {
        if let profile = answers.coachProfile {
            let eligibility = ClientNutritionCoachPolicy.evaluate(.init(mode: .standalone, profile: profile), answers: answers)
            guard eligibility == .allowed else { throw eligibility }
            return try ClientNutritionCoachEnergy.calculate(profile: profile, phase: answers.phase).target
        }
        guard answers.healthyAdultConfirmed, !answers.hasAllergiesOrMedicalNeeds else {
            throw ClientNutritionGenerationEligibility.missingRequiredProfile
        }
        guard let age = answers.age, let sex = answers.biologicalSex,
              let kg = answers.weightKg, let cm = answers.heightCm else {
            throw ClientNutritionGenerationEligibility.missingRequiredProfile
        }
        let resting = try ClientNutritionCoachEnergy.rmr(age: age, sex: sex, weightKg: kg, heightCm: cm)
        try ClientNutritionCoachEnergy.checkApplicability(weightKg: kg, heightCm: cm, phase: answers.phase)
        // Preserve only the explicitly selected legacy factor. NEVER fabricate occupation,
        // workout frequency or health declarations to adapt old answers into coach evidence.
        // Conservative general-product protein estimate; NOT an exercising-user target/plan.
        return try ClientNutritionCoachEnergy.allocate(resting: resting, maintenance: resting * answers.activity.coefficient,
                                                       weightKg: kg, phase: answers.phase, proteinRate: 1.0)
    }

    /// The old UI cannot assert owner/health/catalog review.5D must route through the session adapter.
    static func generate(answers: ClientNutritionCreationAnswers, catalog: [ClientFoodCatalogItem],
                         variation: Int = 0) throws -> ClientPersonalNutritionPlan {
        throw ClientNutritionGenerationEligibility.missingRequiredProfile
    }

    static func generate(context: ClientNutritionCoachContext, answers: ClientNutritionCreationAnswers,
                         catalog: [ClientFoodCatalogItem], variation: Int = 0, now: Date = Date()) throws -> ClientPersonalNutritionPlan {
        let eligibility = ClientNutritionCoachPolicy.evaluate(context, answers: answers)
        guard eligibility == .allowed, let profile = context.profile else { throw eligibility }
        guard variation >= 0 && variation <= 1000 else { throw ClientNutritionGenerationEligibility.invalidPlan }
        let energy = try ClientNutritionCoachEnergy.calculate(profile: profile, phase: answers.phase)
        let admitted = ClientNutritionFoodPolicy.admit(catalog, profile: profile, excluded: Set(answers.excludedFoodIDs))
        guard !admitted.isEmpty else { throw ClientNutritionGenerationEligibility.insufficientFoodData }
        let shares = ClientNutritionCoachRules.mealShares(answers.mealCount)
        let mealTargets = shares.map { ClientNutritionPortionSolver.mealTarget(energy.target, share: $0, mealCount: answers.mealCount) }
        let weekdays = answers.dayCount == 7 ? Array(1...7) : [profile.referenceWeekday]
        for attempt in 0..<6 {
            var storedAnswers = answers
            storedAnswers.coachProfile = profile
            var plan = ClientNutritionDraft.newPlan(answers: storedAnswers, now: now)
            plan.source = .guided; plan.target = energy.target
            plan.days = weekdays.map { day in
                ClientPersonalNutritionDay(id: UUID(), weekday: day, name: ClientNutritionDraft.weekdays[day - 1],
                    meals: ClientNutritionDraft.mealNames(count: answers.mealCount).map {
                        ClientPersonalMeal(id: UUID(), name: $0, foods: [])
                    })
            }
            for dayIndex in plan.days.indices {
                var portionsByMeal: [[ClientNutritionSolvedPortion]] = []
                var dailyUse: [UUID: Int] = [:]
                for mealIndex in shares.indices {
                    var selected = Set<UUID>()
                    var portions: [ClientNutritionSolvedPortion] = []
                    for (roleIndex, role) in roles(index: mealIndex, count: answers.mealCount).enumerated() {
                        let candidates = admitted.filter {
                            matches($0, role: role) && !selected.contains($0.id) &&
                                $0.nutritionEvidence?.allowedMeals.contains(occasion(index: mealIndex, count: answers.mealCount)) == true
                        }
                        let priorities = Set(candidates.compactMap { $0.nutritionEvidence?.source.priority }).sorted()
                        guard !priorities.isEmpty else {
                            if !profile.allergies.isEmpty || !profile.intolerances.isEmpty {
                                throw ClientNutritionGenerationEligibility.allergyConflict
                            }
                            throw ClientNutritionGenerationEligibility.incompatiblePreferences
                        }
                        // Prefer CREA, then bounded fallback to USDA/OFF if the higher-priority fit fails.
                        let priority = priorities[min(attempt / 2, priorities.count - 1)]
                        let sourcePreferred = candidates.filter { $0.nutritionEvidence?.source.priority == priority }
                        let leastUsed = sourcePreferred.map { dailyUse[$0.id, default: 0] }.min() ?? 0
                        let preferred = sourcePreferred.filter { dailyUse[$0.id, default: 0] == leastUsed }
                        let offset = (variation * 13 + attempt * 7 + dayIndex * 5 + mealIndex * 3 + roleIndex) % preferred.count
                        let item = preferred[offset]
                        guard let evidence = item.nutritionEvidence else { throw ClientNutritionGenerationEligibility.insufficientFoodData }
                        selected.insert(item.id)
                        dailyUse[item.id, default: 0] += 1
                        portions.append(ClientNutritionSolvedPortion(item: item, role: role, bounds: evidence.portion,
                            grams: evidence.portion.minimumGrams))
                    }
                    portionsByMeal.append(ClientNutritionPortionSolver.fit(portions, target: mealTargets[mealIndex]))
                }
                portionsByMeal = ClientNutritionPortionSolver.refineDay(portionsByMeal, targets: mealTargets, daily: energy.target)
                for mealIndex in shares.indices {
                    plan.days[dayIndex].meals[mealIndex].foods = portionsByMeal[mealIndex].map { portion in
                        // Already quantized in GRAMS, whole pieces checked by admission/validator.
                        ClientPersonalFood(id: UUID(), catalogFoodID: portion.item.id, name: portion.item.name,
                            quantityGrams: portion.grams, caloriesPer100g: portion.item.caloriesPer100g,
                            proteinPer100g: portion.item.proteinPer100g, carbsPer100g: portion.item.carbsPer100g,
                            fatPer100g: portion.item.fatPer100g, gramsPerPiece: portion.item.gramsPerPiece,
                            nutritionEvidence: portion.item.nutritionEvidence)
                    }
                }
            }
            plan.generationMetadata = ClientNutritionGenerationMetadata(
                generatorVersion: ClientNutritionCoachRules.version, profile: profile, energy: energy,
                catalogFingerprint: ClientNutritionFoodPolicy.fingerprint(admitted), variation: variation,
                dailyEnergyTolerance: ClientNutritionCoachRules.dailyEnergyTolerance,
                dailyMacroTolerance: ClientNutritionCoachRules.dailyMacroTolerance,
                mealEnergyTolerance: ClientNutritionCoachRules.mealEnergyTolerance,
                mealProteinTolerance: ClientNutritionCoachRules.mealProteinTolerance,
                rationale: explanations(energy: energy, profile: profile), structuralSignature: "")
            let structuralSignature = ClientNutritionPlanValidator.signature(plan)
            plan.generationMetadata?.structuralSignature = structuralSignature
            if ClientNutritionPlanValidator.inspect(plan, context: context, catalog: catalog).isEmpty {
                return ClientPlanEditing.beginNutrition(plan)
            }
        }
        throw ClientNutritionGenerationEligibility.fitFailed
    }

    static func isSnack(index: Int, count: Int) -> Bool {
        ClientNutritionDraft.mealNames(count: count)[index].hasPrefix("Spuntino") ||
            ClientNutritionDraft.mealNames(count: count)[index] == "Merenda"
    }

    static func roles(index: Int, count: Int) -> [ClientNutritionFoodRole] {
        if isSnack(index: index, count: count) { return [.protein, .fruit, .fat] }
        return [.protein, .carbohydrate, index == 0 ? .fruit : .vegetable, .fat]
    }

    static func occasion(index: Int, count: Int) -> ClientNutritionMealOccasion {
        isSnack(index: index, count: count) ? .snack : index == 0 ? .breakfast : .main
    }

    static func matches(_ item: ClientFoodCatalogItem, role: ClientNutritionFoodRole) -> Bool {
        guard let e = item.nutritionEvidence else { return false }
        return e.roles.contains(role) || (role == .protein && e.roles.contains(.dairyAlternative))
    }

    static func explanations(energy: ClientNutritionEnergyCalculation, profile: ClientNutritionCoachProfile) -> [String] {
        [
            "Il mantenimento è stimato da età, peso, altezza, sesso richiesto dalla formula e attività quotidiana dichiarata: non è una misurazione.",
            energy.goal == .cut ? "Riduzione moderata del10% rispetto al mantenimento stimato." :
                energy.goal == .bulk ? "Incremento contenuto del5% rispetto al mantenimento stimato." : "Obiettivo vicino al mantenimento stimato.",
            profile.activity?.exerciseDaysPerWeek == 0 ?
                "Proteine distribuite nei pasti; target generale di prodotto, distinto dal riferimento minimo di popolazione." :
                "Target proteico nel range sportivo configurato; non rappresenta un valore individuale ottimale.",
            "Grassi al30% del target; carboidrati dall'energia restante. I pasti usano solo dati alimentari e compatibilità verificati.",
            "Porzioni vincolate a limiti verificati e arrotondate prima della validazione. Nessuna garanzia di adeguatezza clinica o micronutrizionale."
        ]
    }
}
