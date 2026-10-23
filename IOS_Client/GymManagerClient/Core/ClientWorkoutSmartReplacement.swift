import Foundation

struct ClientWorkoutReplacementScore: Equatable, Sendable {
    let difficultyDistance: Int
    let equipmentSetupChanges: Int
    let priorityShortfall: Int
    let volumeDistance: Double
    /// Lexicographic order: no uncalibrated similarity percentage.
    func precedes(_ other: Self) -> Bool {
        if difficultyDistance != other.difficultyDistance { return difficultyDistance < other.difficultyDistance }
        if equipmentSetupChanges != other.equipmentSetupChanges { return equipmentSetupChanges < other.equipmentSetupChanges }
        if priorityShortfall != other.priorityShortfall { return priorityShortfall < other.priorityShortfall }
        return volumeDistance < other.volumeDistance
    }
}

enum ClientWorkoutReplacementRanking {
    struct Alternative: Sendable {
        let candidate: ClientWorkoutCatalogPolicy.Candidate
        let score: ClientWorkoutReplacementScore
    }
    static func ranked(candidates: [ClientWorkoutCatalogPolicy.Candidate], original: ClientPersonalExercise,
                       usedIDs: Set<UUID>, priorities: Set<ClientMuscleRegion>) -> [Alternative] {
        guard let originalCandidate = candidates.first(where: { $0.item.id == original.catalogExerciseID }),
              original.difficultyLevel == originalCandidate.level,
              original.movementPattern == originalCandidate.review.pattern,
              original.exerciseKind == originalCandidate.review.kind,
              Set(original.primaryMuscles ?? []) == originalCandidate.primary else { return [] }
        let levels: [ClientTrainingExperience] = [.beginner,.intermediate,.advanced]
        let ceiling = levels.firstIndex(of: originalCandidate.level) ?? 0
        let before = ClientWorkoutVolumeMetrics(exercises: [original])
        return candidates.filter {
            $0.item.id != original.catalogExerciseID && !usedIDs.contains($0.item.id) &&
                $0.primary == Set(original.primaryMuscles ?? []) &&
                $0.review.pattern == original.movementPattern && $0.review.kind == original.exerciseKind &&
                (levels.firstIndex(of: $0.level) ?? 0) <= ceiling
        }.map { candidate in
            let afterExercise = ClientWorkoutCoachEditingContext.exercise(candidate, replacing: original)
            let after = ClientWorkoutVolumeMetrics(exercises: [afterExercise])
            let keys = Set(before.weeklySets.keys).union(after.weeklySets.keys)
            let volumeDistance = keys.sorted { $0.rawValue < $1.rawValue }.reduce(0.0) {
                $0 + abs((before.weeklySets[$1] ?? 0) - (after.weeklySets[$1] ?? 0))
            }
            let relevant = candidate.primary.union(candidate.item.secondaryMuscles).intersection(priorities)
            return Alternative(candidate: candidate, score: .init(
                difficultyDistance: ceiling - (levels.firstIndex(of: candidate.level) ?? 0),
                equipmentSetupChanges: originalCandidate.review.required.symmetricDifference(candidate.review.required).count,
                priorityShortfall: priorities.subtracting(relevant).count, volumeDistance: volumeDistance))
        }.sorted {
            if $0.score != $1.score { return $0.score.precedes($1.score) }
            return $0.candidate.item.id.uuidString < $1.candidate.item.id.uuidString
        }
    }
}

enum ClientWorkoutSmartReplacement {
    struct Proposal: Sendable {
        let parentPlanID: UUID
        let parentSignature: String
        let catalogFingerprint: String
        let sessionID: UUID
        let exerciseID: UUID
        let original: ClientPersonalExercise
        let replacementCatalogID: UUID
        let score: ClientWorkoutReplacementScore
        let plan: ClientPersonalWorkoutPlan
        let beforeVolume: ClientWorkoutVolumeMetrics
        let afterVolume: ClientWorkoutVolumeMetrics
    }
    static func alternatives(plan original: ClientPersonalWorkoutPlan, sessionID: UUID, exerciseID: UUID,
                             catalog: [ClientExerciseCatalogItem], context: ClientWorkoutGenerationContext) throws -> [Proposal] {
        guard let mode = context.mode else { throw ClientWorkoutGenerationEligibility.deniedUnauthenticated }
        guard ClientAccessPolicy.canManagePersonalWorkoutPlans(in: mode) else { throw ClientWorkoutGenerationEligibility.deniedTrainerManaged }
        let checked = ClientEditedWorkoutPlanValidator().inspect(ClientPlanEditing.beginWorkout(original), catalog: catalog)
        guard checked.canSave, let answers = original.generationAnswers,
              let parentSignature = ClientSmartPlanFingerprint.workout(original) else { throw ClientSmartPlanEditError.invalidOriginal }
        let plan = checked.plan
        guard let day = plan.sessions.firstIndex(where: { $0.id == sessionID }),
              let index = plan.sessions[day].exercises.firstIndex(where: { $0.id == exerciseID }) else { throw ClientSmartPlanEditError.missingTarget }
        let exercise = plan.sessions[day].exercises[index]
        let editing = ClientWorkoutCoachEditingContext(answers: answers, catalog: catalog)
        let used = Set(plan.sessions[day].exercises.enumerated().filter { $0.offset != index }.compactMap { $0.element.catalogExerciseID })
        let ranked = ClientWorkoutReplacementRanking.ranked(candidates: editing.candidates, original: exercise,
            usedIDs: used, priorities: answers.priorityMuscles)
        let fingerprint = ClientWorkoutPlanValidator.catalogFingerprint(editing.candidates)
        let before = ClientWorkoutVolumeMetrics(exercises: plan.sessions.flatMap(\.exercises))
        let proposals = ranked.compactMap { alternative -> Proposal? in
            var edited = plan
            // Fresh slot UUID avoids showing the old exercise's load history as the new exercise's history.
            edited.sessions[day].exercises[index] = ClientWorkoutCoachEditingContext.exercise(alternative.candidate, replacing: exercise)
            let result = ClientEditedWorkoutPlanValidator().inspect(edited, catalog: catalog)
            guard result.canSave else { return nil }
            return Proposal(parentPlanID: original.id, parentSignature: parentSignature, catalogFingerprint: fingerprint,
                sessionID: sessionID, exerciseID: exerciseID, original: exercise,
                replacementCatalogID: alternative.candidate.item.id, score: alternative.score, plan: result.plan,
                beforeVolume: before, afterVolume: ClientWorkoutVolumeMetrics(exercises: result.plan.sessions.flatMap(\.exercises)))
        }
        guard !proposals.isEmpty else { throw ClientSmartPlanEditError.noCompatibleAlternative }
        return proposals
    }
    static func apply(_ proposal: Proposal, to current: ClientPersonalWorkoutPlan, catalog: [ClientExerciseCatalogItem],
                      context: ClientWorkoutGenerationContext) throws -> ClientPersonalWorkoutPlan {
        guard current.id == proposal.parentPlanID, ClientSmartPlanFingerprint.workout(current) == proposal.parentSignature,
              let answers = current.generationAnswers else { throw ClientSmartPlanEditError.stalePreview }
        let candidates = ClientWorkoutCoachEditingContext(answers: answers, catalog: catalog).candidates
        guard ClientWorkoutPlanValidator.catalogFingerprint(candidates) == proposal.catalogFingerprint,
              current.sessions.first(where: { $0.id == proposal.sessionID })?.exercises.first(where: { $0.id == proposal.exerciseID }) == proposal.original else {
            throw ClientSmartPlanEditError.stalePreview
        }
        // Rebuild from current trusted catalog; never apply a caller-mutated proposed plan.
        let fresh = try alternatives(plan: current, sessionID: proposal.sessionID, exerciseID: proposal.exerciseID, catalog: catalog, context: context)
        guard let accepted = fresh.first(where: { $0.replacementCatalogID == proposal.replacementCatalogID }) else {
            throw ClientSmartPlanEditError.noCompatibleAlternative
        }
        return accepted.plan
    }
}
