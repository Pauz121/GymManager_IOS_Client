import Foundation

#if DEBUG
enum ClientDemoPersona: String, CaseIterable, Sendable {
    case trainerConnected
    case standalone
}

enum ClientDemoData {
    private static let workoutID = UUID(uuidString: "DE000000-0000-0000-0000-000000000010")!
    private static let upperSessionID = UUID(uuidString: "DE000000-0000-0000-0000-000000000011")!
    private static let benchExerciseID = UUID(uuidString: "DE000000-0000-0000-0000-000000000012")!
    private static let runningPlanID = UUID(uuidString: "DE000000-0000-0000-0000-000000000030")!

    static func identity(for persona: ClientDemoPersona) -> ClientIdentity {
        switch persona {
        case .trainerConnected:
            return ClientIdentity(
                authUserID: UUID(uuidString: "DE000000-0000-0000-0000-000000000001")!,
                clientID: UUID(uuidString: "DE000000-0000-0000-0000-000000000002"),
                trainerID: UUID(uuidString: "DE000000-0000-0000-0000-000000000003"),
                mode: .trainerConnected,
                firstName: "Giulio", lastName: "Demo", displayName: "Giulio Demo",
                username: "ctrainer.demo", email: "ctrainer@example.invalid", trainerName: "Trainer Demo"
            )
        case .standalone:
            return ClientIdentity(
                authUserID: UUID(uuidString: "DE000000-0000-0000-0000-000000000101")!,
                clientID: nil, trainerID: nil, mode: .standalone,
                firstName: "Giulio", lastName: "Demo", displayName: "Giulio Demo",
                username: "cclient.demo", email: "cclient@example.invalid", trainerName: nil
            )
        }
    }

    static func snapshot(for persona: ClientDemoPersona) -> ClientSnapshot {
        persona == .trainerConnected ? trainerSnapshot : .empty
    }

    static func stepCount(for identity: ClientIdentity) -> Int? {
        identity.mode == .trainerConnected ? 6_482 : 3_240
    }

    static let stepTarget = 10_000

    static func activity(for persona: ClientDemoPersona, now: Date = Date()) -> ClientActivityState {
        guard persona == .trainerConnected else { return .empty }
        let loads = [70.0, 75.0, 77.5, 80.0]
        let workoutDays = [8, 7, 3, 2]
        let workouts = zip(workoutDays, loads).compactMap { days, load -> ClientWorkoutExecution? in
            guard let date = Calendar.current.date(byAdding: .day, value: -days, to: now) else { return nil }
            return completedWorkout(at: date, benchLoad: load)
        }

        let runSpecs: [(days: Int, distance: Double, minutes: Double)] = [
            (14, 3, 18), (11, 5, 28), (8, 7, 38),
            (5, 10, 56), (3, 10, 54), (1, 10, 52)
        ]
        let runs = runSpecs.compactMap { spec -> ClientRunningResult? in
            guard let completedAt = Calendar.current.date(byAdding: .day, value: -spec.days, to: now) else { return nil }
            let duration = spec.minutes * 60
            return ClientRunningResult(
                id: UUID(), planID: runningPlanID, completedAt: completedAt,
                durationSeconds: duration, distanceKm: spec.distance,
                route: route(distanceKm: spec.distance, durationSeconds: duration, completedAt: completedAt),
                maximumSpeedKmh: spec.distance / (duration / 3_600) * 1.08,
                effort: min(5, max(2, Int(spec.distance / 2))),
                note: spec.distance >= 10 ? "Progressivo controllato." : "Ritmo regolare."
            )
        }

        let today = trainerSnapshot.nutrition?.days.first { $0.weekday == ClientDateLogic.weekday(for: now) }
        let meals = (today?.meals.prefix(2) ?? []).map {
            ClientMealCompletion(id: UUID(), mealID: $0.id, dayKey: ClientDayKey.string(for: now), completedAt: now)
        }
        return ClientActivityState(workouts: workouts, meals: meals, restTimer: nil, activeRun: nil, runningResults: runs)
    }

    static func agenda(for persona: ClientDemoPersona, now: Date = Date()) -> [PersonalAgendaTask] {
        guard persona == .trainerConnected else { return [] }
        return [
            PersonalAgendaTask(id: UUID(), title: "Preparare la borsa palestra", date: Calendar.current.date(byAdding: .hour, value: 2, to: now), notes: "Fasce e borraccia", kind: .reminder, priority: .normal, isCompleted: false),
            PersonalAgendaTask(id: UUID(), title: "Mobilità 10 minuti", date: Calendar.current.date(byAdding: .hour, value: -1, to: now), notes: "Routine anche e caviglie", kind: .activity, priority: .high, isCompleted: true)
        ]
    }

    private static let trainerSnapshot: ClientSnapshot = {
        let now = Date()
        let exercises = [
            ClientExercise(id: benchExerciseID, name: "Panca piana", sets: "4", repetitions: "8", restSeconds: 120, loadKg: 80, notes: "Piedi saldi e fermo controllato al petto.", videoURL: nil),
            ClientExercise(id: UUID(uuidString: "DE000000-0000-0000-0000-000000000013")!, name: "Rematore manubrio", sets: "4", repetitions: "10", restSeconds: 90, loadKg: 28, notes: "Mantieni il busto stabile.", videoURL: nil),
            ClientExercise(id: UUID(uuidString: "DE000000-0000-0000-0000-000000000014")!, name: "Military press", sets: "3", repetitions: "8", restSeconds: 90, loadKg: 32.5, notes: nil, videoURL: nil),
            ClientExercise(id: UUID(uuidString: "DE000000-0000-0000-0000-000000000015")!, name: "Lat machine", sets: "3", repetitions: "12", restSeconds: 75, loadKg: 55, notes: nil, videoURL: nil),
            ClientExercise(id: UUID(uuidString: "DE000000-0000-0000-0000-000000000016")!, name: "Alzate laterali", sets: "3", repetitions: "15", restSeconds: 60, loadKg: 8, notes: "Movimento pulito, senza slancio.", videoURL: nil),
            ClientExercise(id: UUID(uuidString: "DE000000-0000-0000-0000-000000000017")!, name: "Pushdown cavo", sets: "3", repetitions: "12", restSeconds: 60, loadKg: 25, notes: nil, videoURL: nil)
        ]
        let workout = ClientWorkoutPlan(
            id: workoutID, title: "Ipertrofia A", startsOn: "2026-09-01", endsOn: "2026-10-31", currentWeek: 4,
            sessions: [
                ClientWorkoutSession(id: upperSessionID, name: "Upper Body 2", weekday: ClientDateLogic.weekday(for: now), durationMinutes: 58, exercises: exercises),
                ClientWorkoutSession(id: UUID(uuidString: "DE000000-0000-0000-0000-000000000018")!, name: "Lower Body", weekday: 3, durationMinutes: 55, exercises: demoExercises(prefix: "Lower", names: ["Squat", "Romanian deadlift", "Leg curl"])),
                ClientWorkoutSession(id: UUID(uuidString: "DE000000-0000-0000-0000-000000000019")!, name: "Full Body", weekday: 5, durationMinutes: 50, exercises: demoExercises(prefix: "Full", names: ["Goblet squat", "Chest press", "Pulley"]))
            ],
            todaySessionID: upperSessionID, publishedAt: now.addingTimeInterval(-86_400)
        )

        let nutritionID = UUID(uuidString: "DE000000-0000-0000-0000-000000000020")!
        let mealNames = ["Colazione", "Spuntino", "Pranzo", "Merenda", "Cena"]
        func meals() -> [ClientMeal] {
            let foods = [
                [ClientFood(id: UUID(), name: "Yogurt greco", quantity: 170, unit: "g", caloriesKcal: 110), ClientFood(id: UUID(), name: "Fiocchi d’avena", quantity: 40, unit: "g", caloriesKcal: 152)],
                [ClientFood(id: UUID(), name: "Frutta fresca", quantity: 1, unit: "pz", caloriesKcal: 85)],
                [ClientFood(id: UUID(), name: "Riso basmati", quantity: 90, unit: "g", caloriesKcal: 324), ClientFood(id: UUID(), name: "Pollo", quantity: 160, unit: "g", caloriesKcal: 264)],
                [ClientFood(id: UUID(), name: "Pane integrale", quantity: 60, unit: "g", caloriesKcal: 150)],
                [ClientFood(id: UUID(), name: "Salmone", quantity: 180, unit: "g", caloriesKcal: 374), ClientFood(id: UUID(), name: "Verdure", quantity: 200, unit: "g", caloriesKcal: 70)]
            ]
            return zip(mealNames, foods).map { ClientMeal(id: UUID(), name: $0.0, foods: $0.1) }
        }
        let dayNames = ["Lunedì", "Martedì", "Mercoledì", "Giovedì", "Venerdì", "Sabato", "Domenica"]
        let nutritionDays = (1...7).map { weekday in
            ClientNutritionDay(id: UUID(), weekday: weekday, name: dayNames[weekday - 1], meals: meals())
        }
        let nutrition = ClientNutritionPlan(id: nutritionID, title: "Performance settimanale", days: nutritionDays, publishedAt: now.addingTimeInterval(-172_800), detailNotice: nil)
        let pastPlans = [
            archivedPlan(id: "DE000000-0000-0000-0000-000000000041", title: "Forza 1", starts: "2026-03-01", ends: "2026-05-31", publishedAt: now.addingTimeInterval(-15_552_000)),
            archivedPlan(id: "DE000000-0000-0000-0000-000000000042", title: "Ricondizionamento", starts: "2025-11-01", ends: "2026-01-31", publishedAt: now.addingTimeInterval(-27_648_000))
        ]
        return ClientSnapshot(
            workout: workout,
            nutrition: nutrition,
            appointments: [ClientAppointment(id: UUID(), title: "Check mensile", startsAt: now.addingTimeInterval(172_800), endsAt: now.addingTimeInterval(176_400), location: "Studio GymManager")],
            progress: [
                ClientProgressEntry(id: UUID(), recordedAt: now.addingTimeInterval(-10_368_000), weightKg: 80.2, waistCm: 87, hipsCm: 100),
                ClientProgressEntry(id: UUID(), recordedAt: now.addingTimeInterval(-7_776_000), weightKg: 79.5, waistCm: 86, hipsCm: 99.5),
                ClientProgressEntry(id: UUID(), recordedAt: now.addingTimeInterval(-5_184_000), weightKg: 78.8, waistCm: 85, hipsCm: 99),
                ClientProgressEntry(id: UUID(), recordedAt: now.addingTimeInterval(-2_592_000), weightKg: 78.4, waistCm: 84, hipsCm: 98),
                ClientProgressEntry(id: UUID(), recordedAt: now, weightKg: 77.6, waistCm: 83, hipsCm: 97)
            ],
            updates: [ClientUpdate(id: workoutID, title: "Nuova scheda disponibile", detail: "Ipertrofia A", date: now.addingTimeInterval(-86_400), kind: .workout)],
            warnings: [], capabilities: ClientCapabilities(runningEnabled: true),
            runningPlan: ClientRunningPlan(id: runningPlanID, title: "Corsa facile", detail: "Ritmo conversazionale, senza forzare.", targetMinutes: 30, targetDistanceKm: 5),
            workoutHistory: pastPlans
        )
    }()

    private static func completedWorkout(at date: Date, benchLoad: Double) -> ClientWorkoutExecution? {
        guard let plan = trainerSnapshot.workout,
              let workout = plan.sessions.first(where: { $0.id == upperSessionID }) else { return nil }
        let exerciseLogs = workout.exercises.map { exercise in
            ClientExerciseLog(
                id: UUID(), exerciseID: exercise.id,
                note: exercise.id == benchExerciseID ? "Tecnica stabile, ultima serie impegnativa." : "",
                sets: (1...exercise.setCount).map { number in
                    ClientSetLog(
                        id: UUID(), number: number, prescribedRepetitions: exercise.repetitions,
                        prescribedLoadKg: exercise.loadKg, actualRepetitions: exercise.suggestedActualRepetitions,
                        actualLoadKg: exercise.id == benchExerciseID ? benchLoad : exercise.loadKg,
                        completedAt: date.addingTimeInterval(TimeInterval(number * 180))
                    )
                }
            )
        }
        return ClientWorkoutExecution(
            id: UUID(), planID: plan.id, sessionID: workout.id, dayKey: ClientDayKey.string(for: date),
            startedAt: date, completedAt: date.addingTimeInterval(3_300), exercises: exerciseLogs,
            feedback: ClientWorkoutFeedback(effort: 4, quality: 4, hasPain: false, note: "Sessione demo completata.")
        )
    }

    private static func route(distanceKm: Double, durationSeconds: TimeInterval, completedAt: Date) -> [ClientRoutePoint] {
        let segments = max(2, Int(ceil(distanceKm * 2)))
        let startedAt = completedAt.addingTimeInterval(-durationSeconds)
        return (0...segments).map { index in
            let ratio = Double(index) / Double(segments)
            return ClientRoutePoint(
                latitude: 41.9028 + (distanceKm * ratio / 111.2), longitude: 12.4964,
                timestamp: startedAt.addingTimeInterval(durationSeconds * ratio), horizontalAccuracy: 5,
                speedMetersPerSecond: distanceKm * 1_000 / durationSeconds,
                elapsedSeconds: durationSeconds * ratio
            )
        }
    }

    private static func demoExercises(prefix: String, names: [String]) -> [ClientExercise] {
        names.enumerated().map { index, name in
            ClientExercise(id: UUID(), name: name, sets: index == 0 ? "4" : "3", repetitions: index == 0 ? "8" : "10", restSeconds: index == 0 ? 120 : 90, loadKg: Double(40 + index * 15), notes: "Esecuzione controllata.", videoURL: nil)
        }
    }

    private static func archivedPlan(id: String, title: String, starts: String, ends: String, publishedAt: Date) -> ClientWorkoutPlan {
        ClientWorkoutPlan(
            id: UUID(uuidString: id)!, title: title, startsOn: starts, endsOn: ends, currentWeek: 8,
            sessions: [
                ClientWorkoutSession(id: UUID(), name: "Giorno A", weekday: nil, durationMinutes: 50, exercises: demoExercises(prefix: "A", names: ["Panca piana", "Squat", "Rematore"])),
                ClientWorkoutSession(id: UUID(), name: "Giorno B", weekday: nil, durationMinutes: 48, exercises: demoExercises(prefix: "B", names: ["Military press", "Stacco rumeno", "Lat machine"]))
            ],
            todaySessionID: nil, publishedAt: publishedAt
        )
    }
}
#endif
