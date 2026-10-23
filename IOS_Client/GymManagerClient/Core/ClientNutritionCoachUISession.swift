import Foundation

@MainActor
extension ClientSessionStore {
    func nutritionCoachOwner(expectedOwnerID: UUID?) throws -> ClientIdentity {
        guard case .active(let identity, _, _) = state else { throw ClientNutritionGenerationEligibility.deniedUnauthenticated }
        try ClientNutritionCoachOwnership.check(actualOwnerID: identity.authUserID, expectedOwnerID: expectedOwnerID, mode: identity.mode)
        return identity
    }
    func generateNutritionCoach(inputs: ClientNutritionCoachInputs, catalog: [ClientFoodCatalogItem],
                                variation: Int, expectedOwnerID: UUID?) async throws -> ClientPersonalNutritionPlan {
        let owner = try nutritionCoachOwner(expectedOwnerID: expectedOwnerID)
        let reason = inputs.eligibility(mode: owner.mode)
        guard reason == .allowed else { throw reason }
        let context = ClientNutritionCoachContext(mode: owner.mode, profile: inputs.answers.coachProfile)
        let result = try await Task.detached(priority: .userInitiated) {
            try ClientNutritionGenerator.generate(context: context, answers: inputs.answers, catalog: catalog, variation: variation)
        }.value
        try Task.checkCancellation()
        _ = try nutritionCoachOwner(expectedOwnerID: expectedOwnerID)
        return result
    }
    func saveNutritionCoachPlan(_ plan: ClientPersonalNutritionPlan, catalog: [ClientFoodCatalogItem],
                                expectedOwnerID: UUID?) async -> ClientNutritionCoachSaveState {
        do {
            let owner = try nutritionCoachOwner(expectedOwnerID: expectedOwnerID)
            if plan.generationMetadata != nil || plan.creationAnswers?.coachProfile != nil {
                let issues = ClientNutritionPlanValidator.inspect(plan,
                    context: .init(mode: owner.mode, profile: plan.creationAnswers?.coachProfile), catalog: catalog)
                guard issues.isEmpty else { return .failure(ClientNutritionCoachFeedback.issues(issues).joined(separator: "\n")) }
            } else if let error = ClientNutritionDraft.validationMessage(plan) { return .failure(error) }
            notice = nil
            let saved = await savePersonalNutritionPlanConfirmed(plan)
            _ = try nutritionCoachOwner(expectedOwnerID: expectedOwnerID)
            guard saved else { return .failure(notice ?? "Salvataggio non confermato. La bozza è ancora qui.") }
            guard case .active(_, _, let source) = state else { throw ClientNutritionGenerationEligibility.deniedUnauthenticated }
            return .confirmed(demo: source == .demo)
        } catch { return .failure(error.localizedDescription) }
    }
    func prepareNutritionAlternatives(plan: ClientPersonalNutritionPlan, target: ClientNutritionSmartReplacement.Target,
                                      catalog: [ClientFoodCatalogItem], allowRebalance: Bool, expectedOwnerID: UUID?) async throws -> [ClientNutritionSmartReplacement.Proposal] {
        let owner = try nutritionCoachOwner(expectedOwnerID: expectedOwnerID)
        let context = ClientNutritionCoachContext(mode: owner.mode, profile: plan.creationAnswers?.coachProfile)
        var policy = ClientNutritionReplacementPolicy(); policy.allowMealRebalance = allowRebalance
        let frozenPolicy = policy
        let result = try await Task.detached(priority: .userInitiated) {
            try ClientNutritionSmartReplacement.alternatives(plan: plan, target: target, catalog: catalog, context: context, policy: frozenPolicy)
        }.value
        try Task.checkCancellation()
        _ = try nutritionCoachOwner(expectedOwnerID: expectedOwnerID)
        return result
    }
    func prepareNutritionReplacement(plan: ClientPersonalNutritionPlan, target: ClientNutritionSmartReplacement.Target, candidateID: UUID,
                                     catalog: [ClientFoodCatalogItem], allowRebalance: Bool, expectedOwnerID: UUID?) async throws -> ClientNutritionSmartReplacement.Proposal {
        let owner = try nutritionCoachOwner(expectedOwnerID: expectedOwnerID)
        let context = ClientNutritionCoachContext(mode: owner.mode, profile: plan.creationAnswers?.coachProfile)
        var policy = ClientNutritionReplacementPolicy(); policy.allowMealRebalance = allowRebalance
        let frozenPolicy = policy
        let result = try await Task.detached(priority: .userInitiated) {
            try ClientNutritionSmartReplacement.proposal(plan: plan, target: target, candidateID: candidateID, catalog: catalog, context: context, policy: frozenPolicy)
        }.value
        try Task.checkCancellation()
        _ = try nutritionCoachOwner(expectedOwnerID: expectedOwnerID)
        return result
    }
}
