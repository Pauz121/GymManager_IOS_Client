import XCTest
@testable import GymManagerClient

final class ClientExerciseExperienceTests: XCTestCase {
    func testUnapprovedOrUnknownClipsNeverBecomeDemonstrations() {
        XCTAssertEqual(ClientExerciseMediaPipeline.prototypeKeys.count, 10)
        XCTAssertTrue(ClientExerciseMediaPipeline.approvedAssetKeys.isEmpty)
        for key in ClientExerciseMediaPipeline.prototypeKeys {
            XCTAssertNil(ClientExerciseMediaPipeline.approvedURL(for: key))
        }
        XCTAssertNil(ClientExerciseMediaPipeline.approvedURL(for: nil))
        XCTAssertNil(ClientExerciseMediaPipeline.approvedURL(for: "../../untrusted"))
    }
    func testNoMuscleDataDoesNotInferFromExerciseName() {
        let result = ClientExerciseMusclePresentation(exercise: exercise(name: "Panca piana"))
        XCTAssertTrue(result.primary.isEmpty)
        XCTAssertTrue(result.secondary.isEmpty)
        XCTAssertTrue(result.unclassified.isEmpty)
    }
    func testKnownAndUnknownCatalogRolesRemainDistinct() {
        var item = exercise(name: "Catalogo")
        item.catalogMuscles = [
            .init(id: UUID(), name: "Pettorali", sourceKey: nil, relevance: 1, isPrimary: true),
            .init(id: UUID(), name: "Tricipiti", sourceKey: nil, relevance: 0.5, isPrimary: false),
            .init(id: UUID(), name: "Spalle", sourceKey: nil, relevance: nil, isPrimary: false, roleIsKnown: false)
        ]
        let result = ClientExerciseMusclePresentation(exercise: item)
        XCTAssertEqual(result.primary, [.chest])
        XCTAssertEqual(result.secondary, [.triceps])
        XCTAssertEqual(result.unclassified, ["Spalle"])
    }
    private func exercise(name: String) -> ClientExercise {
        .init(id: UUID(), name: name, sets: "3", repetitions: "8–10", restSeconds: 120,
              loadKg: nil, notes: nil, videoURL: nil)
    }
}
