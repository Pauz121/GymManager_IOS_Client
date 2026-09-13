import Foundation

enum ClientConnectionMode: String, Codable, Sendable {
    case standalone
    case trainerConnected = "trainer-connected"
}

enum ClientDataSource: String, Codable, Sendable {
    case live, demo
}

struct ClientIdentity: Codable, Equatable, Sendable {
    let authUserID: UUID
    let clientID: UUID?
    let trainerID: UUID?
    let mode: ClientConnectionMode
    let firstName: String
    let lastName: String
    let displayName: String
    let username: String
    let email: String?
    let trainerName: String?
}

struct ClientExercise: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let name: String
    let sets: String?
    let repetitions: String?
    let restSeconds: Int?
    let loadKg: Double?
    let notes: String?
    let videoURL: URL?
}

struct ClientWorkoutSession: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let name: String
    let weekday: Int?
    let durationMinutes: Int?
    let exercises: [ClientExercise]
}

struct ClientWorkoutPlan: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let title: String
    let startsOn: String?
    let endsOn: String?
    let currentWeek: Int
    let sessions: [ClientWorkoutSession]
    let todaySessionID: UUID?
    let publishedAt: Date
}

struct ClientFood: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let name: String
    let quantity: Double?
    let unit: String
}

struct ClientMeal: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let name: String
    let foods: [ClientFood]
}

struct ClientNutritionDay: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let weekday: Int
    let name: String
    let meals: [ClientMeal]
}

struct ClientNutritionPlan: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let title: String
    let days: [ClientNutritionDay]
    let publishedAt: Date
    let detailNotice: String?
}

struct ClientAppointment: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let title: String
    let startsAt: Date
    let endsAt: Date
    let location: String?
}

struct ClientProgressEntry: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let recordedAt: Date
    let weightKg: Double?
    let waistCm: Double?
    let hipsCm: Double?
}

enum ClientUpdateKind: String, Codable, Sendable {
    case workout, nutrition, appointment
}

struct ClientUpdate: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let title: String
    let detail: String
    let date: Date
    let kind: ClientUpdateKind
}

struct ClientSnapshot: Codable, Equatable, Sendable {
    var workout: ClientWorkoutPlan?
    var nutrition: ClientNutritionPlan?
    var appointments: [ClientAppointment]
    var progress: [ClientProgressEntry]
    var updates: [ClientUpdate]
    var warnings: [String]
    var capabilities: ClientCapabilities = .none
    var runningPlan: ClientRunningPlan? = nil

    static let empty = ClientSnapshot(
        workout: nil,
        nutrition: nil,
        appointments: [],
        progress: [],
        updates: [],
        warnings: [],
        capabilities: .none,
        runningPlan: nil
    )
}

enum PersonalAgendaKind: String, Codable, CaseIterable, Hashable, Sendable {
    case activity = "Attività"
    case reminder = "Promemoria"
    case note = "Nota"
}

enum PersonalAgendaPriority: String, Codable, CaseIterable, Hashable, Sendable {
    case low = "Bassa"
    case normal = "Media"
    case high = "Alta"
}

struct PersonalAgendaTask: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    var title: String
    var date: Date?
    var notes: String
    var kind: PersonalAgendaKind
    var priority: PersonalAgendaPriority
    var isCompleted: Bool
}

enum ClientAccessPolicy {
    static let canEditProfessionalWorkout = false
    static let canEditProfessionalNutrition = false
    static let canDisconnectTrainer = false
    static let canUsePersonalAgenda = true
}

enum ClientDateLogic {
    static func weekday(for date: Date, calendar: Calendar = .current) -> Int {
        let appleDay = calendar.component(.weekday, from: date)
        return appleDay == 1 ? 7 : appleDay - 1
    }

    static func planWeek(startsOn: Date?, durationWeeks: Int?, fallback: Int, today: Date, calendar: Calendar = .current) -> Int {
        guard let startsOn else { return max(1, fallback) }
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: startsOn), to: calendar.startOfDay(for: today)).day ?? 0
        let week = max(1, days / 7 + 1)
        return min(week, max(1, durationWeeks ?? week))
    }
}

enum ClientIdentityLogic {
    static func technicalEmail(for identifier: String) -> String {
        let normalized = identifier.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return normalized.contains("@") ? normalized : "\(normalized)@accounts.gestionale.invalid"
    }
}
