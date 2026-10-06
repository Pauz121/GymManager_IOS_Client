import Foundation

struct ClientCapabilities: Codable, Equatable, Sendable {
    var runningEnabled: Bool

    static let none = ClientCapabilities(runningEnabled: false)
}

struct ClientRunningPlan: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let title: String
    let detail: String
    let targetMinutes: Int?
    let targetDistanceKm: Double?
}

struct ClientSetLog: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let number: Int
    let prescribedRepetitions: String?
    let prescribedLoadKg: Double?
    var actualRepetitions: Int?
    var actualLoadKg: Double?
    var completedAt: Date?

    var isCompleted: Bool { completedAt != nil }
}

struct ClientExerciseLog: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let exerciseID: UUID
    var note: String
    var sets: [ClientSetLog]

    var isCompleted: Bool { !sets.isEmpty && sets.allSatisfy(\.isCompleted) }
}

struct ClientWorkoutFeedback: Codable, Equatable, Sendable {
    let effort: Int
    let quality: Int
    let hasPain: Bool
    let note: String
}

struct ClientWorkoutExecution: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let planID: UUID
    let sessionID: UUID
    let dayKey: String
    let startedAt: Date
    var completedAt: Date?
    var exercises: [ClientExerciseLog]
    var feedback: ClientWorkoutFeedback?

    var completedExerciseCount: Int { exercises.filter(\.isCompleted).count }
    var totalExerciseCount: Int { exercises.count }
    var isCompleted: Bool { completedAt != nil }
    var durationMinutes: Int? {
        guard let completedAt else { return nil }
        return max(1, Int(completedAt.timeIntervalSince(startedAt) / 60))
    }
}

struct ClientMealCompletion: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let mealID: UUID
    let dayKey: String
    let completedAt: Date
}

enum ClientRestTimerPhase: String, Codable, Sendable {
    case running, paused
}

struct ClientRestTimerState: Codable, Equatable, Sendable {
    let exerciseID: UUID
    let nextSetNumber: Int?
    var phase: ClientRestTimerPhase
    var endsAt: Date?
    var pausedSeconds: TimeInterval?

    func remainingSeconds(at date: Date = Date()) -> Int {
        switch phase {
        case .running:
            return max(0, Int(ceil(endsAt?.timeIntervalSince(date) ?? 0)))
        case .paused:
            return max(0, Int(ceil(pausedSeconds ?? 0)))
        }
    }
}

struct ClientRunningExecution: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let planID: UUID
    let startedAt: Date
    var resumedAt: Date?
    var accumulatedSeconds: TimeInterval
    var route: [ClientRoutePoint]
    var maximumSpeedMetersPerSecond: Double?

    var isPaused: Bool { resumedAt == nil }

    func elapsedSeconds(at date: Date = Date()) -> TimeInterval {
        accumulatedSeconds + (resumedAt.map { max(0, date.timeIntervalSince($0)) } ?? 0)
    }
}

struct ClientRoutePoint: Codable, Equatable, Sendable {
    let latitude: Double
    let longitude: Double
    let timestamp: Date
    let horizontalAccuracy: Double
    let speedMetersPerSecond: Double?
    var elapsedSeconds: TimeInterval? = nil
}

struct ClientRunningResult: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let planID: UUID
    let completedAt: Date
    let durationSeconds: TimeInterval
    let distanceKm: Double?
    let route: [ClientRoutePoint]
    let maximumSpeedKmh: Double?
    let effort: Int?
    let note: String

    var averagePaceMinutesPerKm: Double? {
        guard let distanceKm, distanceKm > 0 else { return nil }
        return durationSeconds / 60 / distanceKm
    }

    var averageSpeedKmh: Double? {
        guard let distanceKm, durationSeconds > 0 else { return nil }
        return distanceKm / (durationSeconds / 3_600)
    }
}

struct ClientRunningSpeedSample: Identifiable, Equatable, Sendable {
    let timestamp: Date
    let elapsedSeconds: TimeInterval
    let speedKmh: Double

    var id: Date { timestamp }
}

enum ClientRunningMetrics {
    static func distanceMeters(for route: [ClientRoutePoint]) -> Double {
        guard route.count > 1 else { return 0 }
        return zip(route, route.dropFirst()).reduce(0) { total, pair in
            total + distanceMeters(from: pair.0, to: pair.1)
        }
    }

    static func stabilizedSpeedMetersPerSecond(
        for route: [ClientRoutePoint],
        windowSeconds: TimeInterval = 30,
        minimumSampleSeconds: TimeInterval = 10
    ) -> Double? {
        guard let first = route.first, let latest = route.last, route.count > 1 else { return nil }
        func elapsed(_ point: ClientRoutePoint) -> TimeInterval {
            point.elapsedSeconds ?? max(0, point.timestamp.timeIntervalSince(first.timestamp))
        }
        let latestElapsed = elapsed(latest)
        let threshold = latestElapsed - max(1, windowSeconds)
        let recent = route.filter { elapsed($0) >= threshold }
        guard let start = recent.first, recent.count > 1 else { return nil }
        let duration = latestElapsed - elapsed(start)
        guard duration >= minimumSampleSeconds else { return nil }
        return distanceMeters(for: recent) / duration
    }

    static func speedSamples(
        for route: [ClientRoutePoint],
        maximumCount: Int = 90,
        smoothingSampleCount: Int = 4
    ) -> [ClientRunningSpeedSample] {
        guard route.count > 1, maximumCount > 0 else { return [] }
        var rawSpeeds: [Double] = []
        var samples: [ClientRunningSpeedSample] = []
        let firstTimestamp = route[0].timestamp

        for index in 1..<route.count {
            let previous = route[index - 1]
            let current = route[index]
            let elapsed = current.elapsedSeconds ?? max(0, current.timestamp.timeIntervalSince(firstTimestamp))
            let segmentDuration: TimeInterval
            if let currentElapsed = current.elapsedSeconds, let previousElapsed = previous.elapsedSeconds {
                segmentDuration = currentElapsed - previousElapsed
            } else {
                segmentDuration = current.timestamp.timeIntervalSince(previous.timestamp)
            }
            guard segmentDuration > 0 else { continue }
            let metersPerSecond = current.speedMetersPerSecond ?? (distanceMeters(from: previous, to: current) / segmentDuration)
            guard metersPerSecond >= 0, metersPerSecond <= 12 else { continue }
            rawSpeeds.append(metersPerSecond * 3.6)
            let window = rawSpeeds.suffix(max(1, smoothingSampleCount))
            let smoothed = window.reduce(0, +) / Double(window.count)
            samples.append(ClientRunningSpeedSample(timestamp: current.timestamp, elapsedSeconds: elapsed, speedKmh: smoothed))
        }
        return Array(samples.suffix(maximumCount))
    }

    static func distanceMeters(from first: ClientRoutePoint, to second: ClientRoutePoint) -> Double {
        let earthRadius = 6_371_000.0
        let latitudeDelta = radians(second.latitude - first.latitude)
        let longitudeDelta = radians(second.longitude - first.longitude)
        let firstLatitude = radians(first.latitude)
        let secondLatitude = radians(second.latitude)
        let value = sin(latitudeDelta / 2) * sin(latitudeDelta / 2)
            + cos(firstLatitude) * cos(secondLatitude)
            * sin(longitudeDelta / 2) * sin(longitudeDelta / 2)
        return earthRadius * 2 * atan2(sqrt(value), sqrt(max(0, 1 - value)))
    }

    private static func radians(_ degrees: Double) -> Double { degrees * .pi / 180 }
}

struct ClientActivityState: Codable, Equatable, Sendable {
    var workouts: [ClientWorkoutExecution]
    var meals: [ClientMealCompletion]
    var restTimer: ClientRestTimerState?
    var activeRun: ClientRunningExecution?
    var runningResults: [ClientRunningResult]

    static let empty = ClientActivityState(workouts: [], meals: [], restTimer: nil, activeRun: nil, runningResults: [])

    func workout(sessionID: UUID, on date: Date = Date()) -> ClientWorkoutExecution? {
        let key = ClientDayKey.string(for: date)
        return workouts.first { $0.sessionID == sessionID && $0.dayKey == key }
    }

    func isMealCompleted(_ mealID: UUID, on date: Date = Date()) -> Bool {
        let key = ClientDayKey.string(for: date)
        return meals.contains { $0.mealID == mealID && $0.dayKey == key }
    }
}

enum ClientDayKey {
    static func string(for date: Date, calendar: Calendar = .current) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", components.year ?? 0, components.month ?? 0, components.day ?? 0)
    }
}

extension ClientExercise {
    var setCount: Int { max(1, Int(sets ?? "") ?? 1) }

    var suggestedActualRepetitions: Int? {
        repetitions?
            .split(whereSeparator: { !$0.isNumber })
            .compactMap { Int($0) }
            .first
    }
}
