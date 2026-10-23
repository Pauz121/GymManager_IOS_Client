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
        try await saveWorkoutPlans([plan], userID: userID)
    }

    func saveWorkoutPlans(_ plans: [ClientPersonalWorkoutPlan], userID: UUID) async throws {
        try await requireStandaloneWorkoutOwner(userID)
        let rows = plans.map { PersonalWorkoutWriteRow(id: $0.id, ownerUserID: userID, title: $0.title, status: $0.status.rawValue, planPayload: $0) }
        // One PostgREST write: new activation and old archives succeed or fail together.
        try await client.from("client_personal_workout_plans").upsert(rows, onConflict: "id").execute()
    }

    /// Defense in depth for normal app calls. RLS remains mandatory against races/direct REST calls.
    private func requireStandaloneWorkoutOwner(_ userID: UUID) async throws {
        let active = try await client.auth.session
        guard active.user.id == userID else { throw ClientWorkoutGenerationEligibility.deniedUnauthenticated }
        struct Profile: Decodable { let role: String; let status: String; let is_active: Bool }
        struct Link: Decodable { let id: UUID }
        let profiles: [Profile] = try await client.from("profiles").select("role,status,is_active")
            .eq("id", value: userID.uuidString).limit(1).execute().value
        guard profiles.first?.role == "client", profiles.first?.status == "active", profiles.first?.is_active == true else {
            throw ClientWorkoutGenerationEligibility.deniedUnauthenticated
        }
        let links: [Link] = try await client.from("clients").select("id")
            .eq("auth_user_id", value: userID.uuidString).limit(1).execute().value
        guard links.isEmpty else { throw ClientWorkoutGenerationEligibility.deniedTrainerManaged }
        try Task.checkCancellation()
    }

    func activeWorkoutPlans(userID: UUID) async throws -> [ClientPersonalWorkoutPlan] {
        let rows: [PersonalWorkoutRow] = try await client.from("client_personal_workout_plans")
            .select("id,title,status,plan_payload").eq("owner_user_id", value: userID.uuidString)
            .eq("status", value: "active").execute().value
        return rows.map(\.plan)
    }

    func workoutPlan(id: UUID, userID: UUID) async throws -> ClientPersonalWorkoutPlan? {
        let rows: [PersonalWorkoutRow] = try await client.from("client_personal_workout_plans")
            .select("id,title,status,plan_payload")
            .eq("id", value: id.uuidString)
            .eq("owner_user_id", value: userID.uuidString)
            .limit(1)
            .execute().value
        return rows.first?.plan
    }

    func deleteWorkoutPlan(_ id: UUID) async throws {
        try await client.from("client_personal_workout_plans").delete().eq("id", value: id.uuidString).execute()
    }

    func saveNutritionPlan(_ plan: ClientPersonalNutritionPlan, userID: UUID) async throws {
        try await saveNutritionPlans([plan], userID: userID)
    }

    func saveNutritionPlans(_ plans: [ClientPersonalNutritionPlan], userID: UUID) async throws {
        try await requireStandaloneNutritionOwner(userID)
        if plans.contains(where: { $0.generationMetadata != nil || $0.creationAnswers?.coachProfile != nil }) {
            let catalog = try await foodCatalog()
            for plan in plans where plan.generationMetadata != nil || plan.creationAnswers?.coachProfile != nil {
                let context = ClientNutritionCoachContext(mode: .standalone, profile: plan.creationAnswers?.coachProfile)
                guard ClientNutritionPlanValidator.inspect(plan, context: context, catalog: catalog).isEmpty else {
                    throw ClientNutritionGenerationEligibility.invalidPlan
                }
            }
        }
        let rows = plans.map { PersonalNutritionWriteRow(id: $0.id, ownerUserID: userID, title: $0.title, status: $0.status.rawValue, planPayload: $0) }
        try await client.from("client_personal_nutrition_plans").upsert(rows, onConflict: "id").execute()
    }

    /// Fresh server-backed preflight; RLS is still required against direct REST and linking races.
    private func requireStandaloneNutritionOwner(_ userID: UUID) async throws {
        let session = try await client.auth.session
        guard session.user.id == userID else { throw ClientNutritionGenerationEligibility.deniedUnauthenticated }
        struct Profile: Decodable { let role: String; let status: String; let is_active: Bool }
        struct Link: Decodable { let id: UUID }
        let profiles: [Profile] = try await client.from("profiles").select("role,status,is_active")
            .eq("id", value: userID.uuidString).limit(1).execute().value
        guard profiles.first?.role == "client", profiles.first?.status == "active", profiles.first?.is_active == true else {
            throw ClientNutritionGenerationEligibility.deniedUnauthenticated
        }
        let links: [Link] = try await client.from("clients").select("id")
            .eq("auth_user_id", value: userID.uuidString).limit(1).execute().value
        guard links.isEmpty else { throw ClientNutritionGenerationEligibility.deniedTrainerManaged }
        try Task.checkCancellation()
    }

    func activeNutritionPlans(userID: UUID) async throws -> [ClientPersonalNutritionPlan] {
        let rows: [PersonalNutritionRow] = try await client.from("client_personal_nutrition_plans")
            .select("id,title,status,plan_payload").eq("owner_user_id", value: userID.uuidString)
            .eq("status", value: "active").execute().value
        return rows.map(\.plan)
    }

    func deleteNutritionPlan(_ id: UUID) async throws {
        try await client.from("client_personal_nutrition_plans").delete().eq("id", value: id.uuidString).execute()
    }

    func nutritionPlan(id: UUID, userID: UUID) async throws -> ClientPersonalNutritionPlan? {
        let rows: [PersonalNutritionRow] = try await client.from("client_personal_nutrition_plans")
            .select("id,title,status,plan_payload")
            .eq("id", value: id.uuidString).eq("owner_user_id", value: userID.uuidString)
            .limit(1).execute().value
        return rows.first?.plan
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
        var request = client.from("exercises")
            .select("*,muscle_links:exercise_muscle_groups(relevance,muscle_group:muscle_groups(id,name,source_key))")
            .eq("is_system", value: true)
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { request = request.ilike("name", pattern: "%\(trimmed)%") }
        let rows: [ExerciseCatalogRow] = try await request.order("name").limit(120).execute().value
        return rows.map(\.catalogItem).map(ClientExerciseMetadataNormalizer.enrich)
    }

    func exerciseCatalog() async throws -> [ClientExerciseCatalogItem] {
        let rows: [ExerciseCatalogRow] = try await client.from("exercises")
            .select("*,muscle_links:exercise_muscle_groups(relevance,muscle_group:muscle_groups(id,name,source_key))")
            .eq("is_system", value: true)
            .order("name")
            .limit(500)
            .execute().value
        return rows.map(\.catalogItem).map(ClientExerciseMetadataNormalizer.enrich)
    }

    func searchFoods(_ query: String) async throws -> [ClientFoodCatalogItem] {
        var request = client.from("food_references")
            .select("id,name,name_it,serving_amount,serving_unit,calories_kcal,protein_g,carbohydrates_g,fat_g,category,provider,metadata,external_food_id,source_url,updated_at")
            .is("trainer_id", value: nil)
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { request = request.or("name.ilike.%\(trimmed)%,name_it.ilike.%\(trimmed)%") }
        let rows: [FoodCatalogRow] = try await request.order("name").limit(60).execute().value
        return rows.compactMap(\.catalogItem)
    }

    func foodCatalog() async throws -> [ClientFoodCatalogItem] {
        let rows: [FoodCatalogRow] = try await client.from("food_references")
            .select("id,name,name_it,serving_amount,serving_unit,calories_kcal,protein_g,carbohydrates_g,fat_g,category,provider,metadata,external_food_id,source_url,updated_at")
            .is("trainer_id", value: nil).order("name").limit(500).execute().value
        return rows.compactMap(\.catalogItem)
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
    let id: UUID; let name: String; let meal: ClientPersonalMeal; let updatedAt: String
    var template: ClientPersonalMealTemplate {
        ClientPersonalMealTemplate(id: id, name: name, meal: meal, updatedAt: clientPersonalParseDate(updatedAt) ?? .distantPast)
    }
    enum CodingKeys: String, CodingKey { case id, name; case meal = "meal_payload"; case updatedAt = "updated_at" }
}

private func clientPersonalParseDate(_ value: String) -> Date? {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let date = formatter.date(from: value) { return date }
    formatter.formatOptions = [.withInternetDateTime]
    return formatter.date(from: value)
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

private typealias ExerciseCatalogRow = ClientExerciseCatalogRecord

private struct FoodCatalogRow: Decodable {
    let id: UUID; let name: String; let nameIT: String?; let servingAmount: Double; let caloriesKcal: Double?
    let proteinG: Double?; let carbohydratesG: Double?; let fatG: Double?
    let servingUnit: String?; let category: String?; let provider: String?; let metadata: FoodCatalogMetadata?
    let externalFoodID: String?; let sourceURL: String?; let updatedAt: String?
    var reviewedEvidence: ClientNutritionFoodEvidence? {
        guard let e = metadata?.nutritionCoachReview, e.canonicalID == id, e.sourceID == externalFoodID,
              e.source.rawValue == provider, e.sourceURL == sourceURL, e.cacheRevision == updatedAt,
              e.sourceServingAmount == servingAmount, e.sourceServingUnit == servingUnit else { return nil }
        return e
    }
    var catalogItem: ClientFoodCatalogItem? {
        ClientNutritionCatalog.normalize(
            id: id, name: nameIT ?? name, servingAmount: servingAmount, servingUnit: servingUnit ?? "",
            calories: caloriesKcal, protein: proteinG, carbs: carbohydratesG, fat: fatG,
            category: category, provider: provider, gramsPerPiece: metadata?.gramsPerPiece, nutritionEvidence: reviewedEvidence
        )
    }
    enum CodingKeys: String, CodingKey {
        case id, name, category, provider, metadata; case servingUnit = "serving_unit"; case nameIT = "name_it"; case servingAmount = "serving_amount"; case caloriesKcal = "calories_kcal"
        case externalFoodID = "external_food_id"; case sourceURL = "source_url"; case updatedAt = "updated_at"
        case proteinG = "protein_g"; case carbohydratesG = "carbohydrates_g"; case fatG = "fat_g"
    }
}

private struct FoodCatalogMetadata: Decodable {
    let gramsPerPiece: Double?
    let nutritionCoachReview: ClientNutritionFoodEvidence?
    enum CodingKeys: String, CodingKey { case gramsPerPiece = "grams_per_piece"; case nutritionCoachReview = "nutrition_coach_review" }
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        // Malformed optional review must not break manual search or be admitted as safe.
        gramsPerPiece = try? values.decode(Double.self, forKey: .gramsPerPiece)
        nutritionCoachReview = try? values.decode(ClientNutritionFoodEvidence.self, forKey: .nutritionCoachReview)
    }
}
