import ActivityKit
import Foundation

struct ClientRunActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        let distanceMeters: Double
        let elapsedSeconds: Int
        let timerAnchor: Date?
        let averagePaceSecondsPerKm: Int?
        let averageSpeedKmh: Double?
        let displayMode: String
        let isPaused: Bool
    }

    let planTitle: String
}
