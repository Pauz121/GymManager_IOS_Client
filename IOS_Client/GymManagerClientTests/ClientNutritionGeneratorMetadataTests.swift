import Foundation
import XCTest
@testable import GymManagerClient

final class ClientNutritionGeneratorMetadataTests: XCTestCase {
    typealias F = ClientNutritionCoachFixtures

    private func generate() throws -> ClientPersonalNutritionPlan {
        try ClientNutritionGenerator.generate(
            context: .init(mode: .standalone, profile: F.profile()),
            answers: F.answers(), catalog: F.catalog(), now: Date(timeIntervalSince1970: 0))
    }

    func testNG01GeneratedSignatureMatchesCompletedPlan() throws {
        let plan = try generate()
        let metadata = try XCTUnwrap(plan.generationMetadata)

        XCTAssertFalse(metadata.structuralSignature.isEmpty)
        XCTAssertEqual(metadata.structuralSignature, ClientNutritionPlanValidator.signature(plan))
        XCTAssertEqual(metadata.generatorVersion, ClientNutritionCoachRules.version)
        XCTAssertNotNil(plan.editProvenance)
        XCTAssertTrue(ClientNutritionPlanValidator.inspect(
            plan, context: .init(mode: .standalone, profile: F.profile()), catalog: F.catalog()).isEmpty)
    }

    func testNG02MetadataSignatureSurvivesCodableRoundTrip() throws {
        let plan = try generate()
        let data = try JSONEncoder().encode(plan)
        let decoded = try JSONDecoder().decode(ClientPersonalNutritionPlan.self, from: data)

        XCTAssertEqual(decoded.generationMetadata, plan.generationMetadata)
        XCTAssertEqual(decoded.generationMetadata?.structuralSignature,
                       ClientNutritionPlanValidator.signature(decoded))
        XCTAssertTrue(ClientNutritionPlanValidator.inspect(
            decoded, context: .init(mode: .standalone, profile: F.profile()), catalog: F.catalog()).isEmpty)
    }
}
