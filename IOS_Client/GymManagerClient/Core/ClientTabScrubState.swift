import Foundation

/// UI-only interaction state. Each change needs fresh intentional travel;
/// a long press, repeated sample or a clamped edge never selects another tab.
struct ClientTabScrubState: Equatable {
    static let threshold: Double = 40
    private(set) var index: Int?
    private var anchorX: Double = 0

    mutating func begin(index: Int) {
        self.index = index
        anchorX = 0
    }

    mutating func update(horizontal: Double, vertical: Double, count: Int) -> Int? {
        guard let index, count > 0, (0..<count).contains(index),
              horizontal.isFinite, vertical.isFinite else { return nil }
        let delta = horizontal - anchorX
        guard abs(delta) >= Self.threshold, abs(delta) > abs(vertical) else { return nil }
        anchorX = horizontal
        let next = min(count - 1, max(0, index + (delta < 0 ? 1 : -1)))
        guard next != index else { return nil }
        self.index = next
        return next
    }

    mutating func end() {
        index = nil
        anchorX = 0
        // Selection lives in TabView, so cancellation keeps the last real tab.
    }
}
