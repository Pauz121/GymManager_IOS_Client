import Foundation

/// Current-session entry points for future5D. Proposals/apply return LOCAL drafts,never server confirmations.
@MainActor
extension ClientSessionStore {
    private func smartEditingOwner(expectedOwnerID: UUID) throws -> ClientIdentity {
        guard case .active(let identity, _, _) = state else { throw ClientWorkoutGenerationEligibility.deniedUnauthenticated }
        guard identity.authUserID == expectedOwnerID else { throw ClientSmartPlanEditError.accountChanged }
        guard ClientAccessPolicy.canManagePersonalWorkoutPlans(in: identity.mode),
              ClientAccessPolicy.canManagePersonalNutritionPlans(in: identity.mode) else {
            throw ClientWorkoutGenerationEligibility.deniedTrainerManaged
        }
        return identity
    }
    func smartWorkoutAlternatives(plan: ClientPersonalWorkoutPlan, sessionID: UUID, exerciseID: UUID,
                                  catalog: [ClientExerciseCatalogItem], expectedOwnerID: UUID) throws -> [ClientWorkoutSmartReplacement.Proposal] {
        let owner = try smartEditingOwner(expectedOwnerID: expectedOwnerID)
        return try ClientWorkoutSmartReplacement.alternatives(plan: plan, sessionID: sessionID, exerciseID: exerciseID,
            catalog: catalog, context: .init(mode: owner.mode))
    }
    func applySmartWorkoutReplacement(_ proposal: ClientWorkoutSmartReplacement.Proposal, to plan: ClientPersonalWorkoutPlan,
                                      catalog: [ClientExerciseCatalogItem], expectedOwnerID: UUID) throws -> ClientPersonalWorkoutPlan {
        let owner = try smartEditingOwner(expectedOwnerID: expectedOwnerID)
        return try ClientWorkoutSmartReplacement.apply(proposal, to: plan, catalog: catalog, context: .init(mode: owner.mode))
    }
    func smartNutritionAlternatives(plan: ClientPersonalNutritionPlan, target: ClientNutritionSmartReplacement.Target,
                                    catalog: [ClientFoodCatalogItem], policy: ClientNutritionReplacementPolicy = .init(),
                                    expectedOwnerID: UUID) throws -> [ClientNutritionSmartReplacement.Proposal] {
        let owner = try smartEditingOwner(expectedOwnerID: expectedOwnerID)
        return try ClientNutritionSmartReplacement.alternatives(plan: plan, target: target, catalog: catalog,
            context: .init(mode: owner.mode, profile: plan.creationAnswers?.coachProfile), policy: policy)
    }
    func smartNutritionProposal(plan: ClientPersonalNutritionPlan, target: ClientNutritionSmartReplacement.Target, candidateID: UUID,
                                catalog: [ClientFoodCatalogItem], policy: ClientNutritionReplacementPolicy = .init(),
                                expectedOwnerID: UUID) throws -> ClientNutritionSmartReplacement.Proposal {
        let owner = try smartEditingOwner(expectedOwnerID: expectedOwnerID)
        return try ClientNutritionSmartReplacement.proposal(plan: plan, target: target, candidateID: candidateID, catalog: catalog,
            context: .init(mode: owner.mode, profile: plan.creationAnswers?.coachProfile), policy: policy)
    }
    func applySmartNutritionReplacement(_ proposal: ClientNutritionSmartReplacement.Proposal, to plan: ClientPersonalNutritionPlan,
                                        catalog: [ClientFoodCatalogItem], acceptRebalance: Bool = false,
                                        expectedOwnerID: UUID) throws -> ClientPersonalNutritionPlan {
        let owner = try smartEditingOwner(expectedOwnerID: expectedOwnerID)
        return try ClientNutritionSmartReplacement.apply(proposal, to: plan, catalog: catalog,
            context: .init(mode: owner.mode, profile: plan.creationAnswers?.coachProfile), acceptRebalance: acceptRebalance)
    }
}
