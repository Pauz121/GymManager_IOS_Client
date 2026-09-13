import Foundation

#if DEBUG
enum ClientDemoPersona: String, CaseIterable, Sendable {
    case trainerConnected
    case standalone
}

enum ClientDemoData {
    static func identity(for persona: ClientDemoPersona) -> ClientIdentity {
        switch persona {
        case .trainerConnected:
            return ClientIdentity(
                authUserID: UUID(uuidString: "DE000000-0000-0000-0000-000000000001")!,
                clientID: UUID(uuidString: "DE000000-0000-0000-0000-000000000002"),
                trainerID: UUID(uuidString: "DE000000-0000-0000-0000-000000000003"),
                mode: .trainerConnected,
                firstName: "Giulio",
                lastName: "Demo",
                displayName: "Giulio Demo",
                username: "ctrainer.demo",
                email: "ctrainer@example.invalid",
                trainerName: "Trainer Demo"
            )
        case .standalone:
            return ClientIdentity(
                authUserID: UUID(uuidString: "DE000000-0000-0000-0000-000000000101")!,
                clientID: nil,
                trainerID: nil,
                mode: .standalone,
                firstName: "Giulio",
                lastName: "Demo",
                displayName: "Giulio Demo",
                username: "cclient.demo",
                email: "cclient@example.invalid",
                trainerName: nil
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

    private static let trainerSnapshot: ClientSnapshot = {
        let now = Date()
        let workoutID = UUID(uuidString: "DE000000-0000-0000-0000-000000000010")!
        let sessionID = UUID(uuidString: "DE000000-0000-0000-0000-000000000011")!
        let exercises = [
            ClientExercise(id: UUID(uuidString: "DE000000-0000-0000-0000-000000000012")!, name: "Panca piana", sets: "4", repetitions: "8", restSeconds: 120, loadKg: 80, notes: "Piedi saldi e fermo controllato al petto.", videoURL: nil),
            ClientExercise(id: UUID(uuidString: "DE000000-0000-0000-0000-000000000013")!, name: "Rematore manubrio", sets: "4", repetitions: "10", restSeconds: 90, loadKg: 28, notes: "Mantieni il busto stabile.", videoURL: nil),
            ClientExercise(id: UUID(uuidString: "DE000000-0000-0000-0000-000000000014")!, name: "Military press", sets: "3", repetitions: "8", restSeconds: 90, loadKg: 32.5, notes: nil, videoURL: nil),
            ClientExercise(id: UUID(uuidString: "DE000000-0000-0000-0000-000000000015")!, name: "Lat machine", sets: "3", repetitions: "12", restSeconds: 75, loadKg: 55, notes: nil, videoURL: nil),
            ClientExercise(id: UUID(uuidString: "DE000000-0000-0000-0000-000000000016")!, name: "Alzate laterali", sets: "3", repetitions: "15", restSeconds: 60, loadKg: 8, notes: "Movimento pulito, senza slancio.", videoURL: nil),
            ClientExercise(id: UUID(uuidString: "DE000000-0000-0000-0000-000000000017")!, name: "Pushdown cavo", sets: "3", repetitions: "12", restSeconds: 60, loadKg: 25, notes: nil, videoURL: nil)
        ]
        let workout = ClientWorkoutPlan(
            id: workoutID, title: "Ipertrofia A", startsOn: "2026-09-01", endsOn: "2026-10-31", currentWeek: 4,
            sessions: [
                ClientWorkoutSession(id: sessionID, name: "Upper Body 2", weekday: ClientDateLogic.weekday(for: now), durationMinutes: 58, exercises: exercises),
                ClientWorkoutSession(id: UUID(uuidString: "DE000000-0000-0000-0000-000000000018")!, name: "Lower Body", weekday: 3, durationMinutes: 55, exercises: [
                    ClientExercise(id: UUID(), name: "Squat", sets: "4", repetitions: "6", restSeconds: 150, loadKg: 95, notes: "Discesa controllata.", videoURL: nil),
                    ClientExercise(id: UUID(), name: "Romanian deadlift", sets: "3", repetitions: "8", restSeconds: 120, loadKg: 80, notes: nil, videoURL: nil),
                    ClientExercise(id: UUID(), name: "Leg curl", sets: "3", repetitions: "12", restSeconds: 75, loadKg: 42.5, notes: nil, videoURL: nil)
                ]),
                ClientWorkoutSession(id: UUID(uuidString: "DE000000-0000-0000-0000-000000000019")!, name: "Full Body", weekday: 5, durationMinutes: 50, exercises: [
                    ClientExercise(id: UUID(), name: "Goblet squat", sets: "3", repetitions: "12", restSeconds: 75, loadKg: 30, notes: nil, videoURL: nil),
                    ClientExercise(id: UUID(), name: "Chest press", sets: "3", repetitions: "10", restSeconds: 90, loadKg: 50, notes: nil, videoURL: nil),
                    ClientExercise(id: UUID(), name: "Pulley", sets: "3", repetitions: "10", restSeconds: 90, loadKg: 50, notes: nil, videoURL: nil)
                ])
            ],
            todaySessionID: sessionID, publishedAt: now.addingTimeInterval(-86_400)
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
        let nutrition = ClientNutritionPlan(
            id: nutritionID, title: "Piano alimentare settimanale",
            days: nutritionDays,
            publishedAt: now.addingTimeInterval(-172_800), detailNotice: nil
        )
        let appointment = ClientAppointment(id: UUID(), title: "Check mensile", startsAt: now.addingTimeInterval(172_800), endsAt: now.addingTimeInterval(176_400), location: "Studio GymManager")
        let running = ClientRunningPlan(id: UUID(uuidString: "DE000000-0000-0000-0000-000000000030")!, title: "Corsa facile", detail: "Ritmo conversazionale, senza forzare.", targetMinutes: 30, targetDistanceKm: 5)
        return ClientSnapshot(
            workout: workout,
            nutrition: nutrition,
            appointments: [appointment],
            progress: [
                ClientProgressEntry(id: UUID(), recordedAt: now.addingTimeInterval(-2_592_000), weightKg: 78.4, waistCm: 84, hipsCm: 98),
                ClientProgressEntry(id: UUID(), recordedAt: now, weightKg: 77.6, waistCm: 83, hipsCm: 97)
            ],
            updates: [ClientUpdate(id: workoutID, title: "Nuova scheda disponibile", detail: "Ipertrofia A", date: now.addingTimeInterval(-86_400), kind: .workout)],
            warnings: [],
            capabilities: ClientCapabilities(runningEnabled: true),
            runningPlan: running
        )
    }()
}
#endif
