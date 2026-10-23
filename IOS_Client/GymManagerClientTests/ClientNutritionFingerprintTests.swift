import Foundation
import XCTest
@testable import GymManagerClient

/// Synthetic compatibility vectors for the pre-fix catalog serialization.
/// Definitions only on Windows: this is NOT an executed Xcode/build/persistence test.
final class ClientNutritionFingerprintTests: XCTestCase {
    private func reviewedFood(name: String = "Synthetic fixture 1", protein: Double? = 30) -> ClientFoodCatalogItem {
        let original = ClientNutritionCoachFixtures.food(1, role: .protein, kcal: 155, p: 30, c: 2, f: 3, min: 20, max: 250)
        return ClientFoodCatalogItem(
            id: original.id, name: name, caloriesPer100g: original.caloriesPer100g,
            proteinPer100g: protein, carbsPer100g: original.carbsPer100g, fatPer100g: original.fatPer100g,
            provider: original.provider, gramsPerPiece: original.gramsPerPiece, nutritionEvidence: original.nutritionEvidence
        )
    }

    func testPF01ReviewedRecordMatchesPreFixGoldenFingerprint() {
        XCTAssertEqual(ClientNutritionFoodPolicy.fingerprint([reviewedFood()]),
                       "6f4f3da8a24f583fc6bf64856afaf5bb68e8ec2cca53fe0184cc0e8a70d0fd81")
    }

    func testPF02UnicodeUTF8AndMissingNutrientMatchPreFixGolden() {
        XCTAssertEqual(ClientNutritionFoodPolicy.fingerprint([reviewedFood(name: "Caffè 🥛", protein: nil)]),
                       "54e40012162bdcb6b63d4b939e98fddba6ec3e738ed0e99ef899dbecb2fa1c3e")
    }

    func testPF03EmptyCatalogKeepsSHA256OfEmptyPayload() {
        XCTAssertEqual(ClientNutritionFoodPolicy.fingerprint([]),
                       "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855")
    }

    func testPF04UnreviewedRecordKeepsLegacyMarker() {
        var item = reviewedFood()
        item.nutritionEvidence = nil
        let expected = ClientNutritionFoodPolicy.digest(item.id.uuidString + ":unreviewed")
        XCTAssertEqual(ClientNutritionFoodPolicy.fingerprint([item]), expected)
    }

    func testPF05CatalogOrderDoesNotChangeFingerprint() {
        let catalog = ClientNutritionCoachFixtures.catalog()
        XCTAssertEqual(ClientNutritionFoodPolicy.fingerprint(catalog),
                       ClientNutritionFoodPolicy.fingerprint(Array(catalog.reversed())))
    }

    func testPF06ChangedReviewedFieldStillInvalidatesFingerprint() {
        let original = ClientNutritionFoodPolicy.fingerprint([reviewedFood()])
        XCTAssertNotEqual(original, ClientNutritionFoodPolicy.fingerprint([reviewedFood(name: "Changed synthetic fixture")]))
        XCTAssertNotEqual(original, ClientNutritionFoodPolicy.fingerprint([reviewedFood(protein: 29)]))
    }
}
