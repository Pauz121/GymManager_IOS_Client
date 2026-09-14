import Combine
import Foundation
import HealthKit

struct ClientStepSample: Equatable, Sendable {
    let date: Date
    let count: Int
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
    private let healthStore = HKHealthStore()
    private let defaults: UserDefaults
    private static let authorizationRequestedKey = "gymmanager.client.healthkit.steps.authorization-requested"
    private var isRefreshing = false

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if !HKHealthStore.isHealthDataAvailable() {
            state = .unavailable
        } else if defaults.bool(forKey: Self.authorizationRequestedKey) {
            state = .loading
        } else {
            state = .notRequested
        }
    }

    func requestAccessAndRefresh() async {
        guard HKHealthStore.isHealthDataAvailable(),
              let stepType = HKObjectType.quantityType(forIdentifier: .stepCount) else {
            state = .unavailable
            return
        }

        state = .loading
        do {
            try await healthStore.requestAuthorization(toShare: [], read: [stepType])
            defaults.set(true, forKey: Self.authorizationRequestedKey)
            try await refresh()
        } catch {
            state = .failed
        }
    }

    func refreshIfPreviouslyRequested() async {
        guard defaults.bool(forKey: Self.authorizationRequestedKey) else { return }
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
