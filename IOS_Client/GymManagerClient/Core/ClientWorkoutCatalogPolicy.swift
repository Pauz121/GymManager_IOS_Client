import Foundation

/// Generation-only metadata review. Does not change the shared display normalizer/catalog.
enum ClientWorkoutCatalogPolicy {
    struct Review: Sendable {
        let id: String?
        let sourceKey: String?
        let name: String
        let pattern: ClientMovementPattern
        let kind: ClientExerciseKind
        let required: Set<ClientWorkoutEquipmentItem>
        let level: ClientTrainingExperience
    }
    struct Candidate: Sendable {
        let item: ClientExerciseCatalogItem
        let review: Review
        let level: ClientTrainingExperience
        var primary: Set<ClientMuscleRegion> { Set(item.primaryMuscles) }
    }
    struct Admission: Sendable {
        let candidates: [Candidate]
        let excludedCount: Int
    }

    static func normalize(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .lowercased()
    }
    static func review(for item: ClientExerciseCatalogItem) -> Review? {
        reviews.first {
            (($0.id != nil && $0.id == item.id.uuidString.lowercased())
                || ($0.sourceKey != nil && $0.sourceKey == item.sourceKey))
                && normalize($0.name) == normalize(item.name)
        }
    }
    static func inventory(_ answers: ClientWorkoutQuestionnaireAnswers) -> Set<ClientWorkoutEquipmentItem> {
        if answers.equipment == .fullGym { return Set(ClientWorkoutEquipmentItem.allCases) }
        return answers.equipmentInventory ?? []
    }
    static func coarseEquipment(for required: Set<ClientWorkoutEquipmentItem>) -> Set<ClientTrainingEquipment> {
        var result: Set<ClientTrainingEquipment> = [.fullGym]
        if required.isDisjoint(with: [.machines, .cables]) { result.insert(.homeGym) }
        if required.isSubset(of: [.floor, .pullupBar, .bands]) { result.insert(.bodyweight) }
        return result
    }

    static func admit(_ raw: [ClientExerciseCatalogItem], answers: ClientWorkoutQuestionnaireAnswers,
                      level: ClientTrainingExperience) throws -> Admission {
        let byID = Dictionary(grouping: raw, by: \.id)
        let exclusions = Set(answers.avoidedExerciseNames.map(normalize).filter { !$0.isEmpty })
        // Do not silently ignore an ambiguous/free-text exclusion.
        let knownNames = Set(raw.map { normalize($0.name) })
        guard exclusions.isSubset(of: knownNames) else {
            throw ClientWorkoutGeneratorError.inconsistentPlan(["Seleziona gli esercizi da evitare dal catalogo: almeno un nome non corrisponde esattamente."])
        }
        let excludedIDs = answers.avoidedExerciseIDs ?? []
        let available = inventory(answers)
        var result: [Candidate] = []
        for id in byID.keys.sorted(by: { $0.uuidString < $1.uuidString }) {
            guard let rows = byID[id], let item = rows.first,
                  rows.allSatisfy({ $0 == item }), // conflicting copies of an ID fail closed
                  id != UUID(uuid: (0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0)),
                  !excludedIDs.contains(id), !exclusions.contains(normalize(item.name)),
                  let rule = review(for: item), rule.required.isSubset(of: available),
                  let links = item.catalogMuscles, !links.isEmpty else { continue }
            // Generic legacy names do not establish a precise home variant. Use imported explicit variants.
            if answers.equipment != .fullGym && rule.sourceKey == nil { continue }
            // Unknown roles/regions and conflicting coefficients cannot establish a safe program.
            guard links.allSatisfy({ link in
                link.hasKnownRole && link.region != nil
                    && (link.relevance.map { $0.isFinite && (0...1).contains($0) } ?? true)
            }), Set(links.map(\.id)).count == links.count else { continue }
            let known = links
            let primary = Set(known.filter { $0.isPrimary && $0.relevance != 0 }.compactMap(\.region))
            guard !primary.isEmpty else { continue }
            let effectiveLevel = item.difficultyLevel ?? rule.level
            guard effectiveLevel != .advanced || level == .advanced else { continue }
            // A self-capped beginner may use reviewed intermediate fundamentals only with declared familiarity.
            // A true novice gets stable beginner variants, or an explicit insufficient-catalog result.
            if level == .beginner && effectiveLevel == .intermediate
                && answers.experienceEvidence?.compoundFamiliarity != true { continue }
            // Roles come ONLY from associations, never from the exercise name/review table.
            let canonical = item.enriched(sourceKey: item.sourceKey, primaryMuscles: primary.sorted { $0.rawValue < $1.rawValue },
                secondaryMuscles: Set(known.filter { !$0.isPrimary }.compactMap(\.region)).subtracting(primary).sorted { $0.rawValue < $1.rawValue },
                movementPattern: rule.pattern, compatibleEquipment: coarseEquipment(for: rule.required),
                kind: rule.kind, minimumExperience: effectiveLevel, animationKey: item.animationKey)
            result.append(Candidate(item: canonical, review: rule, level: effectiveLevel))
        }
        return Admission(candidates: result, excludedCount: byID.count - result.count)
    }

    // Exact public legacy IDs already present in 20261008074659_exercise_difficulty_levels.sql.
    // Variant source keys/names below are from the existing 20260822 import, not new exercise IDs.
    // Local programming metadata, not medical certification. Server difficulty overrides local level.
    static let reviews: [Review] = [
        .init(id: "3e0f0e97-7d85-458a-b2b1-96b28c94d85b", sourceKey: nil, name: "Panca piana", pattern: .horizontalPush, kind: .compound, required: [.barbell, .bench], level: .intermediate),
        .init(id: "a90a10a6-45e2-45f8-889e-9a75d4ca5f3f", sourceKey: nil, name: "Panca inclinata", pattern: .horizontalPush, kind: .compound, required: [.barbell, .bench], level: .intermediate),
        .init(id: "b881964d-c8cb-4ffb-8166-ca4fcd4da8ab", sourceKey: nil, name: "Chest press", pattern: .horizontalPush, kind: .compound, required: [.machines], level: .beginner),
        .init(id: "00730851-5ae5-433b-8849-ff91c8e16ef5", sourceKey: nil, name: "Croci ai cavi", pattern: .horizontalPush, kind: .isolation, required: [.cables], level: .beginner),
        .init(id: "249ddedd-a719-4a47-a88c-8a6772597683", sourceKey: nil, name: "Push-up", pattern: .horizontalPush, kind: .compound, required: [.floor], level: .intermediate),
        .init(id: "64678d57-32c5-4fa4-9b5d-ad68b0e973fd", sourceKey: nil, name: "Lat machine", pattern: .verticalPull, kind: .compound, required: [.machines], level: .beginner),
        .init(id: "8559d5c9-b416-40c2-829f-348d313d4611", sourceKey: nil, name: "Pulley", pattern: .horizontalPull, kind: .compound, required: [.cables], level: .beginner),
        .init(id: "a6bd38d1-bafd-4d5f-9483-28276b1be47c", sourceKey: nil, name: "Rematore bilanciere", pattern: .horizontalPull, kind: .compound, required: [.barbell], level: .intermediate),
        .init(id: "383e4f03-8a77-473d-80aa-1d8e3b6820c4", sourceKey: nil, name: "Shoulder press", pattern: .verticalPush, kind: .compound, required: [.dumbbells, .bench], level: .intermediate),
        .init(id: "fd7c068d-fa9a-41b9-954c-4d7ca4596fb8", sourceKey: nil, name: "Alzate laterali", pattern: .verticalPush, kind: .isolation, required: [.dumbbells], level: .beginner),
        .init(id: "cf3fc762-7576-4f29-9415-5f6e6757a070", sourceKey: nil, name: "Curl manubri", pattern: .elbowFlexion, kind: .isolation, required: [.dumbbells], level: .beginner),
        .init(id: "d806f1e5-06bc-418f-9f86-75f20057dd75", sourceKey: nil, name: "Curl bilanciere", pattern: .elbowFlexion, kind: .isolation, required: [.barbell], level: .beginner),
        .init(id: "4f3cc661-b376-443b-ba2e-a1216a5a8b31", sourceKey: nil, name: "Push down al cavo", pattern: .elbowExtension, kind: .isolation, required: [.cables], level: .beginner),
        .init(id: "b6cd9b15-f8c8-4f61-92df-6b606f58709f", sourceKey: nil, name: "French press", pattern: .elbowExtension, kind: .isolation, required: [.barbell, .bench], level: .intermediate),
        .init(id: "2c476f68-d319-4032-b8c5-318591082cf0", sourceKey: nil, name: "Squat", pattern: .kneeDominant, kind: .compound, required: [.barbell], level: .intermediate),
        .init(id: "f7123c24-8a54-43be-a7fc-9d902cc1ed97", sourceKey: nil, name: "Leg press", pattern: .kneeDominant, kind: .compound, required: [.machines], level: .beginner),
        .init(id: "6bfc0d0f-36ee-4f4d-bd35-3a73e9f1d43f", sourceKey: nil, name: "Calf raise", pattern: .calves, kind: .isolation, required: [.machines], level: .beginner),
        .init(id: "a766173a-0a86-4e4d-8250-9c946e897f39", sourceKey: nil, name: "Crunch", pattern: .core, kind: .isolation, required: [.floor], level: .beginner),
        .init(id: nil, sourceKey: "exercise_row_6", name: "Spinte Con Manubri Su Panca Piona", pattern: .horizontalPush, kind: .compound, required: [.dumbbells, .bench], level: .intermediate),
        .init(id: nil, sourceKey: "exercise_row_36", name: "Push-Up A Terra", pattern: .horizontalPush, kind: .compound, required: [.floor], level: .intermediate),
        .init(id: nil, sourceKey: "exercise_row_55", name: "Alzate Laterali Con Manubri", pattern: .verticalPush, kind: .isolation, required: [.dumbbells], level: .beginner),
        .init(id: nil, sourceKey: "exercise_row_108", name: "Rematore Con Manubrio", pattern: .horizontalPull, kind: .compound, required: [.dumbbells], level: .intermediate),
        .init(id: nil, sourceKey: "exercise_row_129", name: "Rematore singolo con manubrio su panca", pattern: .horizontalPull, kind: .compound, required: [.dumbbells, .bench], level: .beginner),
        .init(id: nil, sourceKey: "exercise_row_120", name: "Pulley Con Elastico", pattern: .horizontalPull, kind: .compound, required: [.bands], level: .beginner),
        .init(id: nil, sourceKey: "exercise_row_219", name: "Goblet Squat", pattern: .kneeDominant, kind: .compound, required: [.dumbbells], level: .beginner),
        .init(id: nil, sourceKey: "exercise_row_221", name: "Air Squat", pattern: .kneeDominant, kind: .compound, required: [.floor], level: .beginner),
        .init(id: nil, sourceKey: "exercise_row_259", name: "Stacco Rumeno", pattern: .hipHinge, kind: .compound, required: [.barbell], level: .intermediate),
        .init(id: nil, sourceKey: "exercise_row_271", name: "Stacchi Rumeni Con Manubri", pattern: .hipHinge, kind: .compound, required: [.dumbbells], level: .intermediate),
        .init(id: nil, sourceKey: "exercise_row_462", name: "Crunch A Terra", pattern: .core, kind: .isolation, required: [.floor], level: .beginner),
        .init(id: nil, sourceKey: "exercise_row_517", name: "Walking calf raises con manubri", pattern: .calves, kind: .isolation, required: [.dumbbells], level: .beginner)
    ]
}
