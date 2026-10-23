import Foundation

/// Presentation contract only. All eligibility, energy, food and fit rules remain in5C.
enum ClientNutritionCoachStep: Int, CaseIterable, Sendable {
    case profile, activity, training, goal, preferences, safety, meals, review
    var title: String {
        switch self {
        case .profile: "Partiamo da te"
        case .activity: "La tua giornata"
        case .training: "Il tuo allenamento"
        case .goal: "Il tuo obiettivo"
        case .preferences: "Come preferisci mangiare?"
        case .safety: "Sicurezza e alimenti esclusi"
        case .meals: "Organizza i pasti"
        case .review: "La tua proposta"
        }
    }
}

struct ClientNutritionCoachInputs: Equatable, Sendable {
    var age: Int?
    var biologicalSex: ClientBiologicalSex?
    var heightCm: Double?
    var weightKg: Double?
    var dailyActivity: ClientNutritionDailyActivity?
    var exerciseDays: Int?
    var phase: ClientNutritionPhase?
    var pattern: ClientNutritionDietPattern?
    var health = ClientNutritionHealthEvidence()
    var allergies: Set<ClientNutritionAllergen> = []
    var intolerances: Set<ClientNutritionIntolerance> = []
    var excludedFoodIDs: Set<UUID> = []
    var dietarySafetyReviewed = false
    var mealCount: Int?
    var dayCount: Int?
    var referenceWeekday = 1
    var reusedSex = false
    var reusedWeight = false

    /// Only explicit reliable profile evidence. No guessed demographics/activity/health consent.
    mutating func reuse(biologicalSex knownSex: ClientBiologicalSex?) {
        if biologicalSex == nil, let knownSex { biologicalSex = knownSex; reusedSex = true }
    }
    /// Only today's explicit progress measurement; never silently reuse an old/stale weight.
    mutating func reuse(weight: Double?, recordedAt: Date, now: Date = Date(), calendar: Calendar = .current) {
        guard weightKg == nil, let weight, weight.isFinite, weight > 0, recordedAt <= now,
              calendar.isDate(recordedAt, inSameDayAs: now) else { return }
        weightKg = weight; reusedWeight = true
    }
    var answers: ClientNutritionCreationAnswers {
        var result = ClientNutritionCreationAnswers()
        result.age = age; result.biologicalSex = biologicalSex; result.heightCm = heightCm; result.weightKg = weightKg
        result.phase = phase ?? .maintenance; result.mealCount = mealCount ?? 0; result.dayCount = dayCount ?? 0
        result.vegetarian = pattern == .vegetarian || pattern == .vegan
        result.excludedFoodIDs = excludedFoodIDs.sorted { $0.uuidString < $1.uuidString }
        result.healthyAdultConfirmed = health.healthyAdultAcknowledged == true
        result.coachProfile = .init(age: age, biologicalSex: biologicalSex, weightKg: weightKg, heightCm: heightCm,
            activity: dailyActivity.flatMap { activity in exerciseDays.map { .init(dailyActivity: activity, exerciseDaysPerWeek: $0) } },
            health: health, dietaryPattern: pattern ?? .omnivore, allergies: allergies,
            intolerances: intolerances, excludedFoodIDs: excludedFoodIDs, referenceWeekday: referenceWeekday)
        return result
    }
    func missingStep() -> ClientNutritionCoachStep? {
        if age == nil || biologicalSex == nil || heightCm == nil || weightKg == nil { return .profile }
        if dailyActivity == nil { return .activity }
        if exerciseDays == nil { return .training }
        if phase == nil { return .goal }
        if pattern == nil { return .preferences }
        if !dietarySafetyReviewed || health.healthyAdultAcknowledged == nil || health.pregnantOrBreastfeeding == nil ||
            health.eatingDisorderRisk == nil || health.clinicalNutritionRequired == nil { return .safety }
        if mealCount == nil || dayCount == nil { return .meals }
        return nil
    }
    func eligibility(mode: ClientConnectionMode?) -> ClientNutritionGenerationEligibility {
        guard let mode else { return .deniedUnauthenticated }
        guard ClientAccessPolicy.canManagePersonalNutritionPlans(in: mode) else { return .deniedTrainerManaged }
        if health.pregnantOrBreastfeeding == true { return .pregnancyOrBreastfeeding }
        if health.eatingDisorderRisk == true { return .eatingDisorderRisk }
        if health.clinicalNutritionRequired == true || health.healthyAdultAcknowledged == false { return .medicalConditionRequiresProfessional }
        if let age, age < 18 { return .underAge }
        guard missingStep() == nil else { return .missingRequiredProfile }
        return ClientNutritionCoachPolicy.evaluate(.init(mode: mode, profile: answers.coachProfile), answers: answers)
    }
    func target(mode: ClientConnectionMode?) throws -> ClientNutritionEnergyCalculation {
        let reason = eligibility(mode: mode)
        guard reason == .allowed else { throw reason }
        guard let profile = answers.coachProfile, let phase else { throw ClientNutritionGenerationEligibility.missingRequiredProfile }
        return try ClientNutritionCoachEnergy.calculate(profile: profile, phase: phase)
    }
    func canAdvance(from step: ClientNutritionCoachStep) -> Bool {
        switch step {
        case .profile: age != nil && biologicalSex != nil && heightCm != nil && weightKg != nil
        case .activity: dailyActivity != nil
        case .training: exerciseDays != nil
        case .goal: phase != nil
        case .preferences: pattern != nil
        case .safety: dietarySafetyReviewed && health.healthyAdultAcknowledged != nil && health.pregnantOrBreastfeeding != nil && health.eatingDisorderRisk != nil && health.clinicalNutritionRequired != nil
        case .meals: mealCount != nil && dayCount != nil
        case .review: missingStep() == nil
        }
    }
}

enum ClientNutritionCoachFeedback {
    static func correction(_ reason: ClientNutritionGenerationEligibility, inputs: ClientNutritionCoachInputs) -> ClientNutritionCoachStep? {
        switch reason {
        case .missingRequiredProfile: inputs.missingStep() ?? .profile
        case .underAge, .invalidAnthropometrics: .profile
        case .pregnancyOrBreastfeeding, .eatingDisorderRisk, .medicalConditionRequiresProfessional, .allergyConflict: .safety
        case .unsupportedGoal, .energyTargetUnsafe: .goal
        case .incompatiblePreferences: .preferences
        case .fitFailed: .meals
        case .allowed, .deniedUnauthenticated, .deniedTrainerManaged, .insufficientFoodData, .invalidPlan: nil
        }
    }
    static func issues(_ issues: Set<ClientNutritionPlanIssue>) -> [String] {
        let labels: [(ClientNutritionPlanIssue, String)] = [
            (.eligibility,"Verifica profilo e condizioni per la generazione."), (.metadata,"La base del piano non è più verificabile. Riapri il piano o rigeneralo esplicitamente."),
            (.target,"Il target non supera i controlli del motore."), (.catalog,"Il catalogo verificato è cambiato o incompleto. Aggiornalo e ricontrolla il piano."),
            (.food,"Controlla compatibilità, dati e composizione degli alimenti."), (.preference,"Un alimento non rispetta le preferenze o le esclusioni."),
            (.portions,"Correggi le quantità rispettando porzioni e pezzi interi."), (.days,"Mantieni i giorni previsti dal piano originale."),
            (.meals,"Controlla nomi, numero pasti, ruoli e distribuzione giornaliera."), (.mealTotals,"La distribuzione di energia o proteine di un pasto è da correggere."),
            (.dayTotals,"I totali giornalieri sono fuori dai limiti del piano."), (.duplicate,"Rimuovi gli alimenti duplicati nello stesso pasto.")]
        return labels.filter { issues.contains($0.0) }.map(\.1)
    }
    static func signed(_ value: Double, unit: String) -> String {
        let rounded = value.rounded()
        return "\(rounded > 0 ? "+" : "")\(rounded == 0 ? "0" : rounded.formatted(.number.precision(.fractionLength(0)))) \(unit)"
    }
}

enum ClientNutritionCoachSaveState: Equatable {
    case localDraft, saving, confirmed(demo: Bool), failure(String)
    var isConfirmed: Bool { if case .confirmed = self { true } else { false } }
}

enum ClientNutritionCoachOwnership {
    /// App-layer guard only; the repository and backend RLS remain mandatory.
    static func check(actualOwnerID: UUID?, expectedOwnerID: UUID?, mode: ClientConnectionMode?) throws {
        guard let actualOwnerID, let mode else { throw ClientNutritionGenerationEligibility.deniedUnauthenticated }
        guard actualOwnerID == expectedOwnerID else { throw ClientSmartPlanEditError.accountChanged }
        guard ClientAccessPolicy.canManagePersonalNutritionPlans(in: mode) else { throw ClientNutritionGenerationEligibility.deniedTrainerManaged }
    }
}

extension ClientNutritionDietPattern {
    var title: String { switch self { case .omnivore: "Onnivoro"; case .vegetarian: "Vegetariano"; case .vegan: "Vegano" } }
}
extension ClientNutritionAllergen {
    var title: String {
        switch self {
        case .glutenCereals: "Cereali con glutine"; case .crustaceans: "Crostacei"; case .eggs: "Uova"; case .fish: "Pesce"
        case .peanuts: "Arachidi"; case .soy: "Soia"; case .milk: "Latte"; case .treeNuts: "Frutta a guscio"
        case .celery: "Sedano"; case .mustard: "Senape"; case .sesame: "Sesamo"; case .sulphites: "Solfiti"; case .lupin: "Lupini"; case .molluscs: "Molluschi"
        }
    }
}
extension ClientNutritionIntolerance { var title: String { self == .lactose ? "Lattosio" : "Glutine" } }
