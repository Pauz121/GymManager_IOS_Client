import Combine
import Foundation
import HealthKit

struct ClientStepSample: Equatable, Sendable {
    let date: Date
    let count: Int
}

enum ClientHealthPermissionDecision: String, Equatable {
    case notAsked
    case accepted
    case declined
}

enum ClientHealthPermissionPreference {
    static let decisionKey = "gymmanager.client.healthkit.steps.permission-decision"
    static let legacyAuthorizationRequestedKey = "gymmanager.client.healthkit.steps.authorization-requested"

    static func load(from defaults: UserDefaults) -> ClientHealthPermissionDecision {
        if let rawValue = defaults.string(forKey: decisionKey),
           let decision = ClientHealthPermissionDecision(rawValue: rawValue) {
            return decision
        }
        return defaults.bool(forKey: legacyAuthorizationRequestedKey) ? .accepted : .notAsked
    }

    static func save(_ decision: ClientHealthPermissionDecision, to defaults: UserDefaults) {
        defaults.set(decision.rawValue, forKey: decisionKey)
        if decision == .accepted {
            defaults.set(true, forKey: legacyAuthorizationRequestedKey)
        }
    }
}

enum ClientHealthDayWindow {
    static func interval(containing date: Date, calendar: Calendar = .autoupdatingCurrent) -> DateInterval {
        let start = calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? date
        return DateInterval(start: start, end: end)
    }
}

@MainActor
final class HealthKitStepService: ObservableObject {
    enum State: Equatable {
        case unavailable
        case notRequested
        case loading
        case ready(ClientStepSample)
        case noData
        case failed
    }

    @Published private(set) var state: State
    @Published private(set) var permissionDecision: ClientHealthPermissionDecision
    private let healthStore = HKHealthStore()
    private let defaults: UserDefaults
    private var isRefreshing = false

    var shouldOfferConnectionPrompt: Bool {
        HKHealthStore.isHealthDataAvailable() && permissionDecision == .notAsked
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let initialDecision = ClientHealthPermissionPreference.load(from: defaults)
        permissionDecision = initialDecision
        if !HKHealthStore.isHealthDataAvailable() {
            state = .unavailable
        } else if initialDecision == .accepted {
            state = .loading
        } else {
            state = .notRequested
        }
    }

    func declineConnection() {
        permissionDecision = .declined
        ClientHealthPermissionPreference.save(.declined, to: defaults)
        if HKHealthStore.isHealthDataAvailable() {
            state = .notRequested
        }
    }

    func requestAccessAndRefresh() async {
        guard HKHealthStore.isHealthDataAvailable(),
              let stepType = HKObjectType.quantityType(forIdentifier: .stepCount) else {
            state = .unavailable
            return
        }

        permissionDecision = .accepted
        ClientHealthPermissionPreference.save(.accepted, to: defaults)
        state = .loading
        do {
            try await healthStore.requestAuthorization(toShare: [], read: [stepType])
            try await refresh()
        } catch {
            state = .failed
        }
    }

    func refreshIfPreviouslyRequested() async {
        guard permissionDecision == .accepted else { return }
        do {
            try await refresh()
        } catch {
            if case .ready = state { return }
            state = .failed
        }
    }

    func refresh() async throws {
        guard let stepType = HKObjectType.quantityType(forIdentifier: .stepCount) else {
            state = .unavailable
            return
        }
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        let now = Date()
        let day = ClientHealthDayWindow.interval(containing: now)
        let predicate = HKQuery.predicateForSamples(
            withStart: day.start,
            end: min(now, day.end),
            options: .strictStartDate
        )

        let result: (count: Int, hasAccessibleData: Bool) = try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: stepType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, error in
                if let error { continuation.resume(throwing: error); return }
                let quantity = result?.sumQuantity()
                let value = quantity?.doubleValue(for: .count()) ?? 0
                continuation.resume(returning: (max(0, Int(value.rounded())), quantity != nil))
            }
            healthStore.execute(query)
        }

        // HKStatisticsQuery delegates source reconciliation to HealthKit. We never add
        // iPhone, Watch or third-party samples ourselves, avoiding duplicated totals.
        state = result.hasAccessibleData
            ? .ready(ClientStepSample(date: now, count: result.count))
            : .noData
    }
}
