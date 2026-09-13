import Foundation

#if DEBUG
enum ClientDemoData {
    static let identity = ClientIdentity(
        authUserID: UUID(uuidString: "DE000000-0000-0000-0000-000000000001")!,
        clientID: UUID(uuidString: "DE000000-0000-0000-0000-000000000002"),
        trainerID: UUID(uuidString: "DE000000-0000-0000-0000-000000000003"),
        mode: .trainerConnected,
        firstName: "Giulia",
        lastName: "Demo",
        displayName: "Giulia Demo",
        username: "giulia.demo",
        email: "giulia@example.invalid",
        trainerName: "Luca Bianchi"
    )

    static let snapshot: ClientSnapshot = {
        let workoutID = UUID(uuidString: "DE000000-0000-0000-0000-000000000010")!
        let sessionID = UUID(uuidString: "DE000000-0000-0000-0000-000000000011")!
        let nutritionID = UUID(uuidString: "DE000000-0000-0000-0000-000000000020")!
        let now = Date()
        let workout = ClientWorkoutPlan(
            id: workoutID, title: "Forza e movimento", startsOn: "2026-09-01", endsOn: "2026-10-31", currentWeek: 2,
            sessions: [ClientWorkoutSession(id: sessionID, name: "Total body", weekday: ClientDateLogic.weekday(for: now), durationMinutes: 52, exercises: [
                ClientExercise(id: UUID(), name: "Goblet squat", sets: "4", repetitions: "10", restSeconds: 90, loadKg: 16, notes: "Movimento controllato.", videoURL: nil),
                ClientExercise(id: UUID(), name: "Rematore", sets: "3", repetitions: "12", restSeconds: 75, loadKg: 12, notes: nil, videoURL: nil)
            ])], todaySessionID: sessionID, publishedAt: now.addingTimeInterval(-86_400)
        )
        let nutrition = ClientNutritionPlan(
            id: nutritionID, title: "Equilibrio quotidiano",
            days: [ClientNutritionDay(id: UUID(), weekday: ClientDateLogic.weekday(for: now), name: "Oggi", meals: [
                ClientMeal(id: UUID(), name: "Colazione", foods: [ClientFood(id: UUID(), name: "Yogurt greco", quantity: 170, unit: "g"), ClientFood(id: UUID(), name: "Fiocchi d’avena", quantity: 40, unit: "g")]),
                ClientMeal(id: UUID(), name: "Pranzo", foods: [ClientFood(id: UUID(), name: "Riso basmati", quantity: 90, unit: "g"), ClientFood(id: UUID(), name: "Verdure", quantity: 200, unit: "g")])
            ])], publishedAt: now.addingTimeInterval(-172_800), detailNotice: nil
        )
        let appointment = ClientAppointment(id: UUID(), title: "Check mensile", startsAt: now.addingTimeInterval(172_800), endsAt: now.addingTimeInterval(176_400), location: "Studio GymManager")
        return ClientSnapshot(
            workout: workout,
            nutrition: nutrition,
            appointments: [appointment],
            progress: [
                ClientProgressEntry(id: UUID(), recordedAt: now.addingTimeInterval(-2_592_000), weightKg: 68.4, waistCm: 74, hipsCm: 96),
                ClientProgressEntry(id: UUID(), recordedAt: now, weightKg: 67.6, waistCm: 73, hipsCm: 95)
            ],
            updates: [ClientUpdate(id: workoutID, title: "Nuova scheda disponibile", detail: "Forza e movimento", date: now.addingTimeInterval(-86_400), kind: .workout)],
            warnings: []
        )
    }()
}
#endif
