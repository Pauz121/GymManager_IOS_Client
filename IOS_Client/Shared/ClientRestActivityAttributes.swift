import ActivityKit
import Foundation

struct ClientRestActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable, Sendable {
        let endsAt: Date?
        let pausedSeconds: Int?
        let exerciseName: String?
        let nextSetNumber: Int?
        let finished: Bool
    }
    let title: String
}
