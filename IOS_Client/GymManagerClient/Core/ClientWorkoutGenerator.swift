import Foundation

enum ClientMuscleRegion: String, Codable, CaseIterable, Hashable, Sendable {
    case chest
    case shoulders
    case upperBack
    case lats
    case quadriceps
    case hamstrings
    case biceps
    case triceps
    case glutes
    case core
    case calves

    var displayName: String {
        switch self {
        case .chest: "Petto"
        case .shoulders: "Spalle"
        case .upperBack: "Centro schiena"
        case .lats: "Dorsali"
        case .quadriceps: "Quadricipiti"
        case .hamstrings: "Femorali"
        case .biceps: "Bicipiti"
        case .triceps: "Tricipiti"
        case .glutes: "Glutei"
        case .core: "Core"
        case .calves: "Polpacci"
        }
    }

    static let majorGroups: Set<ClientMuscleRegion> = Set(allCases)
}

enum ClientMovementPattern: String, Codable, CaseIterable, Hashable, Sendable {
    case horizontalPush
    case horizontalPull
    case verticalPush
    case verticalPull
    case kneeDominant
    case hipHinge
    case unilateralLower
    case elbowFlexion
    case elbowExtension
    case core
    case calves
    case mobility
    case cardio
}

enum ClientTrainingEquipment: String, Codable, CaseIterable, Hashable, Sendable {
    case fullGym
    case homeGym
    case bodyweight

    var displayName: String {
        switch self {
        case .fullGym: "Palestra completa"
        case .homeGym: "Home gym"
        case .bodyweight: "Corpo libero"
        }
    }
}

enum ClientExerciseKind: String, Codable, Hashable, Sendable {
    case compound
    case accessory
    case isolation
}

enum ClientTrainingExperience: String, Codable, CaseIterable, Hashable, Sendable {
    case beginner
    case intermediate
    case advanced

    var displayName: String {
        switch self {
        case .beginner: "Principiante"
        case .intermediate: "Intermedio"
        case .advanced: "Avanzato"
        }
    }
}

enum ClientTrainingGoal: String, Codable, CaseIterable, Hashable, Sendable {
    case hypertrophy
    case strengthAndMass
    case recomposition
    case maintenance

    var displayName: String {
        switch self {
        case .hypertrophy: "Ipertrofia"
        case .strengthAndMass: "Forza + massa"
        case .recomposition: "Ricomposizione / fitness"
        case .maintenance: "Mantenimento"
        }
    }
}

enum ClientNutritionPhase: String, Codable, CaseIterable, Hashable, Sendable {
    case bulk
    case maintenance
    case cut

    var displayName: String {
        switch self {
        case .bulk: "Bulk"
        case .maintenance: "Mantenimento"
        case .cut: "Cut"
        }
    }
}

enum ClientWorkoutSplitPreference: String, Codable, CaseIterable, Hashable, Sendable {
    case automatic
    case fullBody
    case upperLower
    case pushPullLegs
    case custom

    var displayName: String {
        switch self {
        case .automatic: "Lascia decidere a Weol"
        case .fullBody: "Full Body"
        case .upperLower: "Upper / Lower"
        case .pushPullLegs: "Push / Pull / Legs"
        case .custom: "Configura i gruppi"
        }
    }
}

enum ClientPersonalWorkoutPlanSource: String, Codable, Sendable {
    case manual
    case guided
}

struct ClientWorkoutQuestionnaireAnswers: Codable, Equatable, Sendable {
    var experience: ClientTrainingExperience = .beginner
    var weeklyFrequency: Int = 3
    var sessionDurationMinutes: Int = 60
    var equipment: ClientTrainingEquipment = .fullGym
    var splitPreference: ClientWorkoutSplitPreference = .automatic
    var customSplitGroups: [[ClientMuscleRegion]] = []
    var priorityMuscles: Set<ClientMuscleRegion> = []
    var goal: ClientTrainingGoal = .hypertrophy
    var nutritionPhase: ClientNutritionPhase = .maintenance
    var avoidedExerciseNames: [String] = []
    var limitations: String = ""
    var durationWeeks: Int = 8

    var isSafeForAutomaticGeneration: Bool {
        let text = limitations.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        let stopWords = ["infortun", "lesion", "operaz", "riabilit", "dolore forte", "dolore acuto"]
        return !stopWords.contains(where: text.contains)
    }
}

struct ClientTrainingProfile: Codable, Equatable, Sendable {
    let experience: ClientTrainingExperience
    let weeklyFrequency: Int
    let sessionDurationMinutes: Int
    let equipment: ClientTrainingEquipment
    let splitPreference: ClientWorkoutSplitPreference
    let customSplitGroups: [[ClientMuscleRegion]]
    let priorityMuscles: Set<ClientMuscleRegion>
    let goal: ClientTrainingGoal
    let nutritionPhase: ClientNutritionPhase
    let avoidedExerciseNames: [String]
    let limitations: String
    let durationWeeks: Int

    init(answers: ClientWorkoutQuestionnaireAnswers) {
        experience = answers.experience
        weeklyFrequency = min(6, max(2, answers.weeklyFrequency))
        sessionDurationMinutes = [30, 45, 60, 75, 90].min(by: { abs($0 - answers.sessionDurationMinutes) < abs($1 - answers.sessionDurationMinutes) }) ?? 60
        equipment = answers.equipment
        splitPreference = answers.splitPreference
        customSplitGroups = answers.customSplitGroups
        priorityMuscles = answers.priorityMuscles
        goal = answers.goal
        nutritionPhase = answers.nutritionPhase
        avoidedExerciseNames = answers.avoidedExerciseNames
        limitations = answers.limitations
        durationWeeks = [4, 6, 8, 12].min(by: { abs($0 - answers.durationWeeks) < abs($1 - answers.durationWeeks) }) ?? 8
    }
}

struct ClientWorkoutProgressionRule: Codable, Equatable, Sendable {
    let kind: String
    let summary: String
    let durationWeeks: Int

    static func doubleProgression(weeks: Int) -> ClientWorkoutProgressionRule {
        ClientWorkoutProgressionRule(
            kind: "double_progression",
            summary: "Raggiungi il limite alto delle ripetizioni con il RIR previsto, poi aumenta gradualmente il carico e riparti dal limite basso.",
            durationWeeks: weeks
        )
    }
}

struct ClientWorkoutPlanValidation: Codable, Equatable, Sendable {
    let allMajorGroupsCovered: Bool
    let weeklyVolumeValid: Bool
    let sessionDurationPlausible: Bool
    let exercisesPerDayValid: Bool
    let equipmentCompatible: Bool
    let priorityMusclesRepresented: Bool
    let recoveryPlausible: Bool
    let hasDuplicateExercises: Bool
    let movementBalanceValid: Bool
    let weeklySets: [ClientMuscleRegion: Int]
    let notices: [String]

    var isValid: Bool {
        allMajorGroupsCovered && weeklyVolumeValid && sessionDurationPlausible && exercisesPerDayValid
            && equipmentCompatible && priorityMusclesRepresented && recoveryPlausible
            && !hasDuplicateExercises && movementBalanceValid
    }
}

struct ClientGeneratedWorkoutResult: Equatable, Sendable {
    let plan: ClientPersonalWorkoutPlan
    let validation: ClientWorkoutPlanValidation
}

enum ClientWorkoutGeneratorError: LocalizedError, Equatable {
    case unsafeLimitations
    case emptyCatalog
    case insufficientCompatibleExercises
    case inconsistentPlan([String])

    var errorDescription: String? {
        switch self {
        case .unsafeLimitations:
            "Per dolore, infortunio o riabilitazione serve una valutazione professionale: la generazione automatica è stata fermata."
        case .emptyCatalog:
            "Il database esercizi non è disponibile. Riprova quando la connessione è attiva."
        case .insufficientCompatibleExercises:
            "Il catalogo non contiene abbastanza esercizi compatibili con l'attrezzatura scelta."
        case .inconsistentPlan(let notices):
            "Il programma non ha superato i controlli: \(notices.joined(separator: ", "))."
        }
    }
}

struct ClientExerciseMetadataNormalizer {
    struct Rule: Sendable {
        let aliases: [String]
        let primary: [ClientMuscleRegion]
        let secondary: [ClientMuscleRegion]
        let pattern: ClientMovementPattern
        let equipment: Set<ClientTrainingEquipment>
        let kind: ClientExerciseKind
        let minimumExperience: ClientTrainingExperience
        let animationKey: String?
    }

    static func enrich(_ item: ClientExerciseCatalogItem) -> ClientExerciseCatalogItem {
        guard let rule = rule(for: item.name) else {
            let legacy = legacyMuscles(item.muscleGroup)
            return item.enriched(
                sourceKey: item.sourceKey ?? "catalog_\(slug(item.name))",
                primaryMuscles: item.primaryMuscles.isEmpty ? legacy : item.primaryMuscles,
                secondaryMuscles: item.secondaryMuscles,
                movementPattern: item.movementPattern,
                compatibleEquipment: item.compatibleEquipment.isEmpty ? Set(ClientTrainingEquipment.allCases) : item.compatibleEquipment,
                kind: item.kind ?? .accessory,
                minimumExperience: item.minimumExperience ?? .beginner,
                animationKey: item.animationKey
            )
        }
        return item.enriched(
            sourceKey: item.sourceKey ?? "catalog_\(slug(item.name))",
            primaryMuscles: item.primaryMuscles.isEmpty ? rule.primary : item.primaryMuscles,
            secondaryMuscles: item.secondaryMuscles.isEmpty ? rule.secondary : item.secondaryMuscles,
            movementPattern: item.movementPattern ?? rule.pattern,
            compatibleEquipment: item.compatibleEquipment.isEmpty ? rule.equipment : item.compatibleEquipment,
            kind: item.kind ?? rule.kind,
            minimumExperience: item.minimumExperience ?? rule.minimumExperience,
            animationKey: item.animationKey ?? rule.animationKey
        )
    }

    static func rule(for name: String) -> Rule? {
        let normalized = normalize(name)
        return rules.first { rule in rule.aliases.contains { normalized.contains(normalize($0)) } }
    }

    private static func legacyMuscles(_ value: String?) -> [ClientMuscleRegion] {
        guard let value else { return [] }
        let normalized = normalize(value)
        if normalized.contains("petto") { return [.chest] }
        if normalized.contains("spall") { return [.shoulders] }
        if normalized.contains("schien") { return [.upperBack, .lats] }
        if normalized.contains("bracc") { return [.biceps, .triceps] }
        if normalized.contains("addom") || normalized.contains("core") { return [.core] }
        if normalized.contains("gamb") { return [.quadriceps, .hamstrings, .glutes] }
        return []
    }

    static func normalize(_ value: String) -> String {
        value.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "it_IT"))
            .lowercased()
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "_", with: " ")
    }

    static func slug(_ value: String) -> String {
        normalize(value).unicodeScalars.map { CharacterSet.alphanumerics.contains($0) ? Character(String($0)) : "_" }
            .reduce(into: "") { $0.append($1) }
            .replacingOccurrences(of: "__", with: "_")
            .trimmingCharacters(in: CharacterSet(charactersIn: "_"))
    }

    private static let allEquipment = Set(ClientTrainingEquipment.allCases)
    private static let gymAndHome: Set<ClientTrainingEquipment> = [.fullGym, .homeGym]
    private static let rules: [Rule] = [
        Rule(aliases: ["panca piana", "bench press"], primary: [.chest], secondary: [.triceps, .shoulders], pattern: .horizontalPush, equipment: gymAndHome, kind: .compound, minimumExperience: .beginner, animationKey: "bench_press_v1"),
        Rule(aliases: ["panca inclinata", "incline press"], primary: [.chest], secondary: [.shoulders, .triceps], pattern: .horizontalPush, equipment: gymAndHome, kind: .compound, minimumExperience: .beginner, animationKey: "bench_press_v1"),
        Rule(aliases: ["chest press"], primary: [.chest], secondary: [.triceps, .shoulders], pattern: .horizontalPush, equipment: [.fullGym], kind: .compound, minimumExperience: .beginner, animationKey: "bench_press_v1"),
        Rule(aliases: ["croci"], primary: [.chest], secondary: [.shoulders], pattern: .horizontalPush, equipment: [.fullGym], kind: .isolation, minimumExperience: .beginner, animationKey: nil),
        Rule(aliases: ["push up", "push-up", "piegamenti"], primary: [.chest], secondary: [.triceps, .shoulders, .core], pattern: .horizontalPush, equipment: allEquipment, kind: .compound, minimumExperience: .beginner, animationKey: "bench_press_v1"),
        Rule(aliases: ["lat machine", "lat pulldown"], primary: [.lats], secondary: [.biceps, .upperBack], pattern: .verticalPull, equipment: [.fullGym], kind: .compound, minimumExperience: .beginner, animationKey: "lat_pulldown_v1"),
        Rule(aliases: ["trazioni", "pull up", "pull-up"], primary: [.lats], secondary: [.biceps, .upperBack], pattern: .verticalPull, equipment: allEquipment, kind: .compound, minimumExperience: .beginner, animationKey: "lat_pulldown_v1"),
        Rule(aliases: ["pulley", "rematore seduto", "seated row"], primary: [.upperBack, .lats], secondary: [.biceps], pattern: .horizontalPull, equipment: [.fullGym], kind: .compound, minimumExperience: .beginner, animationKey: "seated_row_v1"),
        Rule(aliases: ["rematore"], primary: [.upperBack, .lats], secondary: [.biceps, .hamstrings, .core], pattern: .horizontalPull, equipment: gymAndHome, kind: .compound, minimumExperience: .intermediate, animationKey: "seated_row_v1"),
        Rule(aliases: ["shoulder press", "military press"], primary: [.shoulders], secondary: [.triceps], pattern: .verticalPush, equipment: gymAndHome, kind: .compound, minimumExperience: .beginner, animationKey: "shoulder_press_v1"),
        Rule(aliases: ["alzate laterali"], primary: [.shoulders], secondary: [], pattern: .verticalPush, equipment: gymAndHome, kind: .isolation, minimumExperience: .beginner, animationKey: nil),
        Rule(aliases: ["curl bilanciere", "curl ez"], primary: [.biceps], secondary: [], pattern: .elbowFlexion, equipment: gymAndHome, kind: .isolation, minimumExperience: .beginner, animationKey: "biceps_curl_v1"),
        Rule(aliases: ["curl manubri", "biceps curl"], primary: [.biceps], secondary: [], pattern: .elbowFlexion, equipment: gymAndHome, kind: .isolation, minimumExperience: .beginner, animationKey: "biceps_curl_v1"),
        Rule(aliases: ["french press"], primary: [.triceps], secondary: [], pattern: .elbowExtension, equipment: gymAndHome, kind: .isolation, minimumExperience: .beginner, animationKey: "triceps_pushdown_v1"),
        Rule(aliases: ["push down", "pushdown"], primary: [.triceps], secondary: [], pattern: .elbowExtension, equipment: [.fullGym], kind: .isolation, minimumExperience: .beginner, animationKey: "triceps_pushdown_v1"),
        Rule(aliases: ["back squat", "squat"], primary: [.quadriceps, .glutes], secondary: [.hamstrings, .core], pattern: .kneeDominant, equipment: allEquipment, kind: .compound, minimumExperience: .beginner, animationKey: "squat_v1"),
        Rule(aliases: ["stacco rumeno", "romanian deadlift", "rdl", "stacco"], primary: [.hamstrings, .glutes], secondary: [.upperBack, .core], pattern: .hipHinge, equipment: gymAndHome, kind: .compound, minimumExperience: .intermediate, animationKey: "romanian_deadlift_v1"),
        Rule(aliases: ["leg press"], primary: [.quadriceps, .glutes], secondary: [.hamstrings], pattern: .kneeDominant, equipment: [.fullGym], kind: .compound, minimumExperience: .beginner, animationKey: "leg_press_v1"),
        Rule(aliases: ["leg extension"], primary: [.quadriceps], secondary: [], pattern: .kneeDominant, equipment: [.fullGym], kind: .isolation, minimumExperience: .beginner, animationKey: nil),
        Rule(aliases: ["affondi", "lunge"], primary: [.quadriceps, .glutes], secondary: [.hamstrings, .core], pattern: .unilateralLower, equipment: allEquipment, kind: .compound, minimumExperience: .beginner, animationKey: nil),
        Rule(aliases: ["leg curl"], primary: [.hamstrings], secondary: [.glutes], pattern: .hipHinge, equipment: [.fullGym], kind: .isolation, minimumExperience: .beginner, animationKey: "leg_curl_v1"),
        Rule(aliases: ["calf raise", "polpacci"], primary: [.calves], secondary: [], pattern: .calves, equipment: allEquipment, kind: .isolation, minimumExperience: .beginner, animationKey: nil),
        Rule(aliases: ["rear delts", "deltoidi posteriori"], primary: [.shoulders, .upperBack], secondary: [], pattern: .horizontalPull, equipment: [.fullGym], kind: .isolation, minimumExperience: .beginner, animationKey: nil),
        Rule(aliases: ["plank"], primary: [.core], secondary: [.glutes], pattern: .core, equipment: allEquipment, kind: .isolation, minimumExperience: .beginner, animationKey: nil),
        Rule(aliases: ["crunch"], primary: [.core], secondary: [], pattern: .core, equipment: allEquipment, kind: .isolation, minimumExperience: .beginner, animationKey: nil),
        Rule(aliases: ["leg raise"], primary: [.core], secondary: [.quadriceps], pattern: .core, equipment: allEquipment, kind: .accessory, minimumExperience: .beginner, animationKey: nil)
    ]
}

struct ClientWorkoutGenerator {
    private struct SessionBlueprint: Sendable {
        let name: String
        let muscles: Set<ClientMuscleRegion>
        let patterns: [ClientMovementPattern]
        let weekday: Int
    }

    func generate(
        answers: ClientWorkoutQuestionnaireAnswers,
        catalog rawCatalog: [ClientExerciseCatalogItem],
        variation: Int = 0,
        now: Date = Date()
    ) throws -> ClientGeneratedWorkoutResult {
        guard answers.isSafeForAutomaticGeneration else { throw ClientWorkoutGeneratorError.unsafeLimitations }
        let profile = ClientTrainingProfile(answers: answers)
        let avoided = Set(profile.avoidedExerciseNames.map(ClientExerciseMetadataNormalizer.normalize))
        let catalog = rawCatalog
            .map(ClientExerciseMetadataNormalizer.enrich)
            .filter { $0.compatibleEquipment.contains(profile.equipment) }
            .filter { item in !avoided.contains(where: { ClientExerciseMetadataNormalizer.normalize(item.name).contains($0) }) }
            .filter { experienceRank($0.minimumExperience ?? .beginner) <= experienceRank(profile.experience) }
        guard !catalog.isEmpty else { throw ClientWorkoutGeneratorError.emptyCatalog }

        let blueprints = split(profile: profile)
        let count = exerciseCount(durationMinutes: profile.sessionDurationMinutes)
        var weeklyUses: [UUID: Int] = [:]
        var sessions: [ClientPersonalWorkoutSession] = []

        for (index, blueprint) in blueprints.enumerated() {
            let selected = selectExercises(
                catalog: catalog,
                blueprint: blueprint,
                profile: profile,
                targetCount: count,
                variation: variation + index,
                weeklyUses: weeklyUses
            )
            guard selected.count >= min(3, count) else { throw ClientWorkoutGeneratorError.insufficientCompatibleExercises }
            for item in selected { weeklyUses[item.id, default: 0] += 1 }
            let exercises = selected.enumerated().map { offset, item in
                prescribe(item: item, position: offset, profile: profile)
            }
            sessions.append(ClientPersonalWorkoutSession(
                id: UUID(), name: blueprint.name, weekday: blueprint.weekday,
                durationMinutes: profile.sessionDurationMinutes, exercises: exercises
            ))
        }

        let preliminary = ClientPersonalWorkoutPlan(
            id: UUID(), title: suggestedTitle(profile), status: .active, sessions: sessions,
            createdAt: now, updatedAt: now, source: .guided, durationWeeks: profile.durationWeeks,
            generationAnswers: answers, progression: .doubleProgression(weeks: profile.durationWeeks), validation: nil
        )
        let validation = validate(plan: preliminary, profile: profile)
        guard validation.isValid else { throw ClientWorkoutGeneratorError.inconsistentPlan(validation.notices) }
        var plan = preliminary
        plan.validation = validation
        return ClientGeneratedWorkoutResult(plan: plan, validation: validation)
    }

    func validate(plan: ClientPersonalWorkoutPlan, profile: ClientTrainingProfile) -> ClientWorkoutPlanValidation {
        var weeklySets: [ClientMuscleRegion: Int] = [:]
        var patterns: Set<ClientMovementPattern> = []
        var notices: [String] = []
        var equipmentCompatible = true
        var duplicate = false

        for session in plan.sessions {
            var seen: Set<UUID> = []
            for exercise in session.exercises {
                if let catalogID = exercise.catalogExerciseID, !seen.insert(catalogID).inserted { duplicate = true }
                if !(exercise.compatibleEquipment ?? []).contains(profile.equipment) { equipmentCompatible = false }
                if let pattern = exercise.movementPattern { patterns.insert(pattern) }
                for muscle in exercise.primaryMuscles ?? [] { weeklySets[muscle, default: 0] += exercise.sets }
                for muscle in exercise.secondaryMuscles ?? [] { weeklySets[muscle, default: 0] += max(1, exercise.sets / 2) }
            }
        }

        let availableCoverage = Set(plan.sessions.flatMap(\.exercises).flatMap { ($0.primaryMuscles ?? []) + ($0.secondaryMuscles ?? []) })
        let allMajor = ClientMuscleRegion.majorGroups.isSubset(of: availableCoverage)
        let minimumMainVolume = profile.experience == .beginner ? 3 : 6
        let mainGroups: Set<ClientMuscleRegion> = [.chest, .lats, .quadriceps, .hamstrings, .glutes]
        let volumeValid = weeklySets.allSatisfy { muscle, sets in
            sets <= (profile.priorityMuscles.contains(muscle) ? 26 : 22)
        }
            && mainGroups.allSatisfy { (weeklySets[$0] ?? 0) >= minimumMainVolume }
            && (weeklySets[.shoulders] ?? 0) >= 2
        let exerciseCountsValid = plan.sessions.allSatisfy { (3...7).contains($0.exercises.count) }
        let durationPlausible = plan.sessions.allSatisfy { session in
            let estimated = session.exercises.reduce(0) { total, exercise in
                total + exercise.sets * (45 + exercise.restSeconds)
            } / 60
            return estimated <= profile.sessionDurationMinutes + 18
        }
        let prioritiesRepresented = profile.priorityMuscles.allSatisfy { (weeklySets[$0] ?? 0) >= minimumMainVolume + 2 }
        let movementBalance = patterns.contains(.horizontalPush)
            && (patterns.contains(.horizontalPull) || patterns.contains(.verticalPull))
            && patterns.contains(.kneeDominant)
            && (patterns.contains(.hipHinge) || patterns.contains(.unilateralLower))
        let recovery = recoveryIsPlausible(plan.sessions)

        if !allMajor { notices.append("copertura muscolare incompleta") }
        if !volumeValid { notices.append("volume settimanale fuori intervallo") }
        if !durationPlausible { notices.append("durata stimata eccessiva") }
        if !exerciseCountsValid { notices.append("numero esercizi per giornata non valido") }
        if !equipmentCompatible { notices.append("attrezzatura non compatibile") }
        if !prioritiesRepresented { notices.append("gruppi prioritari non rappresentati") }
        if !recovery { notices.append("recupero tra sessioni insufficiente") }
        if duplicate { notices.append("esercizi duplicati nella stessa giornata") }
        if !movementBalance { notices.append("pattern di movimento sbilanciati") }

        return ClientWorkoutPlanValidation(
            allMajorGroupsCovered: allMajor, weeklyVolumeValid: volumeValid,
            sessionDurationPlausible: durationPlausible, exercisesPerDayValid: exerciseCountsValid,
            equipmentCompatible: equipmentCompatible, priorityMusclesRepresented: prioritiesRepresented,
            recoveryPlausible: recovery, hasDuplicateExercises: duplicate,
            movementBalanceValid: movementBalance, weeklySets: weeklySets, notices: notices
        )
    }

    private func split(profile: ClientTrainingProfile) -> [SessionBlueprint] {
        let weekdays = scheduledWeekdays(profile.weeklyFrequency)
        if profile.splitPreference == .custom, !profile.customSplitGroups.isEmpty {
            return (0..<profile.weeklyFrequency).map { index in
                let muscles = Set(profile.customSplitGroups[index % profile.customSplitGroups.count])
                return SessionBlueprint(
                    name: muscles.map(\.displayName).joined(separator: " + "), muscles: muscles,
                    patterns: patterns(for: muscles), weekday: weekdays[index]
                )
            }
        }

        let requested: ClientWorkoutSplitPreference = profile.splitPreference == .automatic
            ? automaticSplit(for: profile.weeklyFrequency)
            : profile.splitPreference
        let templates: [(String, Set<ClientMuscleRegion>, [ClientMovementPattern])]
        switch requested {
        case .fullBody:
            templates = (0..<profile.weeklyFrequency).map { index in fullBodyBlueprint(index: index) }
        case .upperLower:
            templates = (0..<profile.weeklyFrequency).map { index in index.isMultiple(of: 2) ? upperBlueprint(index: index) : lowerBlueprint(index: index) }
        case .pushPullLegs:
            let cycle = [pushBlueprint, pullBlueprint, legsBlueprint]
            templates = (0..<profile.weeklyFrequency).map { cycle[$0 % cycle.count]($0) }
        case .automatic, .custom:
            templates = (0..<profile.weeklyFrequency).map { index in fullBodyBlueprint(index: index) }
        }
        return templates.enumerated().map { index, template in
            SessionBlueprint(name: template.0, muscles: template.1, patterns: template.2, weekday: weekdays[index])
        }
    }

    private func automaticSplit(for frequency: Int) -> ClientWorkoutSplitPreference {
        switch frequency {
        case 2: .fullBody
        case 3: .fullBody
        case 4: .upperLower
        case 5, 6: .pushPullLegs
        default: .fullBody
        }
    }

    private func fullBodyBlueprint(index: Int) -> (String, Set<ClientMuscleRegion>, [ClientMovementPattern]) {
        let patterns: [ClientMovementPattern] = index.isMultiple(of: 2)
            ? [.kneeDominant, .horizontalPush, .verticalPull, .hipHinge, .verticalPush, .core]
            : [.unilateralLower, .horizontalPull, .horizontalPush, .calves, .hipHinge, .verticalPull]
        return ("Full Body \(Character(UnicodeScalar(65 + index)!))", ClientMuscleRegion.majorGroups, patterns)
    }

    private func upperBlueprint(index: Int) -> (String, Set<ClientMuscleRegion>, [ClientMovementPattern]) {
        ("Upper \(index / 2 + 1)", [.chest, .shoulders, .upperBack, .lats, .biceps, .triceps, .core],
         [.horizontalPush, .verticalPull, .verticalPush, .horizontalPull, .elbowFlexion, .elbowExtension])
    }

    private func lowerBlueprint(index: Int) -> (String, Set<ClientMuscleRegion>, [ClientMovementPattern]) {
        ("Lower \(index / 2 + 1)", [.quadriceps, .hamstrings, .glutes, .calves, .core],
         [.kneeDominant, .hipHinge, .unilateralLower, .calves, .core])
    }

    private func pushBlueprint(index: Int) -> (String, Set<ClientMuscleRegion>, [ClientMovementPattern]) {
        ("Push \(index / 3 + 1)", [.chest, .shoulders, .triceps],
         [.horizontalPush, .verticalPush, .horizontalPush, .elbowExtension])
    }

    private func pullBlueprint(index: Int) -> (String, Set<ClientMuscleRegion>, [ClientMovementPattern]) {
        ("Pull \(index / 3 + 1)", [.lats, .upperBack, .biceps],
         [.verticalPull, .horizontalPull, .verticalPull, .elbowFlexion])
    }

    private func legsBlueprint(index: Int) -> (String, Set<ClientMuscleRegion>, [ClientMovementPattern]) {
        ("Legs \(index / 3 + 1)", [.quadriceps, .hamstrings, .glutes, .calves, .core],
         [.kneeDominant, .hipHinge, .unilateralLower, .calves, .core])
    }

    private func patterns(for muscles: Set<ClientMuscleRegion>) -> [ClientMovementPattern] {
        var result: [ClientMovementPattern] = []
        if muscles.contains(.chest) { result.append(.horizontalPush) }
        if muscles.contains(.lats) { result.append(.verticalPull) }
        if muscles.contains(.upperBack) { result.append(.horizontalPull) }
        if muscles.contains(.shoulders) { result.append(.verticalPush) }
        if muscles.contains(.quadriceps) { result.append(.kneeDominant) }
        if muscles.contains(.hamstrings) || muscles.contains(.glutes) { result.append(.hipHinge) }
        if muscles.contains(.biceps) { result.append(.elbowFlexion) }
        if muscles.contains(.triceps) { result.append(.elbowExtension) }
        if muscles.contains(.calves) { result.append(.calves) }
        if muscles.contains(.core) { result.append(.core) }
        return result
    }

    private func selectExercises(
        catalog: [ClientExerciseCatalogItem],
        blueprint: SessionBlueprint,
        profile: ClientTrainingProfile,
        targetCount: Int,
        variation: Int,
        weeklyUses: [UUID: Int]
    ) -> [ClientExerciseCatalogItem] {
        var selected: [ClientExerciseCatalogItem] = []
        for pattern in blueprint.patterns {
            guard selected.count < targetCount else { break }
            let candidates = catalog.filter { $0.movementPattern == pattern && !selected.map(\.id).contains($0.id) }
            if let candidate = ranked(candidates, blueprint: blueprint, profile: profile, variation: variation, weeklyUses: weeklyUses).first {
                selected.append(candidate)
            }
        }
        if selected.count < targetCount {
            let remaining = catalog.filter { item in
                !selected.map(\.id).contains(item.id)
                    && !blueprint.muscles.isDisjoint(with: Set(item.primaryMuscles + item.secondaryMuscles))
            }
            selected.append(contentsOf: ranked(remaining, blueprint: blueprint, profile: profile, variation: variation, weeklyUses: weeklyUses).prefix(targetCount - selected.count))
        }
        return Array(selected.prefix(targetCount))
    }

    private func ranked(
        _ candidates: [ClientExerciseCatalogItem],
        blueprint: SessionBlueprint,
        profile: ClientTrainingProfile,
        variation: Int,
        weeklyUses: [UUID: Int]
    ) -> [ClientExerciseCatalogItem] {
        candidates.sorted { lhs, rhs in
            let left = score(lhs, blueprint: blueprint, profile: profile, variation: variation, weeklyUses: weeklyUses)
            let right = score(rhs, blueprint: blueprint, profile: profile, variation: variation, weeklyUses: weeklyUses)
            return left == right ? lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending : left > right
        }
    }

    private func score(
        _ item: ClientExerciseCatalogItem,
        blueprint: SessionBlueprint,
        profile: ClientTrainingProfile,
        variation: Int,
        weeklyUses: [UUID: Int]
    ) -> Int {
        let primary = Set(item.primaryMuscles)
        let secondary = Set(item.secondaryMuscles)
        var value = primary.intersection(blueprint.muscles).count * 20
        value += secondary.intersection(blueprint.muscles).count * 6
        value += primary.intersection(profile.priorityMuscles).count * 18
        value += item.kind == .compound ? 8 : item.kind == .accessory ? 4 : 0
        value -= weeklyUses[item.id, default: 0] * 5
        let stable = item.name.unicodeScalars.reduce(0) { ($0 + Int($1.value)) % 17 }
        value += (stable + variation * 5) % 7
        return value
    }

    private func prescribe(item: ClientExerciseCatalogItem, position: Int, profile: ClientTrainingProfile) -> ClientPersonalExercise {
        let isMain = position < 2 && item.kind == .compound
        let repetitions: String
        if profile.goal == .strengthAndMass && isMain { repetitions = "4–6" }
        else if item.kind == .isolation { repetitions = "10–15" }
        else if isMain { repetitions = profile.goal == .recomposition ? "6–10" : "6–10" }
        else { repetitions = "8–12" }

        var sets: Int
        switch profile.experience {
        case .beginner: sets = isMain ? 3 : 2
        case .intermediate: sets = isMain ? 4 : 3
        case .advanced:
            sets = profile.sessionDurationMinutes >= 75 ? (isMain ? 3 : 2) : (isMain ? 4 : 3)
        }
        if !Set(item.primaryMuscles).isDisjoint(with: profile.priorityMuscles) { sets += 1 }
        if profile.nutritionPhase == .cut && !isMain && sets > 2 { sets -= 1 }
        sets = min(5, max(2, sets))

        let rest = isMain ? (profile.goal == .strengthAndMass ? 180 : 150) : item.kind == .isolation ? 75 : 105
        let effort = profile.experience == .beginner ? "RIR 3" : item.kind == .isolation ? "RIR 1–2" : "RIR 2"
        let noteParts = [item.instructions, "Double progression: aumenta il carico solo al limite alto del range con il RIR previsto."]
            .compactMap { $0 }.filter { !$0.isEmpty }
        return ClientPersonalExercise(
            id: UUID(), catalogExerciseID: item.id, catalogSourceKey: item.sourceKey,
            name: item.name, muscleGroup: item.primaryMuscles.first?.displayName ?? item.muscleGroup ?? "",
            sets: sets, repetitions: repetitions, restSeconds: rest, loadKg: nil,
            effortTarget: effort, notes: noteParts.joined(separator: " "), videoURL: item.videoURL,
            primaryMuscles: item.primaryMuscles, secondaryMuscles: item.secondaryMuscles,
            movementPattern: item.movementPattern, compatibleEquipment: item.compatibleEquipment,
            exerciseKind: item.kind, animationKey: item.animationKey, technique: item.instructions
        )
    }

    private func exerciseCount(durationMinutes: Int) -> Int {
        switch durationMinutes {
        case ...30: 4
        case ...45: 5
        case ...60: 5
        case ...75: 6
        default: 7
        }
    }

    private func scheduledWeekdays(_ frequency: Int) -> [Int] {
        switch frequency {
        case 2: [1, 4]
        case 3: [1, 3, 5]
        case 4: [1, 2, 4, 5]
        case 5: [1, 2, 3, 5, 6]
        default: [1, 2, 3, 4, 5, 6]
        }
    }

    private func recoveryIsPlausible(_ sessions: [ClientPersonalWorkoutSession]) -> Bool {
        let sorted = sessions.compactMap { session -> (Int, Set<ClientMuscleRegion>)? in
            guard let weekday = session.weekday else { return nil }
            let muscles = Set(session.exercises.flatMap { $0.primaryMuscles ?? [] })
            return (weekday, muscles)
        }.sorted { $0.0 < $1.0 }
        for pair in zip(sorted, sorted.dropFirst()) where pair.1.0 - pair.0.0 <= 1 {
            let overlap = pair.0.1.intersection(pair.1.1)
            if overlap.count >= 4 { return false }
        }
        return true
    }

    private func suggestedTitle(_ profile: ClientTrainingProfile) -> String {
        let goal: String
        switch profile.goal {
        case .hypertrophy: goal = "Ipertrofia"
        case .strengthAndMass: goal = "Forza e massa"
        case .recomposition: goal = "Fitness"
        case .maintenance: goal = "Mantenimento"
        }
        return "\(goal) · \(profile.weeklyFrequency) giorni"
    }

    private func experienceRank(_ value: ClientTrainingExperience) -> Int {
        switch value {
        case .beginner: 0
        case .intermediate: 1
        case .advanced: 2
        }
    }
}
