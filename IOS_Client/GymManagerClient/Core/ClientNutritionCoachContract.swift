import Foundation

enum ClientNutritionGenerationEligibility: String, Error, LocalizedError, Codable, Sendable {
    case allowed, deniedUnauthenticated, deniedTrainerManaged, underAge, pregnancyOrBreastfeeding
    case eatingDisorderRisk, medicalConditionRequiresProfessional, missingRequiredProfile
    case invalidAnthropometrics, unsupportedGoal, energyTargetUnsafe, insufficientFoodData
    case allergyConflict, incompatiblePreferences, fitFailed, invalidPlan

    var errorDescription: String? {
        switch self {
        case .allowed: "Generazione disponibile."
        case .deniedUnauthenticated: "Accedi nuovamente prima di creare il piano."
        case .deniedTrainerManaged: ClientAccessPolicy.trainerManagedPlansMessage
        case .underAge: "La generazione automatica è riservata agli adulti."
        case .pregnancyOrBreastfeeding, .eatingDisorderRisk, .medicalConditionRequiresProfessional:
            "Per queste esigenze serve una valutazione di un professionista; non generiamo piani clinici."
        case .missingRequiredProfile: "Completa i dati e le conferme richieste per il programma guidato."
        case .invalidAnthropometrics: "Questi dati non rientrano nell'ambito del generatore. Verificali con un professionista."
        case .unsupportedGoal: "Questo obiettivo richiede una valutazione personalizzata."
        case .energyTargetUnsafe: "La stima non consente una proposta automatica appropriata. Rivolgiti a un professionista."
        case .insufficientFoodData: "Mancano alimenti con provenienza e compatibilità verificate. Nessun valore verrà inventato."
        case .allergyConflict: "Il catalogo verificato non permette di rispettare tutte le allergie o intolleranze indicate."
        case .incompatiblePreferences: "Il catalogo verificato non consente questa combinazione di preferenze."
        case .fitFailed: "Non è possibile rispettare gli obiettivi con porzioni realistiche e gli alimenti disponibili."
        case .invalidPlan: "Il piano non supera i controlli di coerenza. La bozza non è stata salvata."
        }
    }
}

enum ClientNutritionDietPattern: String, Codable, CaseIterable, Hashable, Sendable { case omnivore, vegetarian, vegan }
enum ClientNutritionAllergen: String, Codable, CaseIterable, Hashable, Sendable {
    case glutenCereals, crustaceans, eggs, fish, peanuts, soy, milk, treeNuts, celery, mustard, sesame, sulphites, lupin, molluscs
}
enum ClientNutritionIntolerance: String, Codable, CaseIterable, Hashable, Sendable { case lactose, gluten }
enum ClientNutritionDailyActivity: String, Codable, Sendable { case seated, mixed, physical }

/// Explicit evidence, not a claim that an activity multiplier is individually measured.
struct ClientNutritionActivityEvidence: Codable, Equatable, Sendable {
    var dailyActivity: ClientNutritionDailyActivity
    var exerciseDaysPerWeek: Int
    var reliableAverageSteps: Int? = nil

    var category: ClientNutritionActivity {
        switch dailyActivity {
        case .seated: exerciseDaysPerWeek == 0 ? .sedentary : exerciseDaysPerWeek <= 3 ? .light : .active
        case .mixed: exerciseDaysPerWeek <= 2 ? .light : .active
        case .physical: exerciseDaysPerWeek <= 3 ? .active : .veryActive
        }
    }
}

struct ClientNutritionHealthEvidence: Codable, Equatable, Sendable {
    var healthyAdultAcknowledged: Bool? = nil
    var pregnantOrBreastfeeding: Bool? = nil
    var eatingDisorderRisk: Bool? = nil
    var clinicalNutritionRequired: Bool? = nil
}

/// Pure input contract;5D can prefill only data reliably present in the existing profile.
struct ClientNutritionCoachProfile: Codable, Equatable, Sendable {
    var age: Int?
    var biologicalSex: ClientBiologicalSex?
    var weightKg: Double?
    var heightCm: Double?
    var activity: ClientNutritionActivityEvidence?
    var health: ClientNutritionHealthEvidence
    var dietaryPattern: ClientNutritionDietPattern
    var allergies: Set<ClientNutritionAllergen>
    var intolerances: Set<ClientNutritionIntolerance>
    var excludedFoodIDs: Set<UUID>
    /// Stable planning weekday for single-day plans; never inferred from current wall-clock time.
    var referenceWeekday: Int = 1
}

struct ClientNutritionCoachContext: Sendable {
    let mode: ClientConnectionMode?
    let profile: ClientNutritionCoachProfile?
}

enum ClientNutritionCoachPolicy {
    static func evaluate(_ context: ClientNutritionCoachContext, answers: ClientNutritionCreationAnswers) -> ClientNutritionGenerationEligibility {
        guard let mode = context.mode else { return .deniedUnauthenticated }
        guard ClientAccessPolicy.canManagePersonalNutritionPlans(in: mode) else { return .deniedTrainerManaged }
        guard let profile = context.profile else { return .missingRequiredProfile }
        if profile.health.pregnantOrBreastfeeding == true { return .pregnancyOrBreastfeeding }
        if profile.health.eatingDisorderRisk == true { return .eatingDisorderRisk }
        if profile.health.clinicalNutritionRequired == true { return .medicalConditionRequiresProfessional }
        guard let age = profile.age, let weight = profile.weightKg, let height = profile.heightCm,
              profile.biologicalSex != nil, let activity = profile.activity else { return .missingRequiredProfile }
        guard age >= 18 else { return .underAge }
        guard profile.health.healthyAdultAcknowledged == true,
              profile.health.pregnantOrBreastfeeding == false, profile.health.eatingDisorderRisk == false,
              profile.health.clinicalNutritionRequired == false else { return .missingRequiredProfile }
        // Narrow product applicability, NOT a diagnosis or an adjusted-body-weight calculation.
        guard (18...78).contains(age), weight.isFinite, (35...120).contains(weight),
              height.isFinite, (130...220).contains(height) else { return .invalidAnthropometrics }
        // Product applicability only, NOT disease inference or a clinical classification.
        let heightAdjustedMass = weight / pow(height / 100, 2)
        guard (15...40).contains(heightAdjustedMass) else { return .invalidAnthropometrics }
        guard (0...7).contains(activity.exerciseDaysPerWeek), (1...7).contains(profile.referenceWeekday),
              activity.reliableAverageSteps.map({ (0...100_000).contains($0) }) ?? true,
              (3...6).contains(answers.mealCount), [1, 7].contains(answers.dayCount) else { return .missingRequiredProfile }
        guard !answers.hasAllergiesOrMedicalNeeds else { return .medicalConditionRequiresProfessional }
        guard !answers.vegetarian || profile.dietaryPattern != .omnivore else { return .incompatiblePreferences }
        return .allowed
    }
}
