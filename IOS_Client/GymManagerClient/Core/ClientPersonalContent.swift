import Foundation

enum ClientPersonalPlanStatus: String, Codable, CaseIterable, Sendable {
    case draft, active, archived
}

struct ClientPersonalExercise: Identifiable, Codable, Equatable, Sendable {
    var id: UUID
    var catalogExerciseID: UUID?
    var catalogSourceKey: String? = nil
    var name: String
    var muscleGroup: String
    var sets: Int
    var repetitions: String
    var restSeconds: Int
    var loadKg: Double?
    var effortTarget: String
    var notes: String
    var videoURL: URL?
    var primaryMuscles: [ClientMuscleRegion]? = nil
    var secondaryMuscles: [ClientMuscleRegion]? = nil
    var movementPattern: ClientMovementPattern? = nil
    var compatibleEquipment: Set<ClientTrainingEquipment>? = nil
    var exerciseKind: ClientExerciseKind? = nil
    var animationKey: String? = nil
    var technique: String? = nil

    func asClientExercise() -> ClientExercise {
        ClientExercise(
            id: id, name: name, sets: String(max(1, sets)), repetitions: repetitions,
            restSeconds: max(0, restSeconds), loadKg: loadKg,
            notes: [effortTarget, notes].filter { !$0.isEmpty }.joined(separator: " · "), videoURL: videoURL,
            catalogExerciseID: catalogExerciseID, catalogSourceKey: catalogSourceKey,
            primaryMuscles: primaryMuscles, secondaryMuscles: secondaryMuscles,
            movementPattern: movementPattern, animationKey: animationKey, technique: technique
        )
    }
}

struct ClientPersonalWorkoutSession: Identifiable, Codable, Equatable, Sendable {
    var id: UUID
    var name: String
    var weekday: Int?
    var durationMinutes: Int? = nil
    var exercises: [ClientPersonalExercise]
}

struct ClientPersonalWorkoutPlan: Identifiable, Codable, Equatable, Sendable {
    var id: UUID
    var title: String
    var status: ClientPersonalPlanStatus
    var sessions: [ClientPersonalWorkoutSession]
    var createdAt: Date
    var updatedAt: Date
    var source: ClientPersonalWorkoutPlanSource? = nil
    var durationWeeks: Int? = nil
    var generationAnswers: ClientWorkoutQuestionnaireAnswers? = nil
    var progression: ClientWorkoutProgressionRule? = nil
    var validation: ClientWorkoutPlanValidation? = nil

    func asClientPlan(today: Date = Date()) -> ClientWorkoutPlan {
        let weekday = ClientDateLogic.weekday(for: today)
        let mapped = sessions.map {
            ClientWorkoutSession(
                id: $0.id, name: $0.name, weekday: $0.weekday, durationMinutes: $0.durationMinutes,
                exercises: $0.exercises.map { $0.asClientExercise() }
            )
        }
        return ClientWorkoutPlan(
            id: id, title: title, startsOn: nil, endsOn: nil, currentWeek: 1,
            sessions: mapped, todaySessionID: mapped.first(where: { $0.weekday == weekday })?.id,
            publishedAt: updatedAt
        )
    }
}

struct ClientPersonalFood: Identifiable, Codable, Equatable, Sendable {
    var id: UUID
    var catalogFoodID: UUID?
    var name: String
    var quantityGrams: Double
    var caloriesPer100g: Double
    var proteinPer100g: Double?
    var carbsPer100g: Double?
    var fatPer100g: Double?

    var calories: Double { max(0, quantityGrams) * max(0, caloriesPer100g) / 100 }
    var protein: Double { max(0, quantityGrams) * max(0, proteinPer100g ?? 0) / 100 }
    var carbs: Double { max(0, quantityGrams) * max(0, carbsPer100g ?? 0) / 100 }
    var fat: Double { max(0, quantityGrams) * max(0, fatPer100g ?? 0) / 100 }

    func asClientFood() -> ClientFood {
        ClientFood(id: id, name: name, quantity: quantityGrams, unit: "g", caloriesKcal: calories)
    }
}

struct ClientPersonalMeal: Identifiable, Codable, Equatable, Sendable {
    var id: UUID
    var name: String
    var foods: [ClientPersonalFood]
    var calories: Double { foods.reduce(0) { $0 + $1.calories } }
    var protein: Double { foods.reduce(0) { $0 + $1.protein } }
    var carbs: Double { foods.reduce(0) { $0 + $1.carbs } }
    var fat: Double { foods.reduce(0) { $0 + $1.fat } }
}

struct ClientPersonalNutritionDay: Identifiable, Codable, Equatable, Sendable {
    var id: UUID
    var weekday: Int
    var name: String
    var meals: [ClientPersonalMeal]
}

struct ClientPersonalNutritionPlan: Identifiable, Codable, Equatable, Sendable {
    var id: UUID
    var title: String
    var status: ClientPersonalPlanStatus
    var days: [ClientPersonalNutritionDay]
    var createdAt: Date
    var updatedAt: Date

    func asClientPlan() -> ClientNutritionPlan {
        ClientNutritionPlan(
            id: id, title: title, startsOn: nil, endsOn: nil,
            days: days.map { day in
                ClientNutritionDay(
                    id: day.id, weekday: day.weekday, name: day.name,
                    meals: day.meals.map { meal in
                        ClientMeal(id: meal.id, name: meal.name, foods: meal.foods.map { $0.asClientFood() })
                    }
                )
            },
            publishedAt: updatedAt, detailNotice: "Piano personale · modificabile"
        )
    }
}

struct ClientPersonalMealTemplate: Identifiable, Codable, Equatable, Sendable {
    var id: UUID
    var name: String
    var meal: ClientPersonalMeal
    var updatedAt: Date
}

struct ClientExerciseCatalogItem: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let name: String
    let muscleGroup: String?
    let videoURL: URL?
    let instructions: String?
    let sourceKey: String?
    let primaryMuscles: [ClientMuscleRegion]
    let secondaryMuscles: [ClientMuscleRegion]
    let movementPattern: ClientMovementPattern?
    let compatibleEquipment: Set<ClientTrainingEquipment>
    let kind: ClientExerciseKind?
    let minimumExperience: ClientTrainingExperience?
    let animationKey: String?

    init(
        id: UUID,
        name: String,
        muscleGroup: String?,
        videoURL: URL?,
        instructions: String? = nil,
        sourceKey: String? = nil,
        primaryMuscles: [ClientMuscleRegion] = [],
        secondaryMuscles: [ClientMuscleRegion] = [],
        movementPattern: ClientMovementPattern? = nil,
        compatibleEquipment: Set<ClientTrainingEquipment> = [],
        kind: ClientExerciseKind? = nil,
        minimumExperience: ClientTrainingExperience? = nil,
        animationKey: String? = nil
    ) {
        self.id = id
        self.name = name
        self.muscleGroup = muscleGroup
        self.videoURL = videoURL
        self.instructions = instructions
        self.sourceKey = sourceKey
        self.primaryMuscles = primaryMuscles
        self.secondaryMuscles = secondaryMuscles
        self.movementPattern = movementPattern
        self.compatibleEquipment = compatibleEquipment
        self.kind = kind
        self.minimumExperience = minimumExperience
        self.animationKey = animationKey
    }

    func enriched(
        sourceKey: String?,
        primaryMuscles: [ClientMuscleRegion],
        secondaryMuscles: [ClientMuscleRegion],
        movementPattern: ClientMovementPattern?,
        compatibleEquipment: Set<ClientTrainingEquipment>,
        kind: ClientExerciseKind?,
        minimumExperience: ClientTrainingExperience?,
        animationKey: String?
    ) -> ClientExerciseCatalogItem {
        ClientExerciseCatalogItem(
            id: id, name: name, muscleGroup: muscleGroup, videoURL: videoURL,
            instructions: instructions, sourceKey: sourceKey,
            primaryMuscles: primaryMuscles, secondaryMuscles: secondaryMuscles,
            movementPattern: movementPattern, compatibleEquipment: compatibleEquipment,
            kind: kind, minimumExperience: minimumExperience, animationKey: animationKey
        )
    }
}

struct ClientFoodCatalogItem: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let name: String
    let caloriesPer100g: Double
    let proteinPer100g: Double?
    let carbsPer100g: Double?
    let fatPer100g: Double?
}

struct ClientPersonalContentState: Codable, Equatable, Sendable {
    var workoutPlans: [ClientPersonalWorkoutPlan]
    var nutritionPlans: [ClientPersonalNutritionPlan]
    var mealTemplates: [ClientPersonalMealTemplate]

    static let empty = ClientPersonalContentState(workoutPlans: [], nutritionPlans: [], mealTemplates: [])
    var activeWorkout: ClientPersonalWorkoutPlan? { workoutPlans.first { $0.status == .active } }
    var activeNutrition: ClientPersonalNutritionPlan? { nutritionPlans.first { $0.status == .active } }

    func merging(_ other: ClientPersonalContentState) -> ClientPersonalContentState {
        ClientPersonalContentState(
            workoutPlans: Self.merge(workoutPlans, other.workoutPlans, id: \.id, updatedAt: \.updatedAt),
            nutritionPlans: Self.merge(nutritionPlans, other.nutritionPlans, id: \.id, updatedAt: \.updatedAt),
            mealTemplates: Self.merge(mealTemplates, other.mealTemplates, id: \.id, updatedAt: \.updatedAt)
        )
    }

    private static func merge<Value>(
        _ first: [Value],
        _ second: [Value],
        id: KeyPath<Value, UUID>,
        updatedAt: KeyPath<Value, Date>
    ) -> [Value] {
        var values: [UUID: Value] = [:]
        for value in first + second {
            let key = value[keyPath: id]
            if let existing = values[key], existing[keyPath: updatedAt] > value[keyPath: updatedAt] { continue }
            values[key] = value
        }
        return values.values.sorted { $0[keyPath: updatedAt] > $1[keyPath: updatedAt] }
    }
}

struct ClientPersonalContentStore {
    private let defaults: UserDefaults
    init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    private func key(_ userID: UUID) -> String { "gymmanager.client.personal.\(userID.uuidString.lowercased())" }

    func load(userID: UUID) -> ClientPersonalContentState {
        guard let data = defaults.data(forKey: key(userID)),
              let content = try? JSONDecoder().decode(ClientPersonalContentState.self, from: data) else { return .empty }
        return content
    }

    func save(_ content: ClientPersonalContentState, userID: UUID) throws {
        defaults.set(try JSONEncoder().encode(content), forKey: key(userID))
    }
}
