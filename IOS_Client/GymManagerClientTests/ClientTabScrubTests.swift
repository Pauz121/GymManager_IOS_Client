import XCTest
@testable import GymManagerClient

final class ClientTabScrubTests: XCTestCase {
    func testUnarmedDragDoesNothing() {
        var state = ClientTabScrubState()
        XCTAssertNil(state.update(horizontal: -80, vertical: 0, count: 5))
    }

    func testHoldAndSmallJitterDoNotChangeTab() {
        var state = ClientTabScrubState()
        state.begin(index: 2)
        for x: Double in [0, 2, -3, 15, -39, 39] {
            XCTAssertNil(state.update(horizontal: x, vertical: 0, count: 5))
        }
        XCTAssertEqual(state.index, 2)
    }

    func testLeftSelectsNextAndRightSelectsPrevious() {
        var state = ClientTabScrubState()
        state.begin(index: 2)
        XCTAssertEqual(state.update(horizontal: -40, vertical: 0, count: 5), 3)
        XCTAssertEqual(state.update(horizontal: 0, vertical: 0, count: 5), 2)
    }

    func testProgressiveTravelRequiresFreshThresholdForEveryChange() {
        var state = ClientTabScrubState()
        state.begin(index: 0)
        XCTAssertEqual(state.update(horizontal: -40, vertical: 0, count: 5), 1)
        XCTAssertNil(state.update(horizontal: -40, vertical: 0, count: 5))
        XCTAssertNil(state.update(horizontal: -79, vertical: 0, count: 5))
        XCTAssertEqual(state.update(horizontal: -80, vertical: 0, count: 5), 2)
        XCTAssertEqual(state.update(horizontal: -120, vertical: 0, count: 5), 3)
    }

    func testOneLargeSampleCannotBurstAcrossMultipleTabs() {
        var state = ClientTabScrubState()
        state.begin(index: 0)
        XCTAssertEqual(state.update(horizontal: -800, vertical: 0, count: 5), 1)
        XCTAssertNil(state.update(horizontal: -800, vertical: 0, count: 5))
    }

    func testFirstAndLastBoundariesDoNotWrap() {
        var state = ClientTabScrubState()
        state.begin(index: 0)
        XCTAssertNil(state.update(horizontal: 40, vertical: 0, count: 5))
        XCTAssertEqual(state.index, 0)
        state.begin(index: 4)
        XCTAssertNil(state.update(horizontal: -40, vertical: 0, count: 5))
        XCTAssertEqual(state.index, 4)
        XCTAssertEqual(state.update(horizontal: 0, vertical: 0, count: 5), 3)
    }

    func testVerticalTravelAndInvalidSamplesDoNothing() {
        var state = ClientTabScrubState()
        state.begin(index: 2)
        XCTAssertNil(state.update(horizontal: -50, vertical: 100, count: 5))
        XCTAssertNil(state.update(horizontal: .nan, vertical: 0, count: 5))
        XCTAssertNil(state.update(horizontal: -.infinity, vertical: 0, count: 5))
        XCTAssertNil(state.update(horizontal: -50, vertical: 0, count: 0))
    }

    func testCancelResetsInteractionButDoesNotUndoLastSelectedTab() {
        var state = ClientTabScrubState()
        state.begin(index: 1)
        let lastSelection = state.update(horizontal: -40, vertical: 0, count: 5)
        state.end()
        XCTAssertEqual(lastSelection, 2)
        XCTAssertNil(state.index)
        XCTAssertNil(state.update(horizontal: -80, vertical: 0, count: 5))
        state.begin(index: lastSelection!)
        XCTAssertNil(state.update(horizontal: -39, vertical: 0, count: 5))
    }
}
