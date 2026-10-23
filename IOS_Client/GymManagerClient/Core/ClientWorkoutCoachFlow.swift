import Foundation

enum ClientWorkoutCoachStep: Int, CaseIterable, Sendable {
    case experience, skills, availability, equipment, goal, split, priorities, exclusions, safety, review
    var title: String {
        switch self {
        case .experience: "La tua esperienza"
        case .skills: "Tecnica e abitudini"
        case .availability: "Il tempo per te"
        case .equipment: "Dove ti alleni"
        case .goal: "Il tuo obiettivo"
        case .split: "Organizza la settimana"
        case .priorities: "A cosa dare attenzione"
        case .exclusions: "Esercizi da evitare"
        case .safety: "Prima di iniziare"
        case .review: "Le tue scelte"
        }
    }
}

struct ClientWorkoutCoachFeedback: Error, LocalizedError, Equatable, Sendable {
    let message: String
    let step: ClientWorkoutCoachStep?
    var errorDescription: String? { message }

    static func generation(_ error: Error) -> Self {
        if let feedback = error as? Self { return feedback }
        if let reason = error as? ClientWorkoutGenerationEligibility {
            let step: ClientWorkoutCoachStep?
            switch reason {
            case .invalidExperience: step = .experience
            case .invalidFrequency, .invalidDuration: step = .availability
            case .invalidProgramLength: step = .goal
            case .incompatiblePreferredSplit, .invalidCustomSplit: step = .split
            case .professionalAssessmentRequired: step = .safety
            case .noCompatibleExercises: step = .equipment
            case .missingRequiredAnswers(let missing):
                step = missing.contains(.experienceEvidence) ? .experience : missing.contains(.equipmentInventory) ? .equipment : .safety
            case .allowed, .deniedUnauthenticated, .deniedTrainerManaged: step = nil
            }
            return Self(message: reason.errorDescription ?? "Controlla le tue scelte.", step: step)
        }
        if let reason = error as? ClientWorkoutGeneratorError {
            switch reason {
            case .unsafeLimitations: return Self(message: reason.errorDescription ?? "", step: .safety)
            case .emptyCatalog: return Self(message: "Il catalogo non è disponibile. Ricaricalo prima di creare la scheda.", step: .equipment)
            case .insufficientCompatibleExercises:
                return Self(message: "Mancano varianti verificate per coprire i movimenti con questa attrezzatura e queste esclusioni. Rivedi gli esercizi esclusi o l'attrezzatura; non abbiamo aggiunto esercizi non verificati.", step: .exclusions)
            case .inconsistentPlan(let issues):
                let names = issues.compactMap { ClientWorkoutValidationIssue(rawValue: $0) }.map(editIssue)
                return Self(message: names.isEmpty
                    ? "Le scelte non permettono un programma coerente con il catalogo disponibile. Rivedi split, attrezzatura o esclusioni."
                    : names.joined(separator: " "), step: issues.contains("duration") || issues.contains("volume") ? .availability : .split)
            }
        }
        return Self(message: "La scheda non è stata creata. Le risposte sono ancora qui: controlla il catalogo e riprova.", step: .review)
    }

    static func editIssue(_ issue: ClientWorkoutValidationIssue) -> String {
        switch issue {
        case .answers: "Le preferenze originali sono incomplete: torna al questionario."
        case .days: "Mantieni il numero di sessioni e giorni distinti; assegna un nome a ogni sessione."
        case .catalog: "Un esercizio non corrisponde più ai dati verificati del catalogo."
        case .equipment: "Un esercizio richiede attrezzatura diversa da quella scelta."
        case .exclusions: "Un esercizio escluso non può essere reinserito."
        case .coverage: "La settimana non copre più tutti i gruppi principali."
        case .volume: "Il volume settimanale è fuori dai limiti del programma: rivedi serie ed esercizi."
        case .duration: "Una sessione supera il tempo disponibile: riduci serie o esercizi."
        case .duplicates: "Rimuovi gli esercizi duplicati nella stessa sessione."
        case .movement: "Ripristina l'equilibrio tra spinta, tirata, gambe e catena posteriore."
        case .order: "Sposta i multiarticolari prima degli esercizi di isolamento."
        case .recovery: "Distanzia i giorni che concentrano molto lavoro sugli stessi gruppi."
        case .prescription: "Usa 1–5 serie, ripetizioni valide, recupero 45–300 secondi (almeno 90 per i multiarticolari) e RIR 1–4; il carico si registra allenandoti."
        case .metadata: "I dati originali del programma non sono verificabili. Non sono stati sovrascritti: riparti dalle preferenze."
        }
    }
}

/// View-owned input only: evidence and mandatory choices start UNANSWERED.
/// Defaults inside questionnaire answers are never accepted as user evidence.
struct ClientWorkoutCoachDraft {
    var totalMonths = ""
    var recentMonths = ""
    var recentFrequency: Int?
    var perceivedLevel: ClientTrainingExperience?
    var compoundFamiliarity: Bool?
    var canUseRIR: Bool?
    var hasUsedProgression: Bool?
    var frequency: Int?
    var minutes: Int?
    var equipment: ClientTrainingEquipment?
    var inventory: Set<ClientWorkoutEquipmentItem> = []
    var goal: ClientTrainingGoal?
    var phase: ClientNutritionPhase?
    var weeks: Int?
    var split: ClientWorkoutSplitPreference?
    var customGroups: [[ClientMuscleRegion]] = []
    var priorities: Set<ClientMuscleRegion> = []
    var excludedIDs: Set<UUID> = []
    var acknowledgement: Bool? = nil
    var limitations = ""

    static func visibleCatalogRows(_ catalog: [ClientExerciseCatalogItem]) -> [ClientExerciseCatalogItem] {
        Dictionary(grouping: catalog, by: \.id).values.compactMap { rows in
            guard let first = rows.first, rows.allSatisfy({ $0 == first }) else { return nil }
            return first
        }.sorted { $0.name == $1.name ? $0.id.uuidString < $1.id.uuidString : $0.name < $1.name }
    }

    var evidence: ClientWorkoutExperienceEvidence? {
        guard let total = Int(totalMonths), let recent = Int(recentMonths), let count = recentFrequency,
              let compound = compoundFamiliarity, let rir = canUseRIR, let progression = hasUsedProgression else { return nil }
        return .init(totalMonths: total, recentConsistentMonths: recent, recentSessionsPerWeek: count,
                     compoundFamiliarity: compound, canUseRIR: rir, hasUsedLoadProgression: progression)
    }
    var effectiveLevel: ClientTrainingExperience? {
        guard let evidence, evidence.isValid, let perceivedLevel else { return nil }
        return evidence.classified(cappedAt: perceivedLevel)
    }

    private var catalogAnswers: ClientWorkoutQuestionnaireAnswers {
        // ONLY for fail-closed catalog admission, never a generation path.
        var value = ClientWorkoutQuestionnaireAnswers()
        value.experience = perceivedLevel ?? .beginner
        value.experienceEvidence = evidence
        value.equipment = equipment ?? .fullGym
        value.equipmentInventory = inventory
        value.avoidedExerciseIDs = excludedIDs
        return value
    }

    func availableEquipment(in catalog: [ClientExerciseCatalogItem]) -> [ClientTrainingEquipment] {
        ClientTrainingEquipment.allCases.filter { category in
            var value = catalogAnswers
            value.equipment = category
            value.equipmentInventory = category == .homeGym
                ? Set(ClientWorkoutEquipmentItem.allCases).subtracting([.cables, .machines])
                : [.floor, .bands, .pullupBar]
            let candidates = (try? ClientWorkoutCatalogPolicy.admit(catalog, answers: value, level: effectiveLevel ?? .beginner).candidates) ?? []
            return Self.hasRequiredCoverage(candidates)
        }
    }
    func verifiedInventory(in catalog: [ClientExerciseCatalogItem]) -> [ClientWorkoutEquipmentItem] {
        var value = catalogAnswers; value.equipment = .fullGym
        let candidates = (try? ClientWorkoutCatalogPolicy.admit(catalog, answers: value, level: effectiveLevel ?? .beginner).candidates) ?? []
        return ClientWorkoutEquipmentItem.allCases.filter { equipment in
            ![.machines,.cables].contains(equipment) && candidates.contains { $0.review.sourceKey != nil && $0.review.required.contains(equipment) }
        }
    }
    private static func hasRequiredCoverage(_ candidates: [ClientWorkoutCatalogPolicy.Candidate]) -> Bool {
        let coverage = ClientWorkoutVolumeMetrics(exercises: candidates.map { ClientWorkoutCoachEditingContext.exercise($0) }).coverage
        let patterns = Set(candidates.filter { $0.review.kind == .compound }.map { $0.review.pattern })
        return candidates.count >= 3 && ClientMuscleRegion.majorGroups.isSubset(of: coverage)
            && patterns.contains(.horizontalPush) && patterns.contains(.kneeDominant) && patterns.contains(.hipHinge)
            && (!patterns.isDisjoint(with: [.horizontalPull,.verticalPull]))
    }
    mutating func resizeCustomSplit() {
        let count = frequency ?? 0
        while customGroups.count < count { customGroups.append([]) }
        // Preserve hidden later-day answers if the user temporarily reduces frequency.
    }
    func isSplitAvailable(_ option: ClientWorkoutSplitPreference) -> Bool {
        if option == .custom { return true } // Its groups are collected only after selection.
        var probe = self; probe.split = option
        return probe.issue(at: .split, catalog: []) == nil
    }

    func issue(at step: ClientWorkoutCoachStep, catalog: [ClientExerciseCatalogItem]) -> ClientWorkoutCoachFeedback? {
        func problem(_ text: String) -> ClientWorkoutCoachFeedback { .init(message: text, step: step) }
        switch step {
        case .experience:
            guard let total = Int(totalMonths), let recent = Int(recentMonths), let recentFrequency,
                  perceivedLevel != nil else { return problem("Indica mesi totali, continuità recente, frequenza recente e livello percepito. Zero è una risposta valida.") }
            if !(0...600).contains(total) || !(0...total).contains(recent) || !(0...7).contains(recentFrequency) {
                return problem("La continuità recente non può superare l'esperienza totale. Usa valori da 0 a 600 mesi.")
            }
        case .skills:
            if compoundFamiliarity == nil || canUseRIR == nil || hasUsedProgression == nil { return problem("Rispondi alle tre domande: anche No è una risposta utile.") }
        case .availability:
            if !(2...6).contains(frequency ?? 0) || ![30,45,60,75,90].contains(minutes ?? 0) { return problem("Scegli 2–6 giorni settimanali e una durata disponibile.") }
        case .equipment:
            guard let equipment, availableEquipment(in: catalog).contains(equipment) else { return problem("Scegli un contesto supportato dal catalogo verificato. Se non ne compare nessuno, ricarica il catalogo o rivedi le esclusioni.") }
            let candidates = (try? ClientWorkoutCatalogPolicy.admit(catalog, answers: catalogAnswers, level: effectiveLevel ?? .beginner).candidates) ?? []
            if equipment != .fullGym && inventory.isEmpty { return problem("Indica l'attrezzatura che hai davvero a disposizione.") }
            if !Self.hasRequiredCoverage(candidates) { return problem("Con questa attrezzatura e queste esclusioni mancano movimenti verificati per una settimana completa. Rivedi la selezione.") }
        case .goal:
            if goal == nil || phase == nil || ![4,6,8,12].contains(weeks ?? 0) { return problem("Scegli obiettivo, fase attuale e durata del programma.") }
        case .split:
            guard let split else { return problem("Scegli uno split oppure Decidi tu.") }
            if split == .fullBody && (frequency ?? 0) > 3 { return problem("Full Body è supportato fino a 3 giorni. Scegli Decidi tu o Upper / Lower.") }
            if [.upperLower,.pushPullLegs].contains(split) && (frequency ?? 0) < 3 { return problem("Con 2 giorni scegli Decidi tu o Full Body.") }
            if split == .custom {
                let groups = Array(customGroups.prefix(max(0, frequency ?? 0)))
                if groups.count != (frequency ?? 0) || groups.contains(where: { $0.isEmpty }) || !ClientMuscleRegion.majorGroups.isSubset(of: Set(groups.flatMap { $0 })) {
                    return problem("Assegna gruppi a ogni giornata e copri l'intera settimana, oppure scegli Decidi tu.")
                }
            }
        case .safety:
            if acknowledgement != true { return problem("Conferma che stai cercando attività fitness generale per adulti sani, non riabilitazione.") }
        case .priorities, .exclusions, .review: break
        }
        return nil
    }
    func completeAnswers(catalog: [ClientExerciseCatalogItem]) throws -> ClientWorkoutQuestionnaireAnswers {
        for step in ClientWorkoutCoachStep.allCases {
            if let issue = issue(at: step, catalog: catalog) { throw issue }
        }
        guard let perceivedLevel, let evidence, let frequency, let minutes, let equipment,
              let goal, let phase, let weeks, let split, acknowledgement == true else {
            throw ClientWorkoutCoachFeedback(message: "Completa le scelte prima di generare.", step: .experience)
        }
        var value = ClientWorkoutQuestionnaireAnswers()
        value.experience = perceivedLevel; value.experienceEvidence = evidence
        value.weeklyFrequency = frequency; value.sessionDurationMinutes = minutes
        value.equipment = equipment; value.equipmentInventory = inventory
        value.goal = goal; value.nutritionPhase = phase; value.durationWeeks = weeks
        value.splitPreference = split; value.customSplitGroups = Array(customGroups.prefix(frequency))
        value.priorityMuscles = priorities; value.avoidedExerciseIDs = excludedIDs; value.avoidedExerciseNames = []
        value.healthyAdultAcknowledged = acknowledgement; value.limitations = limitations
        let reason = ClientWorkoutGenerationPolicy.validateAnswers(value)
        guard reason == .allowed else { throw reason }
        return value
    }
}

enum ClientWorkoutCoachSaveState: Equatable {
    case localDraft, saving, confirmed(demo: Bool), failure(String)
    var message: String {
        switch self {
        case .localDraft: "Bozza: non ancora confermata dal database."
        case .saving: "Salvataggio e verifica…"
        case .confirmed(let demo): demo ? "Scheda salvata solo nella modalità demo." : "Scheda salvata e riletta dal server."
        case .failure(let detail): detail
        }
    }
}

extension ClientWorkoutStrategy {
    var coachTitle: String {
        switch self {
        case .fullBody: "Full Body"
        case .upperLower: "Upper / Lower"
        case .pushPullLegs: "Push / Pull / Legs"
        case .hybrid: "Split combinato"
        case .custom: "Split personale"
        }
    }
}

enum ClientWorkoutCoachExplanation {
    static func lines(for plan: ClientPersonalWorkoutPlan) -> [String] {
        guard let metadata = plan.generationMetadata, let answers = plan.generationAnswers else { return [] }
        var reasons = [
            "Abbiamo scelto \(metadata.strategy.coachTitle) considerando \(answers.weeklyFrequency) allenamenti da circa \(answers.sessionDurationMinutes) minuti e la tua esperienza.",
            "Il programma parte dal livello stimato \(metadata.effectiveExperience.displayName.lowercased()). Le durate sono stime che comprendono i recuperi.",
            "Quando completi tutte le serie al limite alto con il RIR indicato, puoi valutare un aumento graduale del carico. Nessun peso viene inventato."
        ]
        if !answers.priorityMuscles.isEmpty {
            reasons.append("Abbiamo dato maggiore attenzione a: " + answers.priorityMuscles.map(\.displayName).sorted().joined(separator: ", ") + ".")
        }
        if !(answers.avoidedExerciseIDs ?? []).isEmpty { reasons.append("Gli esercizi che hai escluso non sono stati selezionati.") }
        return reasons
    }
}
