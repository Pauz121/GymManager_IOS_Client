import Foundation

enum ClientProgressPeriod: String, CaseIterable, Identifiable {
    case month, quarter, all
    var id: String { rawValue }
    var title: String { switch self { case .month: "30 giorni"; case .quarter: "90 giorni"; case .all: "Tutto" } }
    func contains(_ date: Date, now: Date = Date(), calendar: Calendar = .autoupdatingCurrent) -> Bool {
        guard date <= now else { return false }
        let days: Int
        switch self { case .month: days = 30; case .quarter: days = 90; case .all: return true }
        guard let start = calendar.date(byAdding: .day, value: -(days - 1), to: calendar.startOfDay(for: now)) else { return false }
        return date >= start
    }
}

enum ClientProgressPresentation {
    static func weights(_ entries: [ClientProgressEntry], period: ClientProgressPeriod, now: Date = Date()) -> [ClientProgressEntry] {
        entries.filter {
            guard let weight = $0.weightKg else { return false }
            return weight.isFinite && weight > 0 && period.contains($0.recordedAt, now: now)
        }.sorted { $0.recordedAt == $1.recordedAt ? $0.id.uuidString < $1.id.uuidString : $0.recordedAt < $1.recordedAt }
    }
    static func delta(_ weights: [ClientProgressEntry]) -> Double? {
        guard weights.count >= 2, let current = weights.last?.weightKg,
              let previous = weights.dropLast().last?.weightKg else { return nil }
        return current - previous
    }
    static func nearest(to date: Date, in weights: [ClientProgressEntry]) -> ClientProgressEntry? {
        weights.min { abs($0.recordedAt.timeIntervalSince(date)) < abs($1.recordedAt.timeIntervalSince(date)) }
    }
}
