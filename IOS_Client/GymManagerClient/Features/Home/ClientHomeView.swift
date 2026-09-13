import SwiftUI

struct ClientHomeView: View {
    let identity: ClientIdentity
    let snapshot: ClientSnapshot
    let source: ClientDataSource
    @Binding var selectedTab: ClientTab
    @EnvironmentObject private var session: ClientSessionStore
    @EnvironmentObject private var healthKit: HealthKitStepService
    @State private var presentedWorkout: ClientWorkoutSession?

    private var todayWorkout: ClientWorkoutSession? {
        guard let id = snapshot.workout?.todaySessionID else { return nil }
        return snapshot.workout?.sessions.first { $0.id == id }
    }

    private var todayNutrition: ClientNutritionDay? {
        snapshot.nutrition?.days.first { $0.weekday == ClientDateLogic.weekday(for: Date()) }
            ?? (snapshot.nutrition?.days.count == 1 ? snapshot.nutrition?.days.first : nil)
    }

    private var homeAgendaTasks: [PersonalAgendaTask] {
        session.agenda
            .filter { task in
                guard let date = task.date else { return true }
                return Calendar.current.isDateInToday(date)
            }
            .sorted {
                if $0.isCompleted != $1.isCompleted { return !$0.isCompleted }
                return ($0.date ?? .distantFuture) < ($1.date ?? .distantFuture)
            }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                stepsCard
                journey
                Text("Oggi").font(.title2.weight(.bold)).foregroundStyle(ClientClay.ink)
                workoutCard
                nutritionCard
                if identity.mode == .standalone { standaloneActions }
                contextCards

                ForEach(snapshot.warnings, id: \.self) { warning in
                    Label(warning, systemImage: "exclamationmark.triangle.fill")
                        .font(.footnote).foregroundStyle(ClientClay.warning).clayCard(padding: 14)
                }
            }
            .padding(20)
        }
        .clientPage()
        .navigationTitle("Oggi")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable {
            await session.refresh()
            if case .ready(_) = healthKit.state { try? await healthKit.refresh() }
        }
        .fullScreenCover(item: $presentedWorkout) { workout in
            if let plan = snapshot.workout {
                ClientWorkoutExecutionView(plan: plan, workoutSession: workout)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Ciao, \(identity.firstName) 👋")
                .font(.system(.largeTitle, design: .rounded, weight: .bold))
                .foregroundStyle(ClientClay.ink)
            Text(Date.now.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                .font(.subheadline).foregroundStyle(ClientClay.secondaryInk)
            ClientBadge(
                text: identity.mode == .trainerConnected ? "Con Trainer" : "Percorso autonomo",
                tint: identity.mode == .trainerConnected ? ClientClay.sage : ClientClay.warning,
                symbol: identity.mode == .trainerConnected ? "person.2.fill" : "figure.walk"
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder private var journey: some View {
        if let plan = snapshot.workout {
            let completed = session.activity.workouts.filter(\.isCompleted).count
            VStack(alignment: .leading, spacing: 7) {
                Text("Il tuo percorso").font(.caption.weight(.bold)).textCase(.uppercase).tracking(1)
                    .foregroundStyle(ClientClay.accent)
                HStack {
                    Label("Settimana \(plan.currentWeek)", systemImage: "calendar")
                    Spacer()
                    Text("\(completed) completati su questo iPhone")
                        .font(.caption).foregroundStyle(ClientClay.secondaryInk)
                }
            }
            .clayCard(padding: 15)
        }
    }

    @ViewBuilder private var workoutCard: some View {
        if let plan = snapshot.workout, let workout = todayWorkout {
            let execution = session.workoutExecution(sessionID: workout.id)
            VStack(alignment: .leading, spacing: 13) {
                HStack {
                    Label("Allenamento di oggi", systemImage: execution?.isCompleted == true ? "checkmark.circle.fill" : "dumbbell.fill")
                        .font(.headline).foregroundStyle(execution?.isCompleted == true ? ClientClay.sage : ClientClay.accent)
                    Spacer()
                    Text("\(workout.exercises.count) esercizi").font(.caption).foregroundStyle(ClientClay.secondaryInk)
                }
                Text(workout.name).font(.system(.title2, design: .rounded, weight: .bold))
                Text("\(plan.title) · Settimana \(plan.currentWeek)")
                    .font(.subheadline).foregroundStyle(ClientClay.secondaryInk)

                if execution?.isCompleted == true {
                    HStack {
                        Label("Allenamento completato", systemImage: "checkmark.seal.fill")
                        Spacer()
                        if let minutes = execution?.durationMinutes { Text("\(minutes) min") }
                    }
                    .font(.headline).foregroundStyle(ClientClay.sage)
                } else {
                    Button {
                        session.beginWorkout(plan: plan, workoutSession: workout)
                        presentedWorkout = workout
                    } label: {
                        Label(execution == nil ? "Inizia allenamento" : "Riprendi allenamento", systemImage: "play.fill")
                    }
                    .buttonStyle(ClayPrimaryButtonStyle())
                }
            }
            .clayCard()
        } else if snapshot.workout != nil {
            ClientEmptyState(symbol: "moon.zzz", title: "Oggi riposo", message: "Nessun allenamento è programmato per oggi.")
        } else {
            ClientEmptyState(
                symbol: "dumbbell",
                title: "Nessun allenamento per oggi",
                message: identity.mode == .standalone ? "Puoi iniziare dal tuo spazio personale o collegare un Trainer." : "Il Trainer non ha pubblicato una sessione per oggi."
            )
        }
    }

    @ViewBuilder private var nutritionCard: some View {
        if let nutrition = snapshot.nutrition, let day = todayNutrition, !day.meals.isEmpty {
            let completed = day.meals.filter { session.activity.isMealCompleted($0.id) }.count
            let completedCalories = day.meals
                .filter { session.activity.isMealCompleted($0.id) }
                .compactMap(\.caloriesKcal).reduce(0, +)
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("Nutrizione di oggi", systemImage: "leaf.fill").font(.headline).foregroundStyle(ClientClay.sage)
                    Spacer()
                    Button("Dettagli") { selectedTab = .nutrition }.font(.subheadline.weight(.semibold))
                }
                HStack(spacing: 16) {
                    ClientCaloriePie(
                        value: day.caloriesKcal == nil ? 0 : completedCalories,
                        total: day.caloriesKcal ?? 1,
                        valueText: day.caloriesKcal.map { "\(Int(completedCalories.rounded()))" } ?? "--",
                        detail: day.caloriesKcal.map { "di \(Int($0.rounded())) kcal" } ?? "kcal non disponibili",
                        size: 104
                    )
                    VStack(alignment: .leading, spacing: 5) {
                        Text(nutrition.title).font(.subheadline.weight(.semibold))
                        Text(day.name).font(.caption).foregroundStyle(ClientClay.secondaryInk)
                        Text("\(completed) / \(day.meals.count) pasti")
                            .font(.caption.weight(.semibold)).foregroundStyle(ClientClay.sage)
                    }
                }
                ForEach(day.meals) { meal in
                    mealToggle(meal)
                }
            }
            .clayCard()
        } else if identity.mode == .trainerConnected {
            ClientEmptyState(symbol: "leaf", title: "Nutrizione non programmata", message: "Nessun pasto è disponibile per oggi.")
        }
    }

    private func mealToggle(_ meal: ClientMeal) -> some View {
        let completed = session.activity.isMealCompleted(meal.id)
        return Button { session.toggleMealCompletion(meal.id) } label: {
            HStack(spacing: 12) {
                Image(systemName: completed ? "checkmark.circle.fill" : "circle")
                    .font(.title2).foregroundStyle(completed ? ClientClay.sage : ClientClay.secondaryInk)
                Text(meal.name).font(.body.weight(.medium)).foregroundStyle(ClientClay.ink)
                    .strikethrough(completed)
                Spacer()
                Text(meal.caloriesKcal.map { "\(Int($0.rounded())) kcal" } ?? "-- kcal")
                    .font(.caption.weight(.semibold)).foregroundStyle(ClientClay.secondaryInk)
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(meal.name), \(completed ? "completato" : "da completare")")
        .accessibilityHint("Tocca due volte per cambiare lo stato del pasto")
    }

    @ViewBuilder private var stepsCard: some View {
        if let demo = demoSteps {
            HStack(spacing: 18) {
                ClientCircularProgress(value: Double(demo.count), total: Double(demo.target), title: "Passi di oggi", valueText: demo.count.formatted(), detail: "di \(demo.target.formatted())", tint: ClientClay.accent)
                VStack(alignment: .leading, spacing: 7) {
                    Label("Passi di oggi", systemImage: "figure.walk").font(.headline).foregroundStyle(ClientClay.accent)
                    Text("Il movimento quotidiano in un colpo d’occhio.")
                        .font(.subheadline).foregroundStyle(ClientClay.secondaryInk)
                }
            }
            .clayCard()
        } else {
            HStack(spacing: 18) {
                switch healthKit.state {
                case .ready(let sample):
                    ClientCircularProgress(value: Double(sample.count), total: 10_000, title: "Passi di oggi", valueText: sample.count.formatted(), detail: "di 10.000", tint: ClientClay.accent)
                    VStack(alignment: .leading, spacing: 7) {
                        Label("Passi di oggi", systemImage: "figure.walk").font(.headline).foregroundStyle(ClientClay.accent)
                        Text("Dati letti da Apple Salute").font(.caption).foregroundStyle(ClientClay.secondaryInk)
                    }
                case .loading:
                    ProgressView("Lettura da Apple Salute…")
                case .unavailable:
                    stepsUnavailable("Apple Salute non è disponibile su questo dispositivo.", actionTitle: nil)
                case .noData, .failed:
                    stepsUnavailable("Passi non disponibili", actionTitle: "Riprova")
                case .notRequested:
                    stepsUnavailable("Collega Apple Salute per vedere i passi giornalieri.", actionTitle: "Collega")
                }
            }
            .clayCard()
        }
    }

    private var standaloneActions: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Il tuo spazio autonomo").font(.title3.weight(.bold))
            action("Crea il tuo piano allenamento", symbol: "dumbbell")
            action("Crea il tuo piano alimentare", symbol: "leaf")
            action("Registra un progresso", symbol: "chart.line.uptrend.xyaxis")
            Button { selectedTab = .space } label: { Label("Agenda", systemImage: "checklist") }
                .buttonStyle(ClaySecondaryButtonStyle())
            Button { selectedTab = .space } label: { Label("Hai un codice Trainer?", systemImage: "link") }
                .buttonStyle(ClaySecondaryButtonStyle())
        }
        .clayCard()
    }

    private func action(_ title: String, symbol: String) -> some View {
        Button { session.notice = "Questa funzione sarà disponibile nella prossima fase." } label: {
            Label(title, systemImage: symbol)
        }
        .buttonStyle(ClaySecondaryButtonStyle())
    }

    @ViewBuilder private var contextCards: some View {
        if identity.mode == .trainerConnected, let next = snapshot.appointments.first {
            VStack(alignment: .leading, spacing: 8) {
                ClientBadge(text: "Fissato dal Trainer", tint: ClientClay.accent, symbol: "calendar.badge.clock")
                Text(next.title).font(.headline)
                Text(next.startsAt.formatted(date: .abbreviated, time: .shortened)).foregroundStyle(ClientClay.secondaryInk)
                if let location = next.location { Label(location, systemImage: "mappin.and.ellipse").font(.subheadline) }
            }
            .clayCard()
        }

        if !homeAgendaTasks.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("La tua Agenda", systemImage: "checklist").font(.headline).foregroundStyle(ClientClay.sage)
                    Spacer()
                    Button("Apri") { selectedTab = .space }.font(.subheadline.weight(.semibold))
                }
                ForEach(homeAgendaTasks) { task in
                    Button { session.toggleAgendaTask(task.id) } label: {
                        HStack(spacing: 11) {
                            Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                                .font(.title3).foregroundStyle(task.isCompleted ? ClientClay.sage : ClientClay.secondaryInk)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(task.title).font(.subheadline.weight(.semibold)).foregroundStyle(ClientClay.ink).strikethrough(task.isCompleted)
                                if let date = task.date { Text(date.formatted(date: .omitted, time: .shortened)).font(.caption).foregroundStyle(ClientClay.secondaryInk) }
                            }
                            Spacer()
                        }
                        .frame(minHeight: 44)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(task.title), \(task.isCompleted ? "completata" : "da completare")")
                }
            }
            .clayCard(padding: 15)
        }
    }

    private func stepsUnavailable(_ message: String, actionTitle: String?) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Passi di oggi", systemImage: "figure.walk").font(.headline).foregroundStyle(ClientClay.accent)
            Text(message).font(.subheadline).foregroundStyle(ClientClay.secondaryInk)
            if let actionTitle {
                Button(actionTitle) { Task { await healthKit.requestAccessAndRefresh() } }
                    .font(.subheadline.weight(.semibold))
            }
        }
    }

    private var demoSteps: (count: Int, target: Int)? {
        #if DEBUG
        guard source == .demo, let count = ClientDemoData.stepCount(for: identity) else { return nil }
        return (count, ClientDemoData.stepTarget)
        #else
        return nil
        #endif
    }
}
