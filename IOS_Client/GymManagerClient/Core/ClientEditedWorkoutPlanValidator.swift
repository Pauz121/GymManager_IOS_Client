import Foundation

struct ClientWorkoutCoachEditingContext {
    let answers: ClientWorkoutQuestionnaireAnswers
    let catalog: [ClientExerciseCatalogItem]
    var candidates: [ClientWorkoutCatalogPolicy.Candidate] {
        (try? ClientWorkoutCatalogPolicy.admit(catalog, answers: answers, level: ClientTrainingProfile(answers: answers).experience).candidates) ?? []
    }
    func alternatives(to exercise: ClientPersonalExercise, usedIDs: Set<UUID>) -> [ClientWorkoutCatalogPolicy.Candidate] {
        ClientWorkoutReplacementRanking.ranked(candidates: candidates, original: exercise,
            usedIDs: usedIDs, priorities: answers.priorityMuscles).map(\.candidate)
    }
    static func exercise(_ candidate: ClientWorkoutCatalogPolicy.Candidate, replacing original: ClientPersonalExercise? = nil) -> ClientPersonalExercise {
        let item = candidate.item
        return ClientPersonalExercise(id: UUID(), catalogExerciseID: item.id, catalogSourceKey: item.sourceKey,
            name: item.name, muscleGroup: item.primaryMuscles.first?.displayName ?? "",
            sets: original?.sets ?? 2, repetitions: original?.repetitions ?? "8–10",
            restSeconds: original?.restSeconds ?? (candidate.review.kind == .compound ? 150 : 75), loadKg: nil,
            effortTarget: original?.effortTarget ?? "RIR 2", notes: original?.notes ?? "",
            videoURL: item.videoURL, primaryMuscles: item.primaryMuscles, secondaryMuscles: item.secondaryMuscles,
            movementPattern: candidate.review.pattern, compatibleEquipment: item.compatibleEquipment,
            exerciseKind: candidate.review.kind, animationKey: item.animationKey, technique: item.instructions,
            difficultyLevel: candidate.level, catalogMuscles: item.catalogMuscles)
    }
}

/// Editing changes user-facing names/calendar and derived estimates, NEVER original evidence/provenance.
/// All constraint failures are HARD INVALID here. No override policy exists in the View.
struct ClientEditedWorkoutPlanValidator {
    struct Result {
        let plan: ClientPersonalWorkoutPlan
        let issues: [ClientWorkoutValidationIssue]
        var canSave: Bool { issues.isEmpty }
        var messages: [String] { issues.map(ClientWorkoutCoachFeedback.editIssue) }
    }
    func inspect(_ original: ClientPersonalWorkoutPlan, catalog: [ClientExerciseCatalogItem]) -> Result {
        guard let answers = original.generationAnswers, let metadata = original.generationMetadata,
              metadata.generatorVersion == ClientWorkoutCoachRules.version else {
            return Result(plan: original, issues: [.metadata])
        }
        var plan = original
        for index in plan.sessions.indices {
            plan.sessions[index].durationMinutes = ClientWorkoutCoachRules.minutes(plan.sessions[index].exercises)
        }
        plan.generationMetadata = ClientWorkoutGenerationMetadata(generatorVersion: metadata.generatorVersion,
            effectiveExperience: metadata.effectiveExperience, strategy: metadata.strategy, rationale: metadata.rationale,
            estimatedSessionMinutes: plan.sessions.map { ClientWorkoutCoachRules.minutes($0.exercises) },
            catalogFingerprint: metadata.catalogFingerprint)
        let report = ClientWorkoutPlanValidator().inspect(plan: plan, answers: answers, catalog: catalog,
                                                         allowEditedPresentation: true)
        plan.validation = report.summary
        guard let marked = ClientPlanEditing.refreshWorkout(plan) else {
            plan.validation = nil
            return Result(plan: plan, issues: ClientWorkoutValidationIssue.allCases.filter { report.issues.contains($0) || $0 == .metadata })
        }
        plan = marked
        return Result(plan: plan, issues: report.issues)
    }
}

@MainActor
extension ClientSessionStore {
    /// Uses current session at invocation and the EXISTING repository's fresh session/profile/link preflight.
    /// Repository/RLS remain authoritative; a cached UI mode is not an authorization boundary.
    func saveWorkoutCoachPlan(_ plan: ClientPersonalWorkoutPlan, catalog: [ClientExerciseCatalogItem], expectedOwnerID: UUID?) async -> ClientWorkoutCoachSaveState {
        guard case .active(let owner, _, let source) = state else {
            return .failure(ClientWorkoutGenerationEligibility.deniedUnauthenticated.errorDescription ?? "")
        }
        guard expectedOwnerID == owner.authUserID else {
            return .failure("L'account è cambiato: riapri la creazione dalla tua libreria.")
        }
        guard ClientAccessPolicy.canManagePersonalWorkoutPlans(in: owner.mode) else {
            return .failure(ClientWorkoutGenerationEligibility.deniedTrainerManaged.errorDescription ?? "")
        }
        var checked = plan
        if plan.generationMetadata != nil || (plan.source == .guided && plan.generationAnswers?.experienceEvidence != nil) {
            let validation = ClientEditedWorkoutPlanValidator().inspect(plan, catalog: catalog)
            guard validation.canSave else { return .failure(validation.messages.joined(separator: " ")) }
            checked = validation.plan
        }
        notice = nil // A previous unrelated notice is not evidence about this save attempt.
        let confirmed = await savePersonalWorkoutPlanConfirmed(checked)
        guard case .active(let current, _, _) = state, current.authUserID == owner.authUserID else {
            return .failure("L'account è cambiato. Nessuna conferma di salvataggio per questa sessione.")
        }
        guard ClientAccessPolicy.canManagePersonalWorkoutPlans(in: current.mode) else {
            return .failure(ClientWorkoutGenerationEligibility.deniedTrainerManaged.errorDescription ?? "")
        }
        return confirmed ? .confirmed(demo: source != .live)
            : .failure(notice ?? "Il database non ha confermato. L'eventuale copia locale non è una conferma del server.")
    }
}
