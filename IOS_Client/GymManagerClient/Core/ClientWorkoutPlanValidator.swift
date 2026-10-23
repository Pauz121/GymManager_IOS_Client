import Foundation

struct ClientWorkoutVolumeMetrics: Equatable, Sendable {
    var weeklySets: [ClientMuscleRegion: Double] = [:]
    var primarySets: [ClientMuscleRegion: Int] = [:]
    var secondaryExposures: [ClientMuscleRegion: Int] = [:]
    var coverage: Set<ClientMuscleRegion> { Set(primarySets.keys).union(secondaryExposures.keys) }

    init(exercises: [ClientPersonalExercise]) {
        for exercise in exercises {
            let sets = exercise.sets
            guard (1...100).contains(sets) else { continue } // malformed input cannot overflow analytic totals
            if let links = exercise.catalogMuscles, !links.isEmpty {
                var seen: Set<UUID> = []
                for link in links.sorted(by: { $0.id.uuidString < $1.id.uuidString }) {
                    guard seen.insert(link.id).inserted, link.hasKnownRole, let region = link.region else { continue }
                    if let coefficient = link.relevance, (!coefficient.isFinite || coefficient < 0 || coefficient > 1) { continue }
                    if link.relevance == 0 { continue }
                    if link.isPrimary { primarySets[region, default: 0] += sets }
                    else { secondaryExposures[region, default: 0] += sets }
                    if let coefficient = link.relevance { weeklySets[region, default: 0] += Double(sets) * coefficient }
                    else if link.isPrimary { weeklySets[region, default: 0] += Double(sets) }
                    // Missing secondary coefficient stays qualitative. NO invented half-set/activation percent.
                }
            } else {
                // Compatibility analysis only. Such catalog rows are not admitted for new generation.
                for muscle in Set(exercise.primaryMuscles ?? []) {
                    primarySets[muscle, default: 0] += sets; weeklySets[muscle, default: 0] += Double(sets)
                }
                for muscle in Set(exercise.secondaryMuscles ?? []).subtracting(exercise.primaryMuscles ?? []) {
                    secondaryExposures[muscle, default: 0] += sets
                }
            }
        }
    }
}

struct ClientWorkoutRepRange: Equatable, Sendable {
    let lower: Int
    let upper: Int
    init?(_ text: String) {
        let values = text.split(omittingEmptySubsequences: false, whereSeparator: { $0 == "–" || $0 == "-" }).map { $0.trimmingCharacters(in: .whitespaces) }
        guard (1...2).contains(values.count), let low = Int(values[0]), let high = Int(values.last ?? ""),
              (3...30).contains(low), (low...30).contains(high) else { return nil }
        lower = low; upper = high
    }
}

enum ClientWorkoutValidationIssue: String, Codable, CaseIterable, Sendable {
    case answers, days, catalog, equipment, exclusions, coverage, volume, duration, duplicates, movement, order, recovery, prescription, metadata
}

struct ClientWorkoutPlanValidator {
    struct Report: Sendable {
        let summary: ClientWorkoutPlanValidation
        let issues: [ClientWorkoutValidationIssue]
        let volume: ClientWorkoutVolumeMetrics
    }

    static func catalogFingerprint(_ catalog: [ClientWorkoutCatalogPolicy.Candidate]) -> String {
        let rows = catalog.sorted { $0.item.id.uuidString < $1.item.id.uuidString }.map { candidate in
            let links = (candidate.item.catalogMuscles ?? []).sorted { $0.id.uuidString < $1.id.uuidString }.map {
                "\($0.id.uuidString):\($0.region?.rawValue ?? "unknown"):\($0.hasKnownRole):\($0.isPrimary):\($0.relevance.map { String($0) } ?? "unknown")"
            }.joined(separator: ",")
            return "\(candidate.item.id.uuidString)|\(candidate.item.sourceKey ?? "legacy-id")|\(candidate.item.name)|\(candidate.review.pattern.rawValue)|\(candidate.review.kind.rawValue)|\(candidate.level.rawValue)|\(candidate.review.required.map(\.rawValue).sorted().joined(separator: ","))|\(links)"
        }
        return ClientWorkoutCoachRules.fingerprint(rows.joined(separator: "\n"))
    }

    func inspect(plan: ClientPersonalWorkoutPlan, answers: ClientWorkoutQuestionnaireAnswers,
                 catalog: [ClientExerciseCatalogItem], requireMetadata: Bool = true, allowEditedPresentation: Bool = false) -> Report {
        let profile = ClientTrainingProfile(answers: answers)
        let admitted = (try? ClientWorkoutCatalogPolicy.admit(catalog, answers: answers, level: profile.experience).candidates) ?? []
        let byID = Dictionary(uniqueKeysWithValues: admitted.map { ($0.item.id, $0) })
        var issues: Set<ClientWorkoutValidationIssue> = []
        let answersAllowed = ClientWorkoutGenerationPolicy.validateAnswers(answers) == .allowed
        if !answersAllowed { issues.insert(.answers) }
        let blueprints = answersAllowed ? ClientWorkoutCoachRules.blueprints(profile, strategy: ClientWorkoutCoachRules.strategy(profile)) : []
        if allowEditedPresentation {
            func groupKey(_ groups: Set<ClientMuscleRegion>) -> String { groups.map(\.rawValue).sorted().joined(separator: ",") }
            if plan.sessions.map({ groupKey(Set($0.targetMuscles ?? [])) }).sorted() != blueprints.map({ groupKey($0.muscles) }).sorted() { issues.insert(.days) }
        }
        if plan.sessions.count != answers.weeklyFrequency { issues.insert(.days) }
        if plan.title.trimmingCharacters(in: .whitespacesAndNewlines).count < 2 || plan.title.count > 160 { issues.insert(.metadata) }
        var instanceIDs: Set<UUID> = [plan.id]
        var weekdays: Set<Int> = []
        var patterns: [ClientMovementPattern: Int] = [:]
        for (dayIndex, day) in plan.sessions.enumerated() {
            if !instanceIDs.insert(day.id).inserted { issues.insert(.duplicates) }
            if let weekday = day.weekday, (1...7).contains(weekday), weekdays.insert(weekday).inserted {} else { issues.insert(.days) }
            if !(3...ClientWorkoutCoachRules.exerciseCount(profile)).contains(day.exercises.count) { issues.insert(.days) }
            if day.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { issues.insert(.days) }
            if ClientWorkoutCoachRules.minutes(day.exercises) > answers.sessionDurationMinutes
                || day.durationMinutes != ClientWorkoutCoachRules.minutes(day.exercises) { issues.insert(.duration) }
            if !allowEditedPresentation && blueprints.indices.contains(dayIndex) {
                let expected = blueprints[dayIndex]
                if day.name != expected.name || day.weekday != expected.weekday
                    || Set(day.targetMuscles ?? []) != expected.muscles { issues.insert(.days) }
            }
            var catalogIDs: Set<UUID> = []
            var patternCounts: [ClientMovementPattern: Int] = [:]
            var previousOrder = 0
            for exercise in day.exercises {
                guard let catalogID = exercise.catalogExerciseID, let candidate = byID[catalogID] else {
                    issues.insert(.catalog); issues.insert(.equipment); issues.insert(.exclusions); continue
                }
                let item = candidate.item
                let allowedGroups = allowEditedPresentation ? Set(day.targetMuscles ?? []) : blueprints.indices.contains(dayIndex) ? blueprints[dayIndex].muscles : []
                if !candidate.primary.isSubset(of: allowedGroups) { issues.insert(.movement) }
                if !catalogIDs.insert(catalogID).inserted || !instanceIDs.insert(exercise.id).inserted { issues.insert(.duplicates) }
                if exercise.name != item.name || exercise.catalogSourceKey != item.sourceKey
                    || exercise.primaryMuscles != item.primaryMuscles || exercise.secondaryMuscles != item.secondaryMuscles
                    || exercise.catalogMuscles != item.catalogMuscles || exercise.movementPattern != candidate.review.pattern
                    || exercise.exerciseKind != candidate.review.kind || exercise.difficultyLevel != candidate.level { issues.insert(.catalog) }
                if exercise.compatibleEquipment != item.compatibleEquipment { issues.insert(.equipment) }
                if !(1...5).contains(exercise.sets) || ClientWorkoutRepRange(exercise.repetitions) == nil
                    || !(45...300).contains(exercise.restSeconds) || exercise.loadKg != nil
                    || !["RIR 1", "RIR 2", "RIR 3", "RIR 4"].contains(exercise.effortTarget) { issues.insert(.prescription) }
                if candidate.review.kind == .compound && exercise.restSeconds < 90 { issues.insert(.prescription) }
                let order = candidate.review.kind == .compound ? 0 : candidate.review.kind == .accessory ? 1 : 2
                if order < previousOrder { issues.insert(.order) }; previousOrder = order
                patternCounts[candidate.review.pattern, default: 0] += 1
                if candidate.review.kind == .compound { patterns[candidate.review.pattern, default: 0] += exercise.sets }
            }
            if patternCounts.values.contains(where: { $0 > 2 }) { issues.insert(.movement) }
        }
        let volume = ClientWorkoutVolumeMetrics(exercises: plan.sessions.flatMap(\.exercises))
        if !ClientMuscleRegion.majorGroups.isSubset(of: volume.coverage) { issues.insert(.coverage) }
        let main: Set<ClientMuscleRegion> = [.chest, .lats, .quadriceps, .hamstrings, .glutes]
        if !main.allSatisfy({ (volume.weeklySets[$0] ?? 0) >= ClientWorkoutCoachRules.minimumVolume(profile) })
            || !volume.weeklySets.allSatisfy({ $0.value.isFinite && $0.value <= ClientWorkoutCoachRules.maximum($0.key, profile) }) { issues.insert(.volume) }
        let priorities = profile.priorityMuscles.allSatisfy {
            (volume.weeklySets[$0] ?? 0) >= ClientWorkoutCoachRules.minimumVolume(profile) + 2
        }
        if !priorities { issues.insert(.volume) }
        let push = (patterns[.horizontalPush] ?? 0) + (patterns[.verticalPush] ?? 0)
        let pull = (patterns[.horizontalPull] ?? 0) + (patterns[.verticalPull] ?? 0)
        if patterns[.horizontalPush] == nil || pull == 0 || patterns[.kneeDominant] == nil || patterns[.hipHinge] == nil
            || Double(max(push, pull)) > Double(max(1, min(push, pull))) * 3 { issues.insert(.movement) }
        let sortedDays = plan.sessions.sorted { ($0.weekday ?? 0) < ($1.weekday ?? 0) }
        if sortedDays.count > 1 {
            for index in sortedDays.indices {
                let current = sortedDays[index], next = sortedDays[(index + 1) % sortedDays.count]
                let gap = ((next.weekday ?? 0) - (current.weekday ?? 0) + 7) % 7
                if gap == 1 {
                    let a = ClientWorkoutVolumeMetrics(exercises: current.exercises).primarySets
                    let b = ClientWorkoutVolumeMetrics(exercises: next.exercises).primarySets
                    if a.contains(where: { $0.value >= 6 && (b[$0.key] ?? 0) >= 6 }) { issues.insert(.recovery) }
                }
            }
        }
        if requireMetadata {
            if let metadata = plan.generationMetadata {
                if metadata.generatorVersion != ClientWorkoutCoachRules.version || metadata.effectiveExperience != profile.experience
                    || metadata.strategy != ClientWorkoutCoachRules.strategy(profile) || metadata.rationale.isEmpty
                    || metadata.estimatedSessionMinutes != plan.sessions.map({ ClientWorkoutCoachRules.minutes($0.exercises) })
                    || metadata.catalogFingerprint != Self.catalogFingerprint(admitted) { issues.insert(.metadata) }
            } else { issues.insert(.metadata) }
            if plan.source != .guided || plan.durationWeeks != answers.durationWeeks || plan.generationAnswers != answers
                || plan.progression?.kind != "double_progression" || plan.progression?.durationWeeks != answers.durationWeeks { issues.insert(.metadata) }
        }
        let ordered = ClientWorkoutValidationIssue.allCases.filter { issues.contains($0) }
        let summary = ClientWorkoutPlanValidation(allMajorGroupsCovered: !issues.contains(.coverage),
            weeklyVolumeValid: !issues.contains(.volume), sessionDurationPlausible: !issues.contains(.duration),
            exercisesPerDayValid: !issues.contains(.days), equipmentCompatible: !issues.contains(.equipment),
            priorityMusclesRepresented: priorities, recoveryPlausible: !issues.contains(.recovery),
            hasDuplicateExercises: issues.contains(.duplicates), movementBalanceValid: !issues.contains(.movement),
            weeklySets: volume.weeklySets, notices: ordered.map(\.rawValue), contractValid: issues.isEmpty)
        return Report(summary: summary, issues: ordered, volume: volume)
    }
}
