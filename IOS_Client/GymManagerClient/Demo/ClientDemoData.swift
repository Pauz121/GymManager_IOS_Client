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
            sessions: [ClientWorkoutSession(id: sessionID, name: "Upper Body 2", weekday: ClientDateLogic.weekday(for: now), durationMinutes: 58, exercises: exercises)],
            todaySessionID: sessionID, publishedAt: now.addingTimeInterval(-86_400)
        )
        let nutritionID = UUID(uuidString: "DE000000-0000-0000-0000-000000000020")!
        let mealNames = ["Colazione", "Spuntino", "Pranzo", "Merenda", "Cena"]
        let foods = [
            [ClientFood(id: UUID(uuidString: "DE000000-0000-0000-0000-000000000041")!, name: "Yogurt greco", quantity: 170, unit: "g"), ClientFood(id: UUID(uuidString: "DE000000-0000-0000-0000-000000000042")!, name: "Fiocchi d’avena", quantity: 40, unit: "g")],
            [ClientFood(id: UUID(uuidString: "DE000000-0000-0000-0000-000000000043")!, name: "Frutta fresca", quantity: 1, unit: "pz")],
            [ClientFood(id: UUID(uuidString: "DE000000-0000-0000-0000-000000000044")!, name: "Riso basmati", quantity: 90, unit: "g"), ClientFood(id: UUID(uuidString: "DE000000-0000-0000-0000-000000000045")!, name: "Pollo", quantity: 160, unit: "g")],
            [ClientFood(id: UUID(uuidString: "DE000000-0000-0000-0000-000000000046")!, name: "Pane integrale", quantity: 60, unit: "g")],
            [ClientFood(id: UUID(uuidString: "DE000000-0000-0000-0000-000000000047")!, name: "Salmone", quantity: 180, unit: "g"), ClientFood(id: UUID(uuidString: "DE000000-0000-0000-0000-000000000048")!, name: "Verdure", quantity: 200, unit: "g")]
        ]
        let mealIDs = (51...55).map { UUID(uuidString: String(format: "DE000000-0000-0000-0000-%012d", $0))! }
        let meals = zip(zip(mealIDs, mealNames), foods).map { ClientMeal(id: $0.0.0, name: $0.0.1, foods: $0.1) }
        let nutrition = ClientNutritionPlan(
            id: nutritionID, title: "Piano quotidiano",
            days: [ClientNutritionDay(id: UUID(uuidString: "DE000000-0000-0000-0000-000000000050")!, weekday: ClientDateLogic.weekday(for: now), name: "Oggi", meals: meals)],
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
