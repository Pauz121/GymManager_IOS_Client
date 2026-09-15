import Foundation

enum ClientActivityKind: String, CaseIterable, Hashable, Sendable {
    case gym
    case running
}

struct ClientActivityItem: Identifiable, Equatable, Sendable {
    let id: UUID
    let kind: ClientActivityKind
    let title: String
    let startedAt: Date
    let completedAt: Date
    let durationSeconds: TimeInterval
    let distanceKm: Double?
    let averagePaceMinutesPerKm: Double?
    let averageSpeedKmh: Double?
}

struct ClientActivitySummary: Equatable, Sendable {
    let gymSessions: Int
    let runs: Int
    let runningDistanceKm: Double
    let activeSeconds: TimeInterval
    let activeDays: Int
    let personalBests: Int

    static let empty = ClientActivitySummary(
        gymSessions: 0,
        runs: 0,
        runningDistanceKm: 0,
        activeSeconds: 0,
        activeDays: 0,
        personalBests: 0
    )
}

struct ClientActivityTrendBucket: Identifiable, Equatable, Sendable {
    let id: Date
    let label: String
    let gymMinutes: Double
    let runningMinutes: Double
    let runningKm: Double
}

enum ClientActivityPeriod: Int, CaseIterable, Identifiable, Hashable, Sendable {
    case month = 1
    case threeMonths = 3
    case sixMonths = 6
    case year = 12

    var id: Int { rawValue }
    var title: String {
        switch self {
        case .month: "Mese"
        case .threeMonths: "3 mesi"
        case .sixMonths: "6 mesi"
        case .year: "Anno"
        }
    }
}

enum ClientActivityInsights {
    static func items(state: ClientActivityState, snapshot: ClientSnapshot) -> [ClientActivityItem] {
        let gymItems = state.workouts.compactMap { execution -> ClientActivityItem? in
            guard let completedAt = execution.completedAt else { return nil }
            let title = snapshot.workout?.sessions.first(where: { $0.id == execution.sessionID })?.name ?? "Allenamento palestra"
            return ClientActivityItem(
                id: execution.id,
                kind: .gym,
                title: title,
                startedAt: execution.startedAt,
                completedAt: completedAt,
                durationSeconds: max(0, completedAt.timeIntervalSince(execution.startedAt)),
                distanceKm: nil,
                averagePaceMinutesPerKm: nil,
                averageSpeedKmh: nil
            )
        }
        let runItems = state.runningResults.map { result in
            ClientActivityItem(
                id: result.id,
                kind: .running,
                title: snapshot.runningPlan.flatMap { $0.id == result.planID ? $0.title : nil } ?? "Corsa",
                startedAt: result.completedAt.addingTimeInterval(-result.durationSeconds),
                completedAt: result.completedAt,
                durationSeconds: max(0, result.durationSeconds),
                distanceKm: result.distanceKm,
                averagePaceMinutesPerKm: result.averagePaceMinutesPerKm,
                averageSpeedKmh: result.averageSpeedKmh
            )
        }
        return (gymItems + runItems).sorted { $0.completedAt > $1.completedAt }
    }

    static func items(
        on date: Date,
        state: ClientActivityState,
        snapshot: ClientSnapshot,
        calendar: Calendar = .current
    ) -> [ClientActivityItem] {
        items(state: state, snapshot: snapshot).filter { calendar.isDate($0.completedAt, inSameDayAs: date) }
    }

    static func interval(
        for period: ClientActivityPeriod,
        endingAt date: Date = Date(),
        calendar: Calendar = .current
    ) -> DateInterval {
        let currentMonth = calendar.dateInterval(of: .month, for: date)!
        let start = calendar.date(byAdding: .month, value: -(period.rawValue - 1), to: currentMonth.start) ?? currentMonth.start
        return DateInterval(start: start, end: currentMonth.end)
    }

    static func summary(
        state: ClientActivityState,
        snapshot: ClientSnapshot,
        interval: DateInterval,
        calendar: Calendar = .current
    ) -> ClientActivitySummary {
        let allItems = items(state: state, snapshot: snapshot)
        let selected = allItems.filter { interval.contains($0.completedAt) }
        guard !selected.isEmpty else { return .empty }
        let activeDays = Set(selected.map { ClientDayKey.string(for: $0.completedAt, calendar: calendar) }).count
        let records = ClientRunningAchievements.recordAchievements(results: state.runningResults)
            .filter { interval.contains($0.achievedAt) }
        return ClientActivitySummary(
            gymSessions: selected.filter { $0.kind == .gym }.count,
            runs: selected.filter { $0.kind == .running }.count,
            runningDistanceKm: selected.compactMap(\.distanceKm).reduce(0, +),
            activeSeconds: selected.map(\.durationSeconds).reduce(0, +),
            activeDays: activeDays,
            personalBests: records.count
        )
    }

    static func trendBuckets(
        state: ClientActivityState,
        snapshot: ClientSnapshot,
        period: ClientActivityPeriod,
        endingAt date: Date = Date(),
        calendar: Calendar = .current
    ) -> [ClientActivityTrendBucket] {
        let selectedInterval = interval(for: period, endingAt: date, calendar: calendar)
        let selected = items(state: state, snapshot: snapshot).filter { selectedInterval.contains($0.completedAt) }
        let usesWeeks = period.rawValue <= 3
        let grouped = Dictionary(grouping: selected) { item -> Date in
            if usesWeeks {
                return calendar.dateInterval(of: .weekOfYear, for: item.completedAt)?.start ?? calendar.startOfDay(for: item.completedAt)
            }
            return calendar.dateInterval(of: .month, for: item.completedAt)?.start ?? calendar.startOfDay(for: item.completedAt)
        }
        return grouped.keys.sorted().map { start in
            let bucket = grouped[start] ?? []
            return ClientActivityTrendBucket(
                id: start,
                label: usesWeeks ? start.formatted(.dateTime.day().month(.abbreviated)) : start.formatted(.dateTime.month(.abbreviated)),
                gymMinutes: bucket.filter { $0.kind == .gym }.map(\.durationSeconds).reduce(0, +) / 60,
                runningMinutes: bucket.filter { $0.kind == .running }.map(\.durationSeconds).reduce(0, +) / 60,
                runningKm: bucket.filter { $0.kind == .running }.compactMap(\.distanceKm).reduce(0, +)
            )
        }
    }
}

enum ClientRunningTarget: Int, CaseIterable, Identifiable, Codable, Hashable, Sendable {
    case oneKilometer = 1_000
    case threeKilometers = 3_000
    case fiveKilometers = 5_000
    case tenKilometers = 10_000

    var id: Int { rawValue }
    var kilometers: Double { Double(rawValue) / 1_000 }
    var title: String { "\(rawValue / 1_000) KM" }
}

struct ClientRunningSplit: Identifiable, Equatable, Sendable {
    let index: Int
    let durationSeconds: TimeInterval
    let completedAt: Date

    var id: Int { index }
    var averagePaceMinutesPerKm: Double { durationSeconds / 60 }
    var averageSpeedKmh: Double? { durationSeconds > 0 ? 3_600 / durationSeconds : nil }
}

struct ClientRunningBestEffort: Equatable, Sendable {
    let target: ClientRunningTarget
    let durationSeconds: TimeInterval
    let startOffsetMeters: Double
    let endOffsetMeters: Double

    var averagePaceMinutesPerKm: Double { durationSeconds / 60 / target.kilometers }
    var averageSpeedKmh: Double? { durationSeconds > 0 ? target.kilometers / (durationSeconds / 3_600) : nil }
}

struct ClientRunningLeaderboardEntry: Identifiable, Equatable, Sendable {
    let sessionID: UUID
    let completedAt: Date
    let sessionDistanceKm: Double?
    let effort: ClientRunningBestEffort

    var id: UUID { sessionID }
}

struct ClientRunningRecordAchievement: Equatable, Sendable {
    let sessionID: UUID
    let target: ClientRunningTarget
    let achievedAt: Date
    let durationSeconds: TimeInterval
}

enum ClientRunningAchievements {
    static func splits(for route: [ClientRoutePoint]) -> [ClientRunningSplit] {
        let samples = timeline(for: route)
        guard let totalDistance = samples.last?.distance, totalDistance >= 1_000 else { return [] }
        let count = Int(totalDistance / 1_000)
        var previousCrossing = samples[0].elapsed
        return (1...count).compactMap { index in
            let threshold = Double(index) * 1_000
            guard let crossing = crossing(at: threshold, samples: samples) else { return nil }
            let duration = max(0, crossing.elapsed - previousCrossing)
            previousCrossing = crossing.elapsed
            return ClientRunningSplit(index: index, durationSeconds: duration, completedAt: crossing.timestamp)
        }
    }

    static func bestEffort(for route: [ClientRoutePoint], target: ClientRunningTarget) -> ClientRunningBestEffort? {
        let samples = timeline(for: route)
        guard samples.count > 1, (samples.last?.distance ?? 0) >= Double(target.rawValue) else { return nil }
        var endIndex = 1
        var best: ClientRunningBestEffort?
        for startIndex in 0..<(samples.count - 1) {
            let start = samples[startIndex]
            let endDistance = start.distance + Double(target.rawValue)
            while endIndex < samples.count, samples[endIndex].distance < endDistance { endIndex += 1 }
            guard endIndex < samples.count,
                  let end = interpolatedSample(at: endDistance, before: samples[endIndex - 1], after: samples[endIndex]) else { break }
            let duration = end.elapsed - start.elapsed
            guard duration > 0 else { continue }
            let candidate = ClientRunningBestEffort(
                target: target,
                durationSeconds: duration,
                startOffsetMeters: start.distance,
                endOffsetMeters: endDistance
            )
            if best == nil || candidate.durationSeconds < best!.durationSeconds { best = candidate }
        }
        return best
    }

    static func leaderboard(
        results: [ClientRunningResult],
        target: ClientRunningTarget,
        limit: Int = 3
    ) -> [ClientRunningLeaderboardEntry] {
        results.compactMap { result in
            bestEffort(for: result.route, target: target).map {
                ClientRunningLeaderboardEntry(sessionID: result.id, completedAt: result.completedAt, sessionDistanceKm: result.distanceKm, effort: $0)
            }
        }
        .sorted {
            if $0.effort.durationSeconds == $1.effort.durationSeconds { return $0.completedAt > $1.completedAt }
            return $0.effort.durationSeconds < $1.effort.durationSeconds
        }
        .reduce(into: [ClientRunningLeaderboardEntry]()) { entries, candidate in
            guard !entries.contains(where: { $0.sessionID == candidate.sessionID }), entries.count < max(0, limit) else { return }
            entries.append(candidate)
        }
    }

    static func newPersonalBests(
        for result: ClientRunningResult,
        comparedWith previousResults: [ClientRunningResult]
    ) -> [ClientRunningBestEffort] {
        ClientRunningTarget.allCases.compactMap { target in
            guard let current = bestEffort(for: result.route, target: target) else { return nil }
            let previous = leaderboard(results: previousResults.filter { $0.id != result.id }, target: target, limit: 1).first
            guard previous == nil || current.durationSeconds < previous!.effort.durationSeconds else { return nil }
            return current
        }
    }

    static func recordAchievements(results: [ClientRunningResult]) -> [ClientRunningRecordAchievement] {
        var records: [ClientRunningTarget: TimeInterval] = [:]
        var achievements: [ClientRunningRecordAchievement] = []
        for result in results.sorted(by: { $0.completedAt < $1.completedAt }) {
            for target in ClientRunningTarget.allCases {
                guard let effort = bestEffort(for: result.route, target: target) else { continue }
                if records[target] == nil || effort.durationSeconds < records[target]! {
                    records[target] = effort.durationSeconds
                    achievements.append(ClientRunningRecordAchievement(
                        sessionID: result.id,
                        target: target,
                        achievedAt: result.completedAt,
                        durationSeconds: effort.durationSeconds
                    ))
                }
            }
        }
        return achievements
    }

    private struct TimelineSample {
        let distance: Double
        let elapsed: TimeInterval
        let timestamp: Date
    }

    private static func timeline(for route: [ClientRoutePoint]) -> [TimelineSample] {
        guard let first = route.first else { return [] }
        var distance = 0.0
        let firstElapsed = max(0, first.elapsedSeconds ?? 0)
        var previousElapsed = firstElapsed
        var samples = [TimelineSample(distance: 0, elapsed: firstElapsed, timestamp: first.timestamp)]
        for (previous, point) in zip(route, route.dropFirst()) {
            distance += ClientRunningMetrics.distanceMeters(from: previous, to: point)
            let fallback = max(0, point.timestamp.timeIntervalSince(first.timestamp))
            let elapsed = max(previousElapsed, point.elapsedSeconds ?? fallback)
            samples.append(TimelineSample(distance: distance, elapsed: elapsed, timestamp: point.timestamp))
            previousElapsed = elapsed
        }
        return samples
    }

    private static func crossing(at distance: Double, samples: [TimelineSample]) -> TimelineSample? {
        guard let index = samples.firstIndex(where: { $0.distance >= distance }), index > 0 else { return nil }
        return interpolatedSample(at: distance, before: samples[index - 1], after: samples[index])
    }

    private static func interpolatedSample(
        at distance: Double,
        before: TimelineSample,
        after: TimelineSample
    ) -> TimelineSample? {
        let segment = after.distance - before.distance
        guard segment > 0, distance >= before.distance, distance <= after.distance else { return nil }
        let ratio = (distance - before.distance) / segment
        let elapsed = before.elapsed + (after.elapsed - before.elapsed) * ratio
        let timestamp = before.timestamp.addingTimeInterval(after.timestamp.timeIntervalSince(before.timestamp) * ratio)
        return TimelineSample(distance: distance, elapsed: elapsed, timestamp: timestamp)
    }
}
