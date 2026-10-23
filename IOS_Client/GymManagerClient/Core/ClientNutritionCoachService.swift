import Foundation

/// Native UI integration is intentionally deferred to5D. No remote write during generation.
@MainActor
extension ClientSessionStore {
    func generatePersonalNutrition(answers: ClientNutritionCreationAnswers, catalog: [ClientFoodCatalogItem],
                                   variation: Int = 0) throws -> ClientPersonalNutritionPlan {
        guard case .active(let identity, _, _) = state else { throw ClientNutritionGenerationEligibility.deniedUnauthenticated }
        return try ClientNutritionGenerator.generate(
            context: .init(mode: identity.mode, profile: answers.coachProfile), answers: answers, catalog: catalog, variation: variation)
    }
}
