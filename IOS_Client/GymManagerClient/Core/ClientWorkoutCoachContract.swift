import Foundation

/// Product classification, not a diagnosis, strength score or medical clearance.
struct ClientWorkoutExperienceEvidence: Codable, Equatable, Sendable {
    var totalMonths: Int
    var recentConsistentMonths: Int
    var recentSessionsPerWeek: Int
    var compoundFamiliarity: Bool
    var canUseRIR: Bool
    var hasUsedLoadProgression: Bool

    var isValid: Bool {
        (0...600).contains(totalMonths) && (0...600).contains(recentConsistentMonths)
            && recentConsistentMonths <= totalMonths && (0...7).contains(recentSessionsPerWeek)
    }

    func classified(cappedAt perceived: ClientTrainingExperience) -> ClientTrainingExperience {
        let supported: ClientTrainingExperience
        if totalMonths >= 36, recentConsistentMonths >= 12, recentSessionsPerWeek >= 3,
           compoundFamiliarity, canUseRIR, hasUsedLoadProgression { supported = .advanced }
        else if totalMonths >= 6, recentConsistentMonths >= 3, recentSessionsPerWeek >= 2,
                compoundFamiliarity { supported = .intermediate }
        else { supported = .beginner }
        let levels: [ClientTrainingExperience] = [.beginner, .intermediate, .advanced]
        return levels[min(levels.firstIndex(of: supported) ?? 0, levels.firstIndex(of: perceived) ?? 0)]
    }
}

enum ClientWorkoutEquipmentItem: String, Codable, CaseIterable, Hashable, Sendable {
    case floor, dumbbells, barbell, bench, cables, machines, pullupBar, bands
    var title: String {
        switch self {
        case .floor: "Spazio a terra"
        case .dumbbells: "Manubri"
        case .barbell: "Bilanciere e supporti"
        case .bench: "Panca"
        case .cables: "Cavi"
        case .machines: "Macchine"
        case .pullupBar: "Sbarra trazioni"
        case .bands: "Elastici"
        }
    }
}

enum ClientWorkoutStrategy: String, Codable, Sendable {
    case fullBody, upperLower, pushPullLegs, hybrid, custom
}

struct ClientWorkoutGenerationContext: Equatable, Sendable {
    /// Nil means there is no verified active Client identity. Never infer from a UI toggle.
    let mode: ClientConnectionMode?
}

enum ClientWorkoutRequiredAnswer: String, Codable, Sendable {
    case experienceEvidence, equipmentInventory, healthyAdultAcknowledgement
}

enum ClientWorkoutGenerationEligibility: Error, LocalizedError, Equatable, Sendable {
    case allowed
    case deniedUnauthenticated
    case deniedTrainerManaged
    case missingRequiredAnswers([ClientWorkoutRequiredAnswer])
    case invalidExperience
    case invalidFrequency
    case invalidDuration
    case invalidProgramLength
    case incompatiblePreferredSplit
    case invalidCustomSplit
    case professionalAssessmentRequired
    case noCompatibleExercises

    var errorDescription: String? {
        switch self {
        case .allowed: nil
        case .deniedUnauthenticated: "Accedi prima di creare una scheda personale."
        case .deniedTrainerManaged: "La programmazione viene gestita dal tuo Trainer. Le schede personali precedenti restano nello storico."
        case .missingRequiredAnswers: "Completa esperienza, attrezzatura e conferma di idoneità al fitness generale."
        case .invalidExperience: "Controlla i mesi di esperienza, la continuità recente e la frequenza attuale."
        case .invalidFrequency: "Scegli da 2 a 6 allenamenti settimanali."
        case .invalidDuration: "Scegli una durata di 30, 45, 60, 75 o 90 minuti."
        case .invalidProgramLength: "Scegli 4, 6, 8 o 12 settimane."
        case .incompatiblePreferredSplit: "Con questa disponibilità lo split non è adatto. Scegli Decidi tu o Full Body."
        case .invalidCustomSplit: "Assegna i gruppi a ogni giornata e copri l'intera settimana."
        case .professionalAssessmentRequired: "La generazione è per adulti sani e fitness generale. Per dolore, lesioni o riabilitazione rivolgiti a un professionista."
        case .noCompatibleExercises: "Non ci sono abbastanza esercizi verificati per questi vincoli. Rivedi attrezzatura o esclusioni."
        }
    }
}

enum ClientWorkoutGenerationPolicy {
    static func evaluate(context: ClientWorkoutGenerationContext, answers: ClientWorkoutQuestionnaireAnswers) -> ClientWorkoutGenerationEligibility {
        guard let mode = context.mode else { return .deniedUnauthenticated }
        guard ClientAccessPolicy.canManagePersonalWorkoutPlans(in: mode) else { return .deniedTrainerManaged }
        return validateAnswers(answers)
    }

    static func validateAnswers(_ answers: ClientWorkoutQuestionnaireAnswers) -> ClientWorkoutGenerationEligibility {
        guard (2...6).contains(answers.weeklyFrequency) else { return .invalidFrequency }
        guard [30, 45, 60, 75, 90].contains(answers.sessionDurationMinutes) else { return .invalidDuration }
        guard [4, 6, 8, 12].contains(answers.durationWeeks) else { return .invalidProgramLength }
        var missing: [ClientWorkoutRequiredAnswer] = []
        if answers.experienceEvidence == nil { missing.append(.experienceEvidence) }
        if answers.equipment != .fullGym && answers.equipmentInventory?.isEmpty != false { missing.append(.equipmentInventory) }
        if answers.healthyAdultAcknowledged == nil { missing.append(.healthyAdultAcknowledgement) }
        guard missing.isEmpty else { return .missingRequiredAnswers(missing) }
        guard answers.experienceEvidence?.isValid == true else { return .invalidExperience }
        guard answers.healthyAdultAcknowledged == true, answers.isSafeForAutomaticGeneration else { return .professionalAssessmentRequired }
        if answers.splitPreference == .pushPullLegs && answers.weeklyFrequency < 3 { return .incompatiblePreferredSplit }
        if answers.splitPreference == .upperLower && answers.weeklyFrequency < 3 { return .incompatiblePreferredSplit }
        if answers.splitPreference == .fullBody && answers.weeklyFrequency > 3 { return .incompatiblePreferredSplit }
        if answers.splitPreference == .custom {
            guard answers.customSplitGroups.count == answers.weeklyFrequency,
                  answers.customSplitGroups.allSatisfy({ !$0.isEmpty }),
                  ClientMuscleRegion.majorGroups.isSubset(of: Set(answers.customSplitGroups.flatMap { $0 })) else { return .invalidCustomSplit }
        }
        return .allowed
    }
}

/// Optional JSON-payload extension. Older plans decode unchanged and are never regenerated.
struct ClientWorkoutGenerationMetadata: Codable, Equatable, Sendable {
    let generatorVersion: String
    let effectiveExperience: ClientTrainingExperience
    let strategy: ClientWorkoutStrategy
    let rationale: [String]
    let estimatedSessionMinutes: [Int]
    let catalogFingerprint: String
}
