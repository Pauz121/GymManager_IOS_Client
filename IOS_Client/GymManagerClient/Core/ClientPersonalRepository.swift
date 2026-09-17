import Foundation
import Supabase

@MainActor
struct ClientPersonalRepository {
    private let client: SupabaseClient
    init(client: SupabaseClient = ClientSupabaseProvider.client) { self.client = client }

    func content(userID: UUID) async throws -> ClientPersonalContentState {
        let workoutRows: [PersonalWorkoutRow] = try await client.from("client_personal_workout_plans")
            .select("id,title,status,plan_payload")
            .eq("owner_user_id", value: userID.uuidString)
            .order("updated_at", ascending: false).execute().value
        let nutritionRows: [PersonalNutritionRow] = try await client.from("client_personal_nutrition_plans")
            .select("id,title,status,plan_payload")
            .eq("owner_user_id", value: userID.uuidString)
            .order("updated_at", ascending: false).execute().value
        let templateRows: [PersonalMealTemplateRow] = try await client.from("client_personal_meal_templates")
            .select("id,name,meal_payload,updated_at")
            .eq("owner_user_id", value: userID.uuidString)
            .order("updated_at", ascending: false).execute().value
        return ClientPersonalContentState(
            workoutPlans: workoutRows.map(\.plan),
            nutritionPlans: nutritionRows.map(\.plan),
            mealTemplates: templateRows.map(\.template)
        )
    }

    func saveWorkoutPlan(_ plan: ClientPersonalWorkoutPlan, userID: UUID) async throws {
        try await client.from("client_personal_workout_plans").upsert(
            PersonalWorkoutWriteRow(id: plan.id, ownerUserID: userID, title: plan.title, status: plan.status.rawValue, planPayload: plan),
            onConflict: "id"
        ).execute()
    }

    func deleteWorkoutPlan(_ id: UUID) async throws {
        try await client.from("client_personal_workout_plans").delete().eq("id", value: id.uuidString).execute()
    }

    func saveNutritionPlan(_ plan: ClientPersonalNutritionPlan, userID: UUID) async throws {
        try await client.from("client_personal_nutrition_plans").upsert(
            PersonalNutritionWriteRow(id: plan.id, ownerUserID: userID, title: plan.title, status: plan.status.rawValue, planPayload: plan),
            onConflict: "id"
        ).execute()
    }

    func deleteNutritionPlan(_ id: UUID) async throws {
        try await client.from("client_personal_nutrition_plans").delete().eq("id", value: id.uuidString).execute()
    }

    func saveMealTemplate(_ template: ClientPersonalMealTemplate, userID: UUID) async throws {
        try await client.from("client_personal_meal_templates").upsert(
            PersonalMealTemplateWriteRow(id: template.id, ownerUserID: userID, name: template.name, mealPayload: template.meal),
            onConflict: "id"
        ).execute()
    }

    func savePersonalExercise(_ exercise: ClientPersonalExercise, userID: UUID) async throws {
        try await client.from("client_personal_exercises").upsert(
            PersonalExerciseWriteRow(
                id: exercise.id, ownerUserID: userID, name: exercise.name,
                muscleGroup: exercise.muscleGroup.isEmpty ? nil : exercise.muscleGroup,
                notes: exercise.notes.isEmpty ? nil : exercise.notes,
                videoURL: exercise.videoURL?.absoluteString
            ),
            onConflict: "owner_user_id,name"
        ).execute()
    }

    func searchExercises(_ query: String) async throws -> [ClientExerciseCatalogItem] {
        var request = client.from("exercises").select("id,name,muscle_group,video_url").eq("is_system", value: true)
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { request = request.ilike("name", pattern: "%\(trimmed)%") }
        let rows: [ExerciseCatalogRow] = try await request.order("name").limit(60).execute().value
        return rows.map { ClientExerciseCatalogItem(id: $0.id, name: $0.name, muscleGroup: $0.muscleGroup, videoURL: $0.videoURL.flatMap(URL.init(string:))) }
    }

    func searchFoods(_ query: String) async throws -> [ClientFoodCatalogItem] {
        var request = client.from("food_references")
            .select("id,name,name_it,serving_amount,calories_kcal,protein_g,carbohydrates_g,fat_g")
            .is("trainer_id", value: nil)
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { request = request.or("name.ilike.%\(trimmed)%,name_it.ilike.%\(trimmed)%") }
        let rows: [FoodCatalogRow] = try await request.order("name").limit(60).execute().value
        return rows.compactMap { row in
            guard row.servingAmount > 0, let calories = row.caloriesKcal else { return nil }
            let factor = 100 / row.servingAmount
            return ClientFoodCatalogItem(
                id: row.id, name: row.nameIT ?? row.name, caloriesPer100g: calories * factor,
                proteinPer100g: row.proteinG.map { $0 * factor }, carbsPer100g: row.carbohydratesG.map { $0 * factor },
                fatPer100g: row.fatG.map { $0 * factor }
            )
        }
    }

    func saveRunningResult(_ result: ClientRunningResult, userID: UUID) async throws {
        try await client.from("client_running_sessions").upsert(
            PersonalRunWriteRow(
                id: result.id, ownerUserID: userID, resultPayload: result,
                completedAt: result.completedAt, distanceKm: result.distanceKm, durationSeconds: result.durationSeconds
            ), onConflict: "id"
        ).execute()
    }
}

private struct PersonalWorkoutRow: Decodable {
    let id: UUID; let title: String; let status: String; let plan: ClientPersonalWorkoutPlan
    enum CodingKeys: String, CodingKey { case id, title, status; case plan = "plan_payload" }
}

private struct PersonalNutritionRow: Decodable {
    let id: UUID; let title: String; let status: String; let plan: ClientPersonalNutritionPlan
    enum CodingKeys: String, CodingKey { case id, title, status; case plan = "plan_payload" }
}

private struct PersonalMealTemplateRow: Decodable {
    let id: UUID; let name: String; let meal: ClientPersonalMeal; let updatedAt: Date
    var template: ClientPersonalMealTemplate { ClientPersonalMealTemplate(id: id, name: name, meal: meal, updatedAt: updatedAt) }
    enum CodingKeys: String, CodingKey { case id, name; case meal = "meal_payload"; case updatedAt = "updated_at" }
}

private struct PersonalWorkoutWriteRow: Encodable {
    let id: UUID; let ownerUserID: UUID; let title: String; let status: String; let planPayload: ClientPersonalWorkoutPlan
    let source = "self_created"
    enum CodingKeys: String, CodingKey { case id, title, status, source; case ownerUserID = "owner_user_id"; case planPayload = "plan_payload" }
}

private struct PersonalNutritionWriteRow: Encodable {
    let id: UUID; let ownerUserID: UUID; let title: String; let status: String; let planPayload: ClientPersonalNutritionPlan
    let source = "self_created"
    enum CodingKeys: String, CodingKey { case id, title, status, source; case ownerUserID = "owner_user_id"; case planPayload = "plan_payload" }
}

private struct PersonalMealTemplateWriteRow: Encodable {
    let id: UUID; let ownerUserID: UUID; let name: String; let mealPayload: ClientPersonalMeal
    enum CodingKeys: String, CodingKey { case id, name; case ownerUserID = "owner_user_id"; case mealPayload = "meal_payload" }
}

private struct PersonalExerciseWriteRow: Encodable {
    let id: UUID; let ownerUserID: UUID; let name: String; let muscleGroup: String?; let notes: String?; let videoURL: String?
    enum CodingKeys: String, CodingKey {
        case id, name, notes
        case ownerUserID = "owner_user_id"
        case muscleGroup = "muscle_group"
        case videoURL = "video_url"
    }
}

private struct PersonalRunWriteRow: Encodable {
    let id: UUID; let ownerUserID: UUID; let resultPayload: ClientRunningResult; let completedAt: Date
    let distanceKm: Double?; let durationSeconds: TimeInterval
    enum CodingKeys: String, CodingKey { case id; case ownerUserID = "owner_user_id"; case resultPayload = "result_payload"; case completedAt = "completed_at"; case distanceKm = "distance_km"; case durationSeconds = "duration_seconds" }
}

private struct ExerciseCatalogRow: Decodable {
    let id: UUID; let name: String; let muscleGroup: String?; let videoURL: String?
    enum CodingKeys: String, CodingKey { case id, name; case muscleGroup = "muscle_group"; case videoURL = "video_url" }
}

private struct FoodCatalogRow: Decodable {
    let id: UUID; let name: String; let nameIT: String?; let servingAmount: Double; let caloriesKcal: Double?
    let proteinG: Double?; let carbohydratesG: Double?; let fatG: Double?
    enum CodingKeys: String, CodingKey {
        case id, name; case nameIT = "name_it"; case servingAmount = "serving_amount"; case caloriesKcal = "calories_kcal"
        case proteinG = "protein_g"; case carbohydratesG = "carbohydrates_g"; case fatG = "fat_g"
    }
}
