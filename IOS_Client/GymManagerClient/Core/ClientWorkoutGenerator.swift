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
        case .automatic: "Lascia decidere a GymManager"
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
    // Optional for historical JSON compatibility; new generation requires explicit answers.
    var experienceEvidence: ClientWorkoutExperienceEvidence? = nil
    var equipmentInventory: Set<ClientWorkoutEquipmentItem>? = nil
    var avoidedExerciseIDs: Set<UUID>? = nil
    var healthyAdultAcknowledged: Bool? = nil

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
        experience = answers.experienceEvidence?.classified(cappedAt: answers.experience) ?? .beginner
        weeklyFrequency = answers.weeklyFrequency
        sessionDurationMinutes = answers.sessionDurationMinutes
        equipment = answers.equipment
        splitPreference = answers.splitPreference
        customSplitGroups = answers.customSplitGroups
        priorityMuscles = answers.priorityMuscles
        goal = answers.goal
        nutritionPhase = answers.nutritionPhase
        avoidedExerciseNames = answers.avoidedExerciseNames
        limitations = answers.limitations
        durationWeeks = answers.durationWeeks
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
    let weeklySets: [ClientMuscleRegion: Double]
    let notices: [String]
    var contractValid: Bool? = nil

    var isValid: Bool {
        allMajorGroupsCovered && weeklyVolumeValid && sessionDurationPlausible && exercisesPerDayValid
            && equipmentCompatible && priorityMusclesRepresented && recoveryPlausible
            && !hasDuplicateExercises && movementBalanceValid && contractValid != false
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
        let hasCatalogMuscles = item.catalogMuscles?.isEmpty == false
        guard let rule = rule(for: item.name) else {
            let legacy = legacyMuscles(item.muscleGroup)
            return item.enriched(
                sourceKey: item.sourceKey ?? "catalog_\(slug(item.name))",
                primaryMuscles: hasCatalogMuscles ? item.primaryMuscles : item.primaryMuscles.isEmpty ? legacy : item.primaryMuscles,
                secondaryMuscles: item.secondaryMuscles,
                movementPattern: item.movementPattern,
                compatibleEquipment: item.compatibleEquipment.isEmpty ? Set(ClientTrainingEquipment.allCases) : item.compatibleEquipment,
                kind: item.kind ?? .accessory,
                minimumExperience: item.minimumExperience,
                animationKey: item.animationKey
            )
        }
        return item.enriched(
            sourceKey: item.sourceKey ?? "catalog_\(slug(item.name))",
            primaryMuscles: hasCatalogMuscles ? item.primaryMuscles : item.primaryMuscles.isEmpty ? rule.primary : item.primaryMuscles,
            secondaryMuscles: hasCatalogMuscles ? item.secondaryMuscles : item.secondaryMuscles.isEmpty ? rule.secondary : item.secondaryMuscles,
            movementPattern: item.movementPattern ?? rule.pattern,
            compatibleEquipment: item.compatibleEquipment.isEmpty ? rule.equipment : item.compatibleEquipment,
            kind: item.kind ?? rule.kind,
            minimumExperience: item.minimumExperience ?? reviewedFallbackLevel(item.name, rule: rule),
            animationKey: item.animationKey ?? rule.animationKey
        )
    }

    static func rule(for name: String) -> Rule? {
        let normalized = normalize(name)
        return rules.first { rule in rule.aliases.contains { normalized.contains(normalize($0)) } }
    }

    private static func reviewedFallbackLevel(_ name: String, rule: Rule) -> ClientTrainingExperience {
        // Compatibility for old payloads while the additive DB attribute awaits deployment.
        // This is explicitly not persisted/claimed as a server classification.
        let value = normalize(name)
        if ["trazioni", "pull up"].contains(where: value.contains) { return .advanced }
        if ["panca piana", "bench press", "panca inclinata", "squat", "affondi", "french press",
            "shoulder press", "military press", "push up", "leg raise"].contains(where: value.contains) { return .intermediate }
        return rule.minimumExperience
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
    /// Pure builder; actual account authorization is owned by the session/repository/RLS.
    /// A new instance UUID/date is NOT part of the deterministic programming specification.
    func generate(answers: ClientWorkoutQuestionnaireAnswers, catalog rawCatalog: [ClientExerciseCatalogItem],
                  variation: Int = 0, now: Date = Date()) throws -> ClientGeneratedWorkoutResult {
        guard answers.isSafeForAutomaticGeneration else { throw ClientWorkoutGeneratorError.unsafeLimitations }
        let eligibility = ClientWorkoutGenerationPolicy.validateAnswers(answers)
        guard eligibility == .allowed else { throw eligibility }
        guard !rawCatalog.isEmpty else { throw ClientWorkoutGeneratorError.emptyCatalog }
        let profile = ClientTrainingProfile(answers: answers)
        let admission = try ClientWorkoutCatalogPolicy.admit(rawCatalog, answers: answers, level: profile.experience)
        guard !admission.candidates.isEmpty else { throw ClientWorkoutGenerationEligibility.noCompatibleExercises }
        let strategy = ClientWorkoutCoachRules.strategy(profile)
        let blueprints = ClientWorkoutCoachRules.blueprints(profile, strategy: strategy)
        let safeVariation = min(10_000, max(0, variation))
        var lastIssues: [String] = []
        // Bounded deterministic correction: fill coverage deficits, respect budget and rebalance volume.
        // Never save/show a failed attempt; no unbounded regeneration or random shuffle.
        for pass in 0..<3 {
            var sessions: [ClientPersonalWorkoutSession] = []
            for (dayIndex, blueprint) in blueprints.enumerated() {
                let exercises = select(catalog: admission.candidates, blueprint: blueprint, profile: profile,
                    prior: sessions.flatMap(\.exercises), variation: safeVariation, pass: pass, day: dayIndex)
                guard exercises.count >= 3 else { throw ClientWorkoutGeneratorError.insufficientCompatibleExercises }
                sessions.append(ClientPersonalWorkoutSession(id: UUID(), name: blueprint.name, weekday: blueprint.weekday,
                    durationMinutes: ClientWorkoutCoachRules.minutes(exercises), exercises: exercises,
                    targetMuscles: blueprint.muscles.sorted { $0.rawValue < $1.rawValue }))
            }
            calibrate(&sessions, profile: profile)
            var plan = ClientPersonalWorkoutPlan(id: UUID(), title: "\(title(strategy)) · \(profile.weeklyFrequency) giorni",
                status: .active, sessions: sessions, createdAt: now, updatedAt: now, source: .guided,
                durationWeeks: profile.durationWeeks, generationAnswers: answers,
                progression: .doubleProgression(weeks: profile.durationWeeks), validation: nil)
            plan.generationMetadata = ClientWorkoutGenerationMetadata(generatorVersion: ClientWorkoutCoachRules.version,
                effectiveExperience: profile.experience, strategy: strategy,
                rationale: explanation(profile, strategy: strategy, excluded: admission.excludedCount),
                estimatedSessionMinutes: sessions.map { ClientWorkoutCoachRules.minutes($0.exercises) },
                catalogFingerprint: ClientWorkoutPlanValidator.catalogFingerprint(admission.candidates))
            let report = ClientWorkoutPlanValidator().inspect(plan: plan, answers: answers, catalog: rawCatalog)
            if report.summary.isValid {
                plan.validation = report.summary
                plan = ClientPlanEditing.beginWorkout(plan)
                return ClientGeneratedWorkoutResult(plan: plan, validation: report.summary)
            }
            lastIssues = report.summary.notices
        }
        throw ClientWorkoutGeneratorError.inconsistentPlan(lastIssues)
    }

    func generate(context: ClientWorkoutGenerationContext, answers: ClientWorkoutQuestionnaireAnswers,
                  catalog: [ClientExerciseCatalogItem], variation: Int = 0, now: Date = Date()) throws -> ClientGeneratedWorkoutResult {
        let eligibility = ClientWorkoutGenerationPolicy.evaluate(context: context, answers: answers)
        guard eligibility == .allowed else { throw eligibility }
        return try generate(answers: answers, catalog: catalog, variation: variation, now: now)
    }

    /// Legacy analysis call remains for callers inspecting historical coefficients.
    /// It CANNOT authorize a plan without the actual catalog/answers validation.
    func validate(plan: ClientPersonalWorkoutPlan, profile: ClientTrainingProfile) -> ClientWorkoutPlanValidation {
        let volume = ClientWorkoutVolumeMetrics(exercises: plan.sessions.flatMap(\.exercises))
        return ClientWorkoutPlanValidation(allMajorGroupsCovered: ClientMuscleRegion.majorGroups.isSubset(of: volume.coverage),
            weeklyVolumeValid: false, sessionDurationPlausible: false, exercisesPerDayValid: false,
            equipmentCompatible: false, priorityMusclesRepresented: false, recoveryPlausible: false,
            hasDuplicateExercises: false, movementBalanceValid: false, weeklySets: volume.weeklySets,
            notices: ["catalog-and-answers-required"], contractValid: false)
    }

    private func select(catalog: [ClientWorkoutCatalogPolicy.Candidate], blueprint: ClientWorkoutCoachRules.Blueprint,
                        profile: ClientTrainingProfile, prior: [ClientPersonalExercise], variation: Int, pass: Int, day: Int) -> [ClientPersonalExercise] {
        var selected: [ClientPersonalExercise] = []
        var used: Set<UUID> = []
        var counts: [ClientMovementPattern: Int] = [:]
        let target = ClientWorkoutCoachRules.exerciseCount(profile)
        for slot in 0..<target {
            let desired = blueprint.patterns.indices.contains(slot) ? blueprint.patterns[slot] : nil
            let volume = ClientWorkoutVolumeMetrics(exercises: prior + selected)
            let eligible = catalog.filter {
                !used.contains($0.item.id) && ($0.primary.isSubset(of: blueprint.muscles))
                    && (counts[$0.review.pattern] ?? 0) < 2
            }
            let ranked = eligible.sorted { a, b in
                func score(_ candidate: ClientWorkoutCatalogPolicy.Candidate) -> Double {
                    let item = candidate.item
                    var score = candidate.review.pattern == desired ? 1_000.0 : 0
                    score += candidate.primary.sorted { $0.rawValue < $1.rawValue }.reduce(0) { $0 + max(0, ClientWorkoutCoachRules.target($1, profile) - (volume.weeklySets[$1] ?? 0)) * Double(12 + pass * 8) }
                    score += Double(candidate.primary.intersection(profile.priorityMuscles).count) * 70
                    score += Double(Set(item.secondaryMuscles).intersection(profile.priorityMuscles).count) * 8
                    // Do not let a leg-curl/posterior accessory replace the required compound hinge.
                    let fundamental: Set<ClientMovementPattern> = [.horizontalPush, .horizontalPull, .verticalPull, .kneeDominant, .hipHinge]
                    score += candidate.review.kind == .compound ? (desired.map { fundamental.contains($0) } == true ? 180 : 15) : 0
                    score += profile.experience == .beginner && candidate.level == .beginner ? 25 : 0
                    score -= Double(prior.filter { $0.catalogExerciseID == item.id }.count) * 8
                    // Small deterministic alternative preference ONLY within compatible, constrained candidates.
                    let key = item.id.uuidString.utf8.reduce(0) { ($0 + Int($1)) % 997 }
                    score += Double((key + variation * (key % 5 + 1) + day) % 11)
                    return score
                }
                let sa = score(a), sb = score(b)
                return sa == sb ? a.item.id.uuidString < b.item.id.uuidString : sa > sb
            }
            var chosen: ClientPersonalExercise?
            for candidate in ranked {
                let exercise = prescribe(candidate, profile: profile)
                if ClientWorkoutCoachRules.minutes(selected + [exercise]) <= profile.sessionDurationMinutes {
                    chosen = exercise; used.insert(candidate.item.id); counts[candidate.review.pattern, default: 0] += 1
                    break
                }
            }
            if let chosen { selected.append(chosen) }
        }
        return selected.enumerated().sorted { a, b in
            let ka = a.element.exerciseKind == .compound ? 0 : a.element.exerciseKind == .accessory ? 1 : 2
            let kb = b.element.exerciseKind == .compound ? 0 : b.element.exerciseKind == .accessory ? 1 : 2
            if ka != kb { return ka < kb }
            let pa = !Set(a.element.primaryMuscles ?? []).isDisjoint(with: profile.priorityMuscles)
            let pb = !Set(b.element.primaryMuscles ?? []).isDisjoint(with: profile.priorityMuscles)
            return pa == pb ? a.offset < b.offset : pa
        }.map(\.element)
    }

    private func prescribe(_ candidate: ClientWorkoutCatalogPolicy.Candidate, profile: ClientTrainingProfile) -> ClientPersonalExercise {
        let item = candidate.item
        let compound = candidate.review.kind == .compound
        let repetitions = compound ? (profile.goal == .strengthAndMass ? "4–6" : "6–10")
            : candidate.review.kind == .isolation ? "10–15" : "8–12"
        var sets = profile.experience == .beginner ? 2 : 3
        if !candidate.primary.isDisjoint(with: profile.priorityMuscles) { sets += 1 }
        if profile.nutritionPhase == .cut { sets = max(2, sets - 1) }
        let rest = compound ? (profile.goal == .strengthAndMass ? 180 : 150) : candidate.review.kind == .isolation ? 75 : 105
        return ClientPersonalExercise(id: UUID(), catalogExerciseID: item.id, catalogSourceKey: item.sourceKey,
            name: item.name, muscleGroup: item.primaryMuscles.first?.displayName ?? "",
            sets: sets, repetitions: repetitions, restSeconds: rest, loadKg: nil,
            effortTarget: profile.experience == .beginner ? "RIR 3" : "RIR 2",
            notes: "Double progression: raggiungi il limite alto in tutte le serie con il RIR previsto prima di valutare un aumento del carico.",
            videoURL: item.videoURL, primaryMuscles: item.primaryMuscles, secondaryMuscles: item.secondaryMuscles,
            movementPattern: candidate.review.pattern, compatibleEquipment: item.compatibleEquipment,
            exerciseKind: candidate.review.kind, animationKey: item.animationKey, technique: item.instructions,
            difficultyLevel: candidate.level, catalogMuscles: item.catalogMuscles)
    }

    private func calibrate(_ sessions: inout [ClientPersonalWorkoutSession], profile: ClientTrainingProfile) {
        // Reduce excess first. Each bounded pass changes at most one existing set.
        for _ in 0..<160 {
            let volume = ClientWorkoutVolumeMetrics(exercises: sessions.flatMap(\.exercises))
            let excessive = Set(volume.weeklySets.filter { $0.value > ClientWorkoutCoachRules.maximum($0.key, profile) }.map(\.key))
            guard !excessive.isEmpty else { break }
            var changed = false
            for d in sessions.indices.reversed() {
                for e in sessions[d].exercises.indices.reversed() {
                    let exercise = sessions[d].exercises[e]
                    let involved = Set((exercise.primaryMuscles ?? []) + (exercise.secondaryMuscles ?? []))
                    if exercise.sets > 1 && !involved.isDisjoint(with: excessive) {
                        sessions[d].exercises[e].sets -= 1; changed = true; break
                    }
                }
                if changed { break }
            }
            if !changed { break }
        }
        // Fill attainable target deficits only while each session and weekly ceiling still fit.
        for _ in 0..<160 {
            let current = ClientWorkoutVolumeMetrics(exercises: sessions.flatMap(\.exercises))
            var best: (Int, Int, Double)?
            for d in sessions.indices {
                for e in sessions[d].exercises.indices where sessions[d].exercises[e].sets < 5 {
                    let exercise = sessions[d].exercises[e]
                    let score = (exercise.primaryMuscles ?? []).reduce(0.0) { total, muscle in
                        let deficit = max(0, ClientWorkoutCoachRules.target(muscle, profile) - (current.weeklySets[muscle] ?? 0))
                        return total + deficit * (profile.priorityMuscles.contains(muscle) ? 3 : 1)
                    }
                    guard score > (best?.2 ?? 0) else { continue }
                    var tentative = sessions
                    tentative[d].exercises[e].sets += 1
                    guard ClientWorkoutCoachRules.minutes(tentative[d].exercises) <= profile.sessionDurationMinutes else { continue }
                    let metric = ClientWorkoutVolumeMetrics(exercises: tentative.flatMap(\.exercises))
                    guard metric.weeklySets.allSatisfy({ $0.value <= ClientWorkoutCoachRules.maximum($0.key, profile) }) else { continue }
                    best = (d, e, score)
                }
            }
            guard let best else { break }
            sessions[best.0].exercises[best.1].sets += 1
        }
        for index in sessions.indices { sessions[index].durationMinutes = ClientWorkoutCoachRules.minutes(sessions[index].exercises) }
    }

    private func title(_ strategy: ClientWorkoutStrategy) -> String {
        switch strategy {
        case .fullBody: "Full Body"
        case .upperLower: "Upper / Lower"
        case .pushPullLegs: "Push / Pull / Legs"
        case .hybrid: "Programma ibrido"
        case .custom: "Programma personale"
        }
    }
    private func explanation(_ profile: ClientTrainingProfile, strategy: ClientWorkoutStrategy, excluded: Int) -> [String] {
        var reasons = [
            "\(title(strategy)): \(profile.weeklyFrequency) giorni da \(profile.sessionDurationMinutes) minuti, livello effettivo \(profile.experience.displayName.lowercased()).",
            "Attrezzatura e varianti ammesse tramite revisione esplicita; \(excluded) record esclusi per vincoli o metadata non verificati.",
            "Durata stimata: preparazione, lavoro, recuperi tra serie e transizioni; non è una misura registrata.",
            "Volume iniziale adattato a esperienza e tempo: obiettivo orientativo, non prescrizione medica.",
            "Contributi numerici solo dal catalogo; secondari privi di coefficiente sono esposizioni qualitative.",
            "Progressione doppia per \(profile.durationWeeks) settimane: nessun carico inventato o aumento automatico."
        ]
        if !profile.priorityMuscles.isEmpty {
            reasons.append("Priorità moderate: " + profile.priorityMuscles.map(\.displayName).sorted().joined(separator: ", ") + ".")
        }
        if profile.nutritionPhase == .cut { reasons.append("Cut: base di volume prudente, stessi pattern e range coerenti; recuperi non accorciati automaticamente.") }
        return reasons
    }
}
