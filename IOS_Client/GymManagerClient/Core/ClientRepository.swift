import Foundation
import Supabase

@MainActor
final class ClientRepository {
    static let shared = ClientRepository()
    private let client: SupabaseClient

    init(client: SupabaseClient = ClientSupabaseProvider.client) {
        self.client = client
    }

    func identity(authUserID: UUID, email: String?) async throws -> ClientIdentity {
        let profiles: [ClientProfileRow] = try await client
            .from("profiles")
            .select("id,username,display_name,role,status,is_active")
            .eq("id", value: authUserID.uuidString)
            .limit(1)
            .execute()
            .value

        guard let profile = profiles.first else {
            throw ClientAppError.message("Il profilo Cliente non è ancora disponibile.")
        }
        guard profile.role == "client" else { throw ClientAppError.unsupportedRole }
        guard profile.status == "active", profile.isActive == true else { throw ClientAppError.inactiveProfile }

        let links: [ClientLinkRow] = try await client
            .from("clients")
            .select("id,auth_user_id,trainer_id,first_name,last_name,status")
            .eq("auth_user_id", value: authUserID.uuidString)
            .limit(2)
            .execute()
            .value

        guard links.count <= 1 else { throw ClientAppError.duplicateClientLinks }
        if let link = links.first {
            guard link.authUserID == authUserID, link.status == "active" else { throw ClientAppError.invalidClientLink }
            return ClientIdentity(
                authUserID: authUserID,
                clientID: link.id,
                trainerID: link.trainerID,
                mode: .trainerConnected,
                firstName: link.firstName,
                lastName: link.lastName,
                displayName: profile.displayName,
                username: profile.username,
                email: Self.publicEmail(email),
                trainerName: nil
            )
        }

        let names = profile.displayName.split(separator: " ", maxSplits: 1).map(String.init)
        return ClientIdentity(
            authUserID: authUserID,
            clientID: nil,
            trainerID: nil,
            mode: .standalone,
            firstName: names.first ?? profile.displayName,
            lastName: names.count > 1 ? names[1] : "",
            displayName: profile.displayName,
            username: profile.username,
            email: Self.publicEmail(email),
            trainerName: nil
        )
    }

    func snapshot(for identity: ClientIdentity, today: Date = Date()) async -> ClientSnapshot {
        guard let clientID = identity.clientID, let trainerID = identity.trainerID else { return .empty }
        var snapshot = ClientSnapshot.empty

        do { snapshot.workout = try await workout(clientID: clientID, trainerID: trainerID, today: today) }
        catch { snapshot.warnings.append("Allenamento non disponibile. Riprova il caricamento.") }
        do { snapshot.nutrition = try await nutrition(clientID: clientID, trainerID: trainerID, today: today) }
        catch { snapshot.warnings.append("Nutrizione non disponibile. Riprova il caricamento.") }
        do { snapshot.appointments = try await appointments(clientID: clientID, trainerID: trainerID, today: today) }
        catch { snapshot.warnings.append("Appuntamenti non disponibili. Riprova il caricamento.") }
        do { snapshot.progress = try await progress(clientID: clientID, trainerID: trainerID) }
        catch { snapshot.warnings.append("Progressi non disponibili. Riprova il caricamento.") }

        snapshot.updates = Self.updates(from: snapshot)
        return snapshot
    }

    private func workout(clientID: UUID, trainerID: UUID, today: Date) async throws -> ClientWorkoutPlan? {
        let rows: [WorkoutPlanRow] = try await client.from("workout_plans")
            .select("id,client_id,trainer_id,title,status,plan_kind,published_at,starts_on,ends_on,duration_weeks,current_week")
            .eq("client_id", value: clientID.uuidString)
            .eq("trainer_id", value: trainerID.uuidString)
            .eq("status", value: "active")
            .eq("plan_kind", value: "client_plan")
            .order("published_at", ascending: false)
            .limit(10)
            .execute().value
        guard let plan = rows.first(where: { $0.isVisible(on: today, clientID: clientID, trainerID: trainerID) }),
              let publishedAt = clientParseDate(plan.publishedAt) else { return nil }

        let days: [WorkoutDayRow] = try await client.from("workout_days")
            .select("id,workout_plan_id,name,weekday,day_order")
            .eq("workout_plan_id", value: plan.id.uuidString)
            .order("day_order", ascending: true)
            .execute().value
        let dayIDs = days.map { $0.id.uuidString }
        let exercises: [WorkoutExerciseRow] = dayIDs.isEmpty ? [] : try await client.from("workout_plan_exercises")
            .select("id,workout_day_id,sets,repetitions,rest_seconds,load_kg,notes,exercise_order,exercise:exercises(id,name,video_url)")
            .in("workout_day_id", values: dayIDs)
            .order("exercise_order", ascending: true)
            .execute().value

        let sessions = days.map { day in
            ClientWorkoutSession(
                id: day.id,
                name: day.name,
                weekday: day.weekday,
                durationMinutes: nil,
                exercises: exercises.filter { $0.workoutDayID == day.id }.map { $0.clientExercise }
            )
        }
        let start = clientParseDay(plan.startsOn)
        let week = ClientDateLogic.planWeek(startsOn: start, durationWeeks: plan.durationWeeks, fallback: plan.currentWeek, today: today)
        let weekday = ClientDateLogic.weekday(for: today)
        return ClientWorkoutPlan(
            id: plan.id,
            title: plan.title,
            startsOn: plan.startsOn,
            endsOn: plan.endsOn,
            currentWeek: week,
            sessions: sessions,
            todaySessionID: sessions.first(where: { $0.weekday == weekday })?.id,
            publishedAt: publishedAt
        )
    }

    private func nutrition(clientID: UUID, trainerID: UUID, today: Date) async throws -> ClientNutritionPlan? {
        let rows: [NutritionPlanRow] = try await client.from("nutrition_plans")
            .select("id,client_id,trainer_id,name,status,plan_kind,published_at,starts_on,ends_on")
            .eq("client_id", value: clientID.uuidString)
            .eq("trainer_id", value: trainerID.uuidString)
            .eq("status", value: "active")
            .eq("plan_kind", value: "client_plan")
            .order("published_at", ascending: false)
            .limit(10)
            .execute().value
        guard let plan = rows.first(where: { $0.isVisible(on: today, clientID: clientID, trainerID: trainerID) }),
              let publishedAt = clientParseDate(plan.publishedAt) else { return nil }

        let days: [NutritionDayRow] = try await client.from("nutrition_plan_days").select()
            .eq("nutrition_plan_id", value: plan.id.uuidString)
            .order("position", ascending: true).execute().value
        let dayIDs = days.map { $0.id.uuidString }
        let meals: [NutritionMealRow] = dayIDs.isEmpty ? [] : try await client.from("nutrition_meals").select()
            .in("nutrition_plan_day_id", values: dayIDs).order("position", ascending: true).execute().value
        let mealIDs = meals.map { $0.id.uuidString }
        let foods: [NutritionFoodRow] = mealIDs.isEmpty ? [] : try await client.from("nutrition_meal_items").select()
            .in("meal_id", values: mealIDs).order("position", ascending: true).execute().value

        return ClientNutritionPlan(
            id: plan.id,
            title: plan.name,
            days: days.map { day in
                ClientNutritionDay(
                    id: day.id,
                    weekday: day.weekday ?? day.dayNumber,
                    name: day.name,
                    meals: meals.filter { $0.dayID == day.id }.map { meal in
                        ClientMeal(id: meal.id, name: meal.name, foods: foods.filter { $0.mealID == meal.id }.map { $0.clientFood })
                    }
                )
            },
            publishedAt: publishedAt,
            detailNotice: nil
        )
    }

    private func appointments(clientID: UUID, trainerID: UUID, today: Date) async throws -> [ClientAppointment] {
        let rows: [AppointmentRow] = try await client.from("appointments")
            .select("id,client_id,trainer_id,title,starts_at,ends_at,location,status,client_visible")
            .eq("client_id", value: clientID.uuidString)
            .eq("trainer_id", value: trainerID.uuidString)
            .eq("client_visible", value: true)
            .eq("status", value: "scheduled")
            .order("starts_at", ascending: true).limit(50).execute().value
        return rows.compactMap { row in
            guard row.clientID == clientID, row.trainerID == trainerID, row.isClientVisible,
                  row.status == "scheduled", let starts = clientParseDate(row.startsAt),
                  let ends = clientParseDate(row.endsAt), ends >= today else { return nil }
            return ClientAppointment(id: row.id, title: row.title, startsAt: starts, endsAt: ends, location: row.location)
        }
    }

    private func progress(clientID: UUID, trainerID: UUID) async throws -> [ClientProgressEntry] {
        let rows: [ProgressRow] = try await client.from("progress_entries")
            .select("id,client_id,trainer_id,recorded_at,weight_kg")
            .eq("client_id", value: clientID.uuidString)
            .eq("trainer_id", value: trainerID.uuidString)
            .order("recorded_at", ascending: true).limit(500).execute().value
        return rows.compactMap { row in
            guard row.clientID == clientID, row.trainerID == trainerID, let date = clientParseDate(row.recordedAt) else { return nil }
            return ClientProgressEntry(id: row.id, recordedAt: date, weightKg: row.weightKg, waistCm: nil, hipsCm: nil)
        }
    }

    private static func updates(from snapshot: ClientSnapshot) -> [ClientUpdate] {
        var updates: [ClientUpdate] = []
        if let plan = snapshot.workout { updates.append(ClientUpdate(id: plan.id, title: "Nuova scheda disponibile", detail: plan.title, date: plan.publishedAt, kind: .workout)) }
        if let plan = snapshot.nutrition { updates.append(ClientUpdate(id: plan.id, title: "Piano nutrizionale aggiornato", detail: plan.title, date: plan.publishedAt, kind: .nutrition)) }
        updates += snapshot.appointments.map { ClientUpdate(id: $0.id, title: "Appuntamento programmato", detail: $0.title, date: $0.startsAt, kind: .appointment) }
        return updates.sorted { $0.date > $1.date }
    }

    private static func publicEmail(_ value: String?) -> String? {
        guard let value, !value.hasSuffix("@accounts.gestionale.invalid") else { return nil }
        return value
    }

}

private struct ClientProfileRow: Decodable { let id: UUID; let username: String; let displayName: String; let role: String; let status: String; let isActive: Bool?; enum CodingKeys: String, CodingKey { case id, username, role, status; case displayName = "display_name"; case isActive = "is_active" } }
private struct ClientLinkRow: Decodable { let id: UUID; let authUserID: UUID?; let trainerID: UUID; let firstName: String; let lastName: String; let status: String; enum CodingKeys: String, CodingKey { case id, status; case authUserID = "auth_user_id"; case trainerID = "trainer_id"; case firstName = "first_name"; case lastName = "last_name" } }
private struct WorkoutPlanRow: Decodable { let id: UUID; let clientID: UUID?; let trainerID: UUID; let title: String; let status: String; let planKind: String; let publishedAt: String?; let startsOn: String?; let endsOn: String?; let durationWeeks: Int?; let currentWeek: Int; enum CodingKeys: String, CodingKey { case id, title, status; case clientID = "client_id"; case trainerID = "trainer_id"; case planKind = "plan_kind"; case publishedAt = "published_at"; case startsOn = "starts_on"; case endsOn = "ends_on"; case durationWeeks = "duration_weeks"; case currentWeek = "current_week" }; func isVisible(on date: Date, clientID: UUID, trainerID: UUID) -> Bool { guard self.clientID == clientID, self.trainerID == trainerID, status == "active", planKind == "client_plan", publishedAt != nil else { return false }; let day = Calendar.current.startOfDay(for: date); if let start = clientParseDay(startsOn), start > day { return false }; if let end = clientParseDay(endsOn), end < day { return false }; return true } }
private struct WorkoutDayRow: Decodable { let id: UUID; let workoutPlanID: UUID; let name: String; let weekday: Int?; let dayOrder: Int; enum CodingKeys: String, CodingKey { case id, name, weekday; case workoutPlanID = "workout_plan_id"; case dayOrder = "day_order" } }
private struct ExerciseRow: Decodable { let id: UUID?; let name: String; let videoURL: String?; enum CodingKeys: String, CodingKey { case id, name; case videoURL = "video_url" } }
private struct WorkoutExerciseRow: Decodable { let id: UUID; let workoutDayID: UUID; let sets: Int?; let repetitions: String?; let restSeconds: Int?; let loadKg: Double?; let notes: String?; let exerciseOrder: Int; let exercise: ExerciseRow?; enum CodingKeys: String, CodingKey { case id, sets, repetitions, notes, exercise; case workoutDayID = "workout_day_id"; case restSeconds = "rest_seconds"; case loadKg = "load_kg"; case exerciseOrder = "exercise_order" }; var clientExercise: ClientExercise { ClientExercise(id: id, name: exercise?.name ?? "Esercizio", sets: sets.map(String.init), repetitions: repetitions, restSeconds: restSeconds, loadKg: loadKg, notes: notes, videoURL: exercise?.videoURL.flatMap { URL(string: $0)?.scheme == "https" ? URL(string: $0) : nil }) } }
private struct NutritionPlanRow: Decodable { let id: UUID; let clientID: UUID?; let trainerID: UUID; let name: String; let status: String; let planKind: String; let publishedAt: String?; let startsOn: String?; let endsOn: String?; enum CodingKeys: String, CodingKey { case id, name, status; case clientID = "client_id"; case trainerID = "trainer_id"; case planKind = "plan_kind"; case publishedAt = "published_at"; case startsOn = "starts_on"; case endsOn = "ends_on" }; func isVisible(on date: Date, clientID: UUID, trainerID: UUID) -> Bool { guard self.clientID == clientID, self.trainerID == trainerID, status == "active", planKind == "client_plan", publishedAt != nil else { return false }; let day = Calendar.current.startOfDay(for: date); if let start = clientParseDay(startsOn), start > day { return false }; if let end = clientParseDay(endsOn), end < day { return false }; return true } }
private struct NutritionDayRow: Decodable { let id: UUID; let nutritionPlanID: UUID; let dayNumber: Int; let name: String; let position: Int; let weekday: Int?; enum CodingKeys: String, CodingKey { case id, name, position, weekday; case nutritionPlanID = "nutrition_plan_id"; case dayNumber = "day_number" } }
private struct NutritionMealRow: Decodable { let id: UUID; let dayID: UUID; let name: String; let position: Int; enum CodingKeys: String, CodingKey { case id, name, position; case dayID = "nutrition_plan_day_id" } }
private struct NutritionFoodRow: Decodable { let id: UUID; let mealID: UUID; let foodName: String; let quantity: Double?; let unit: String; let position: Int; enum CodingKeys: String, CodingKey { case id, quantity, unit, position; case mealID = "meal_id"; case foodName = "food_name" }; var clientFood: ClientFood { ClientFood(id: id, name: foodName, quantity: quantity, unit: unit) } }
private struct AppointmentRow: Decodable { let id: UUID; let clientID: UUID; let trainerID: UUID; let title: String; let startsAt: String; let endsAt: String; let location: String?; let status: String; let isClientVisible: Bool; enum CodingKeys: String, CodingKey { case id, title, location, status; case clientID = "client_id"; case trainerID = "trainer_id"; case startsAt = "starts_at"; case endsAt = "ends_at"; case isClientVisible = "client_visible" } }
private struct ProgressRow: Decodable { let id: UUID; let clientID: UUID; let trainerID: UUID; let recordedAt: String; let weightKg: Double?; enum CodingKeys: String, CodingKey { case id; case clientID = "client_id"; case trainerID = "trainer_id"; case recordedAt = "recorded_at"; case weightKg = "weight_kg" } }

fileprivate func clientParseDate(_ value: String?) -> Date? {
    guard let value else { return nil }
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let date = formatter.date(from: value) { return date }
    formatter.formatOptions = [.withInternetDateTime]
    return formatter.date(from: value) ?? clientParseDay(value)
}

fileprivate func clientParseDay(_ value: String?) -> Date? {
    guard let value else { return nil }
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter.date(from: value)
}
