import Foundation
import CryptoKit

struct ClientPlanEditProvenance: Codable, Equatable, Sendable {
    static let version = "smart-plan-edit-1.0.0"
    let editorVersion: String
    let generatorVersion: String
    let originalPlanSignature: String
    let generationMetadataSignature: String
    var currentPlanSignature: String
    var revision: Int
    var nutritionLayout: ClientNutritionEditingLayout? = nil
    var hasUserEdits: Bool { revision > 0 }
}

enum ClientSmartPlanEditError: Error, LocalizedError, Sendable {
    case invalidOriginal, missingTarget, noCompatibleAlternative, stalePreview, invalidEdit
    case rebalanceConsentRequired, portionBoundsPreventMatch, accountChanged
    var errorDescription: String? {
        switch self {
        case .invalidOriginal: "Il piano di partenza non supera i controlli. Nessuna modifica applicata."
        case .missingTarget: "L'elemento da sostituire non è più presente."
        case .noCompatibleAlternative: "Non ci sono alternative verificate che mantengano valido questo piano."
        case .stalePreview: "Il piano o il catalogo è cambiato: aggiorna le alternative prima di confermare."
        case .invalidEdit: "La modifica non rispetta i vincoli del piano. Controlla il riepilogo."
        case .rebalanceConsentRequired: "La proposta modifica anche altre quantità: conferma prima tutte le variazioni."
        case .portionBoundsPreventMatch: "Non è possibile ottenere una porzione simile entro i limiti verificati dell'alimento."
        case .accountChanged: "L'account è cambiato: riapri la modifica dalla tua libreria."
        }
    }
}

/// Structural fingerprints are audit/stale-preview aids, NEVER authorization or medical certification.
enum ClientSmartPlanFingerprint {
    private static let unorderedKeys: Set<String> = [
        "priorityMuscles","equipmentInventory","avoidedExerciseIDs","excludedFoodIDs","allergies","intolerances",
        "compatibleEquipment","roles","allowedMeals","compatiblePatterns","assessedAllergens","containsAllergens",
        "traceAllergens","assessedIntolerances","incompatibleIntolerances"
    ]
    static func encode<Value: Encodable>(_ value: Value, excluding: Set<String> = []) -> String? {
        guard let data = try? JSONEncoder().encode(value),
              let object = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]) else { return nil }
        func normalized(_ object: Any, key: String = "") -> Any {
            if let dictionary = object as? [String: Any] {
                return dictionary.filter { !excluding.contains($0.key) }
                    .reduce(into: [String: Any]()) { result, entry in result[entry.key] = normalized(entry.value, key: entry.key) }
            }
            if let array = object as? [Any] {
                let values = array.map { normalized($0) }
                if unorderedKeys.contains(key) {
                    return values.sorted {
                        let a = (try? JSONSerialization.data(withJSONObject: $0, options: [.sortedKeys,.fragmentsAllowed])) ?? Data()
                        let b = (try? JSONSerialization.data(withJSONObject: $1, options: [.sortedKeys,.fragmentsAllowed])) ?? Data()
                        return a.lexicographicallyPrecedes(b)
                    }
                }
                return values
            }
            return object
        }
        guard let canonical = try? JSONSerialization.data(withJSONObject: normalized(object), options: [.sortedKeys,.fragmentsAllowed]) else { return nil }
        return SHA256.hash(data: canonical).map { String(format: "%02x", $0) }.joined()
    }
    static func workout(_ plan: ClientPersonalWorkoutPlan) -> String? {
        encode(plan, excluding: ["id","createdAt","updatedAt","status","editProvenance","validation"])
    }
    static func nutrition(_ plan: ClientPersonalNutritionPlan, layout: ClientNutritionEditingLayout) -> String? {
        guard let content = encode(plan, excluding: ["id","createdAt","updatedAt","status","editProvenance"]),
              let distribution = encode(layout) else { return nil }
        return encode([content, distribution])
    }
    static func workoutOrigin(_ plan: ClientPersonalWorkoutPlan) -> String? {
        struct Origin: Encodable {
            let metadata: ClientWorkoutGenerationMetadata?
            let answers: ClientWorkoutQuestionnaireAnswers?
            let progression: ClientWorkoutProgressionRule?
        }
        return encode(Origin(metadata: plan.generationMetadata, answers: plan.generationAnswers, progression: plan.progression),
                      excluding: ["estimatedSessionMinutes"])
    }
    static func nutritionOrigin(_ plan: ClientPersonalNutritionPlan) -> String? {
        struct Origin: Encodable {
            let metadata: ClientNutritionGenerationMetadata?
            let answers: ClientNutritionCreationAnswers?
            let target: ClientNutritionTarget?
        }
        return encode(Origin(metadata: plan.generationMetadata, answers: plan.creationAnswers, target: plan.target))
    }
}

enum ClientPlanEditing {
    static func beginWorkout(_ original: ClientPersonalWorkoutPlan) -> ClientPersonalWorkoutPlan {
        guard original.editProvenance == nil, let metadata = original.generationMetadata,
              let signature = ClientSmartPlanFingerprint.workout(original),
              let origin = ClientSmartPlanFingerprint.workoutOrigin(original) else { return original }
        var plan = original
        plan.editProvenance = .init(editorVersion: ClientPlanEditProvenance.version, generatorVersion: metadata.generatorVersion,
            originalPlanSignature: signature, generationMetadataSignature: origin, currentPlanSignature: signature, revision: 0)
        return plan
    }
    static func refreshWorkout(_ original: ClientPersonalWorkoutPlan) -> ClientPersonalWorkoutPlan? {
        var plan = beginWorkout(original)
        guard var provenance = plan.editProvenance, provenance.nutritionLayout == nil,
              provenance.editorVersion == ClientPlanEditProvenance.version,
              provenance.generatorVersion == plan.generationMetadata?.generatorVersion,
              provenance.generationMetadataSignature == ClientSmartPlanFingerprint.workoutOrigin(plan),
              !provenance.originalPlanSignature.isEmpty, (0...10_000).contains(provenance.revision),
              let signature = ClientSmartPlanFingerprint.workout(plan) else { return nil }
        if provenance.revision == 0 && provenance.originalPlanSignature != provenance.currentPlanSignature { return nil }
        if provenance.currentPlanSignature != signature {
            guard provenance.revision < 10_000 else { return nil }
            provenance.revision += 1
            provenance.currentPlanSignature = signature
        }
        plan.editProvenance = provenance
        return plan
    }
    static func beginNutrition(_ original: ClientPersonalNutritionPlan) -> ClientPersonalNutritionPlan {
        guard original.editProvenance == nil, let metadata = original.generationMetadata,
              let layout = ClientNutritionEditingLayout.generated(original),
              let signature = ClientSmartPlanFingerprint.nutrition(original, layout: layout),
              let origin = ClientSmartPlanFingerprint.nutritionOrigin(original) else { return original }
        var plan = original
        plan.editProvenance = .init(editorVersion: ClientPlanEditProvenance.version, generatorVersion: metadata.generatorVersion,
            originalPlanSignature: signature, generationMetadataSignature: origin, currentPlanSignature: signature,
            revision: 0, nutritionLayout: layout)
        return plan
    }
}
