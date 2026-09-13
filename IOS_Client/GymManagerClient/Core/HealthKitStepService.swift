import Combine
import Foundation
import HealthKit

struct ClientStepSample: Equatable, Sendable {
    let date: Date
    let count: Int
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

    init() {
        state = HKHealthStore.isHealthDataAvailable() ? .notRequested : .unavailable
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
            try await refresh()
        } catch {
            state = .failed
        }
    }

    func refresh() async throws {
        guard let stepType = HKObjectType.quantityType(forIdentifier: .stepCount) else {
            state = .unavailable
            return
        }
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date(), options: .strictStartDate)

        let count: Int = try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: stepType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, error in
                if let error { continuation.resume(throwing: error); return }
                let value = result?.sumQuantity()?.doubleValue(for: .count()) ?? 0
                continuation.resume(returning: max(0, Int(value.rounded())))
            }
            healthStore.execute(query)
        }

        state = count > 0 ? .ready(ClientStepSample(date: Date(), count: count)) : .noData
    }
}
