import Foundation

/// Manual creation uses the same personal plan payload as the existing generator/editor.
enum ClientManualWorkoutDraft {
    enum SuggestedSplit: String, CaseIterable {
        case custom = "Personalizzato"
        case fullBody = "Full Body"
        case upperLower = "Upper / Lower"
        case pushPullLegs = "Push / Pull / Legs"
    }

    static func newPlan(now: Date = Date()) -> ClientPersonalWorkoutPlan {
        var plan = ClientPersonalWorkoutPlan(
            id: UUID(), title: "La mia scheda", status: .active, sessions: [],
            createdAt: now, updatedAt: now, source: .manual
        )
        resize(&plan, count: 2)
        return plan
    }

    static func resize(_ plan: inout ClientPersonalWorkoutPlan, count: Int) {
        let count = min(6, max(2, count))
        if plan.sessions.count > count { plan.sessions.removeLast(plan.sessions.count - count) }
        while plan.sessions.count < count {
            plan.sessions.append(ClientPersonalWorkoutSession(
                id: UUID(), name: "Giorno \(plan.sessions.count + 1)", weekday: nil, exercises: []
            ))
        }
    }

    static func apply(_ split: SuggestedSplit, to plan: inout ClientPersonalWorkoutPlan) {
        guard split != .custom else { return }
        let upper: [ClientMuscleRegion] = [.chest, .upperBack, .lats, .shoulders, .biceps, .triceps]
        let lower: [ClientMuscleRegion] = [.quadriceps, .hamstrings, .glutes, .calves, .core]
        let push: [ClientMuscleRegion] = [.chest, .shoulders, .triceps]
        let pull: [ClientMuscleRegion] = [.upperBack, .lats, .biceps]
        let groups: [[ClientMuscleRegion]]
        switch split {
        case .custom: return
        case .fullBody: groups = [ClientMuscleRegion.allCases]
        case .upperLower: groups = [upper, lower]
        case .pushPullLegs: groups = [push, pull, lower]
        }
        for index in plan.sessions.indices {
            // Changing the split must never delete or replace already selected exercises.
            plan.sessions[index].targetMuscles = groups[index % groups.count]
        }
    }

    static func catalogMatches(_ item: ClientExerciseCatalogItem, groups: [ClientMuscleRegion]) -> Bool {
        guard !groups.isEmpty else { return true }
        let metadata = ClientExerciseMetadataNormalizer.enrich(item)
        return !Set(metadata.primaryMuscles + metadata.secondaryMuscles).isDisjoint(with: groups)
    }

    static func exercise(from item: ClientExerciseCatalogItem) -> ClientPersonalExercise {
        let metadata = ClientExerciseMetadataNormalizer.enrich(item)
        return ClientPersonalExercise(
            id: UUID(), catalogExerciseID: metadata.id, catalogSourceKey: metadata.sourceKey,
            name: metadata.name, muscleGroup: metadata.primaryMuscles.first?.displayName ?? metadata.muscleGroup ?? "",
            sets: 3, repetitions: "8–10", restSeconds: 90, loadKg: nil,
            effortTarget: "RIR 2", notes: "", videoURL: metadata.videoURL,
            primaryMuscles: metadata.primaryMuscles, secondaryMuscles: metadata.secondaryMuscles,
            movementPattern: metadata.movementPattern, compatibleEquipment: metadata.compatibleEquipment,
            exerciseKind: metadata.kind, animationKey: metadata.animationKey, technique: metadata.instructions,
            difficultyLevel: metadata.difficultyLevel, catalogMuscles: metadata.catalogMuscles
        )
    }

    static func validationMessage(_ plan: ClientPersonalWorkoutPlan) -> String? {
        guard plan.title.trimmingCharacters(in: .whitespacesAndNewlines).count >= 2 else { return "Dai un nome alla scheda." }
        guard (2...6).contains(plan.sessions.count) else { return "Scegli da 2 a 6 giornate." }
        for day in plan.sessions {
            guard !day.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return "Dai un nome a ogni giornata." }
            guard !day.exercises.isEmpty else { return "Aggiungi almeno un esercizio a \(day.name)." }
            for exercise in day.exercises {
                guard (1...20).contains(exercise.sets), (0...600).contains(exercise.restSeconds),
                      !exercise.repetitions.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    return "Controlla serie, ripetizioni e recupero di \(exercise.name)."
                }
            }
        }
        return nil
    }
}
