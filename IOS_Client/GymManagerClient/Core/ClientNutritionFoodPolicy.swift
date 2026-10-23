import Foundation
import CryptoKit

enum ClientNutritionFoodSource: String, Codable, CaseIterable, Sendable {
    case crea, usda, openFoodFacts = "open_food_facts"
    var priority: Int { switch self { case .crea: 0; case .usda: 1; case .openFoodFacts: 2 } }
}
enum ClientNutritionFoodRole: String, Codable, CaseIterable, Hashable, Sendable {
    case protein, carbohydrate, fat, vegetable, fruit, dairyAlternative, mixed
}
enum ClientNutritionMealOccasion: String, Codable, CaseIterable, Hashable, Sendable { case breakfast, main, snack }

struct ClientNutritionPortionBounds: Codable, Equatable, Sendable {
    let minimumGrams: Double
    let maximumGrams: Double
    let stepGrams: Double
    var isValid: Bool {
        [minimumGrams, maximumGrams, stepGrams].allSatisfy { $0.isFinite && $0 > 0 } &&
            minimumGrams <= maximumGrams && maximumGrams <= 1000 &&
            maximumGrams / stepGrams <= 1000 &&
            abs(minimumGrams / stepGrams - (minimumGrams / stepGrams).rounded()) < 0.000001 &&
            abs(maximumGrams / stepGrams - (maximumGrams / stepGrams).rounded()) < 0.000001
    }
    func contains(_ grams: Double) -> Bool {
        isValid && grams.isFinite && grams >= minimumGrams - 0.000001 && grams <= maximumGrams + 0.000001 &&
            abs(grams / stepGrams - (grams / stepGrams).rounded()) < 0.000001
    }
}

/// An upstream, source-grounded review is REQUIRED. A provider/category/name is not this review.
/// Legacy food_references rows without this review remain manual-only.
struct ClientNutritionFoodEvidence: Codable, Equatable, Sendable {
    let reviewVersion: String
    let reviewReference: String
    let canonicalID: UUID
    let source: ClientNutritionFoodSource
    let sourceID: String
    let sourceURL: String
    let datasetRevision: String
    let cacheProvenance: String
    let cacheRevision: String
    let sourceServingAmount: Double
    let sourceServingUnit: String
    let foodState: String
    let roles: Set<ClientNutritionFoodRole>
    let allowedMeals: Set<ClientNutritionMealOccasion>
    let compatiblePatterns: Set<ClientNutritionDietPattern>
    let assessedAllergens: Set<ClientNutritionAllergen>
    let containsAllergens: Set<ClientNutritionAllergen>
    let traceAllergens: Set<ClientNutritionAllergen>
    let assessedIntolerances: Set<ClientNutritionIntolerance>
    let incompatibleIntolerances: Set<ClientNutritionIntolerance>
    let portion: ClientNutritionPortionBounds
}

enum ClientNutritionFoodPolicy {
    static func valid(_ item: ClientFoodCatalogItem) -> Bool {
        guard let evidence = item.nutritionEvidence,
              evidence.reviewVersion == ClientNutritionCoachRules.foodReviewVersion,
              evidence.canonicalID == item.id,
              item.provider == evidence.source.rawValue,
              !item.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              [evidence.sourceID, evidence.datasetRevision, evidence.cacheProvenance, evidence.cacheRevision, evidence.reviewReference, evidence.foodState]
                .allSatisfy({ !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }),
              let url = URL(string: evidence.sourceURL), url.scheme == "https", url.host != nil,
              evidence.sourceServingAmount.isFinite, evidence.sourceServingAmount > 0,
              ["g", "pz"].contains(evidence.sourceServingUnit),
              !evidence.roles.isEmpty, !evidence.allowedMeals.isEmpty, !evidence.compatiblePatterns.isEmpty,
              evidence.assessedAllergens == Set(ClientNutritionAllergen.allCases),
              evidence.assessedIntolerances == Set(ClientNutritionIntolerance.allCases),
              evidence.portion.isValid,
              let p = item.proteinPer100g, let c = item.carbsPer100g, let f = item.fatPer100g,
              [p, c, f].allSatisfy({ $0.isFinite && (0...100).contains($0) }),
              p + c + f <= 105, item.caloriesPer100g.isFinite, (1...950).contains(item.caloriesPer100g) else { return false }
        // Stored provider kcal remains authoritative (fiber/polyol/specific Atwater differ).
        // Large contradictions are data-quality failures, not silently reconstructed values.
        let reconstructed = p * 4 + c * 4 + f * 9
        guard abs(reconstructed - item.caloriesPer100g) <= max(20, item.caloriesPer100g * 0.25) else { return false }
        let animalAllergens: Set<ClientNutritionAllergen> = [.milk, .eggs, .fish, .crustaceans, .molluscs]
        if evidence.compatiblePatterns.contains(.vegan), !evidence.containsAllergens.isDisjoint(with: animalAllergens) { return false }
        if evidence.compatiblePatterns.contains(.vegetarian),
           !evidence.containsAllergens.isDisjoint(with: [.fish, .crustaceans, .molluscs]) { return false }
        if let piece = item.gramsPerPiece {
            guard piece.isFinite, piece > 0,
                  abs(evidence.portion.stepGrams / piece - (evidence.portion.stepGrams / piece).rounded()) < 0.000001 else { return false }
        } else {
            guard evidence.sourceServingUnit != "pz", [5.0, 10.0].contains(evidence.portion.stepGrams) else { return false }
        }
        return true
    }

    static func compatible(_ item: ClientFoodCatalogItem, profile: ClientNutritionCoachProfile) -> Bool {
        guard valid(item), let evidence = item.nutritionEvidence else { return false }
        return !profile.excludedFoodIDs.contains(item.id) &&
            evidence.compatiblePatterns.contains(profile.dietaryPattern) &&
            profile.allergies.isDisjoint(with: evidence.containsAllergens.union(evidence.traceAllergens)) &&
            profile.intolerances.isDisjoint(with: evidence.incompatibleIntolerances)
    }

    static func admit(_ catalog: [ClientFoodCatalogItem], profile: ClientNutritionCoachProfile,
                      excluded: Set<UUID>) -> [ClientFoodCatalogItem] {
        // Conflicting identical canonical IDs OR provider IDs are quarantined, never first-wins.
        let byID = Dictionary(grouping: catalog, by: \.id)
        let consistent = byID.values.compactMap { rows -> ClientFoodCatalogItem? in
            guard let first = rows.first, rows.allSatisfy({ $0 == first }) else { return nil }
            return first
        }
        let sourceGroups = Dictionary(grouping: consistent) { item in
            (item.nutritionEvidence?.source.rawValue ?? "") + ":" + (item.nutritionEvidence?.sourceID ?? "")
        }
        return consistent.filter { item in
            guard let e = item.nutritionEvidence else { return false }
            return sourceGroups[e.source.rawValue + ":" + e.sourceID]?.count == 1 &&
                !excluded.contains(item.id) && compatible(item, profile: profile)
        }.sorted {
            let a = $0.nutritionEvidence!, b = $1.nutritionEvidence!
            if a.source.priority != b.source.priority { return a.source.priority < b.source.priority }
            return $0.id.uuidString < $1.id.uuidString
        }
    }

    static func fingerprint(_ catalog: [ClientFoodCatalogItem]) -> String {
        digest(catalog.sorted { $0.id.uuidString < $1.id.uuidString }.map { item in
            guard let e = item.nutritionEvidence else { return item.id.uuidString + ":unreviewed" }
            return [
                item.id.uuidString, item.name, item.provider ?? "", String(item.caloriesPer100g),
                String(item.proteinPer100g ?? -1), String(item.carbsPer100g ?? -1), String(item.fatPer100g ?? -1),
                String(item.gramsPerPiece ?? -1), e.source.rawValue, e.sourceID, e.sourceURL, e.reviewVersion,
                e.reviewReference, e.datasetRevision, e.cacheProvenance, e.cacheRevision, String(e.sourceServingAmount),
                e.sourceServingUnit, e.foodState, e.roles.map(\.rawValue).sorted().joined(separator: ","),
                e.allowedMeals.map(\.rawValue).sorted().joined(separator: ","),
                e.compatiblePatterns.map(\.rawValue).sorted().joined(separator: ","),
                e.assessedAllergens.map(\.rawValue).sorted().joined(separator: ","),
                e.containsAllergens.map(\.rawValue).sorted().joined(separator: ","),
                e.traceAllergens.map(\.rawValue).sorted().joined(separator: ","),
                e.assessedIntolerances.map(\.rawValue).sorted().joined(separator: ","),
                e.incompatibleIntolerances.map(\.rawValue).sorted().joined(separator: ","),
                String(e.portion.minimumGrams), String(e.portion.maximumGrams), String(e.portion.stepGrams)
            ].map { String($0.utf8.count) + ":" + $0 }.joined()
        }.joined(separator: "\n"))
    }

    static func digest(_ value: String) -> String {
        SHA256.hash(data: Data(value.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}
