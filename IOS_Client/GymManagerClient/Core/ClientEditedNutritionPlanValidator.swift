import Foundation

struct ClientEditedNutritionPlanValidator {
    struct Result {
        let plan: ClientPersonalNutritionPlan
        let issues: Set<ClientNutritionPlanIssue>
        var canSave: Bool { issues.isEmpty }
    }
    func inspect(_ plan: ClientPersonalNutritionPlan, context: ClientNutritionCoachContext,
                 catalog: [ClientFoodCatalogItem]) -> Result {
        guard Self.hasValidContract(plan), let layout = plan.editProvenance?.nutritionLayout else {
            return Result(plan: plan, issues: [.metadata,.meals])
        }
        let issues = ClientNutritionPlanValidator.inspectCore(plan, context: context, catalog: catalog, editingLayout: layout)
        return Result(plan: plan, issues: issues)
    }
    static func hasValidContract(_ plan: ClientPersonalNutritionPlan) -> Bool {
        guard let provenance = plan.editProvenance, let layout = provenance.nutritionLayout,
              provenance.editorVersion == ClientPlanEditProvenance.version,
              provenance.generatorVersion == plan.generationMetadata?.generatorVersion,
              provenance.generationMetadataSignature == ClientSmartPlanFingerprint.nutritionOrigin(plan),
              !provenance.originalPlanSignature.isEmpty, (0...10_000).contains(provenance.revision),
              provenance.currentPlanSignature == ClientSmartPlanFingerprint.nutrition(plan, layout: layout),
              layout.valid(for: plan) else { return false }
        if provenance.revision == 0 && provenance.originalPlanSignature != provenance.currentPlanSignature { return false }
        return true
    }
    /// Explicit candidate/edit transaction. Original generator/profile/targets stay immutable.
    func prepare(original: ClientPersonalNutritionPlan, edited: ClientPersonalNutritionPlan,
                 layout: ClientNutritionEditingLayout? = nil, context: ClientNutritionCoachContext,
                 catalog: [ClientFoodCatalogItem]) -> Result {
        guard ClientNutritionPlanValidator.inspect(original, context: context, catalog: catalog).isEmpty,
              original.id == edited.id, original.source == edited.source,
              original.generationMetadata == edited.generationMetadata, original.target == edited.target,
              original.creationAnswers == edited.creationAnswers else { return Result(plan: edited, issues: [.metadata]) }
        let anchored = ClientPlanEditing.beginNutrition(original)
        guard var provenance = anchored.editProvenance, let chosenLayout = layout ?? provenance.nutritionLayout,
              let signature = ClientSmartPlanFingerprint.nutrition(edited, layout: chosenLayout),
              provenance.revision < 10_000 else { return Result(plan: edited, issues: [.metadata]) }
        if signature != provenance.currentPlanSignature { provenance.revision += 1 }
        provenance.currentPlanSignature = signature
        provenance.nutritionLayout = chosenLayout
        var draft = edited
        draft.editProvenance = provenance
        return inspect(draft, context: context, catalog: catalog)
    }
}
