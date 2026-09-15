import SwiftUI

struct ClientHomeView: View {
    let identity: ClientIdentity
    let snapshot: ClientSnapshot
    let source: ClientDataSource
    @Binding var selectedTab: ClientTab
    @EnvironmentObject private var session: ClientSessionStore
    @EnvironmentObject private var healthKit: HealthKitStepService
    @EnvironmentObject private var avatarStore: ClientAvatarStore
    @Environment(\.scenePhase) private var scenePhase
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

    private var todayWorkoutExecution: ClientWorkoutExecution? {
        guard let todayWorkout else { return nil }
        return session.workoutExecution(sessionID: todayWorkout.id)
    }

    private var todayMealProgress: (completed: Int, total: Int) {
        guard let todayNutrition else { return (0, 0) }
        return (todayNutrition.meals.filter { session.activity.isMealCompleted($0.id) }.count, todayNutrition.meals.count)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                stepsCard
                ClientSectionHeader(title: "Priorità", detail: "Oggi", symbol: "bolt.fill")
                workoutCard
                nutritionCard
                if identity.mode == .standalone { standaloneActions }
                contextCards

                ForEach(snapshot.warnings, id: \.self) { warning in
                    Label(warning, systemImage: "exclamationmark.triangle.fill")
                        .font(.footnote).foregroundStyle(ClientClay.warning).clayCard(padding: 14)
                }
            }
            .padding(.horizontal, ClientClay.pagePadding).padding(.vertical, 18)
        }
        .clientPage()
        .navigationTitle("Oggi")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable {
            await session.refresh()
            await healthKit.refreshIfPreviouslyRequested()
        }
        .task {
            await healthKit.refreshIfPreviouslyRequested()
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(60))
                guard !Task.isCancelled else { return }
                await healthKit.refreshIfPreviouslyRequested()
            }
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task { await healthKit.refreshIfPreviouslyRequested() }
        }
        .fullScreenCover(item: $presentedWorkout) { workout in
            if let plan = snapshot.workout {
                ClientWorkoutExecutionView(plan: plan, workoutSession: workout)
            }
        }
    }

    private var header: some View {
        HStack(spacing: 13) {
            NavigationLink {
                ClientAccountView(identity: identity, source: source)
            } label: {
                ClientProfileAvatar(
                    image: avatarStore.image(for: identity.authUserID),
                    initials: initials,
                    size: 52
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Apri l’account di \(identity.firstName)")
            .accessibilityHint("Mostra profilo, foto e sicurezza")

            VStack(alignment: .leading, spacing: 3) {
                Text("OGGI")
                    .font(.caption.weight(.bold)).tracking(1.1).foregroundStyle(ClientClay.accent)
                Text("Ciao, \(identity.firstName)")
                    .font(.system(.title2, design: .rounded, weight: .heavy))
                    .foregroundStyle(ClientClay.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                Text(Date.now.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                    .font(.caption).foregroundStyle(ClientClay.secondaryInk)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var initials: String {
        "\(identity.firstName.first.map(String.init) ?? "")\(identity.lastName.first.map(String.init) ?? "")"
    }

    private var dayStatusHeadline: String {
        if todayWorkoutExecution?.isCompleted == true, todayMealProgress.completed == todayMealProgress.total, todayMealProgress.total > 0 {
            return "Giornata quasi completata"
        }
        if todayWorkout != nil, todayWorkoutExecution?.isCompleted != true {
            return "Il prossimo passo è il workout"
        }
        if todayMealProgress.total > todayMealProgress.completed {
            return "Continua con il tuo piano"
        }
        return homeAgendaTasks.contains(where: { !$0.isCompleted }) ? "Hai attività da completare" : "Sei in pari con la giornata"
    }

    private func dayStatusMetric(value: String, title: String, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Image(systemName: symbol).font(.caption.weight(.bold)).foregroundStyle(ClientClay.accentSoft)
            Text(value).font(.subheadline.weight(.bold)).foregroundStyle(.white).lineLimit(1).minimumScaleFactor(0.72)
            Text(title).font(.caption2).foregroundStyle(.white.opacity(0.66)).lineLimit(1)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.09), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
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
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Label("Nutrizione di oggi", systemImage: "leaf.fill").font(.headline).foregroundStyle(ClientClay.sage)
                        Text(nutrition.title).font(.caption).foregroundStyle(ClientClay.secondaryInk).lineLimit(1)
                    }
                    Spacer()
                    Button { selectedTab = .nutrition } label: {
                        Image(systemName: "arrow.up.right").font(.subheadline.weight(.bold))
                            .frame(width: 38, height: 38)
                            .background(ClientClay.sage.opacity(0.12), in: Circle())
                    }
                    .accessibilityLabel("Apri il piano nutrizionale")
                }
                HStack(spacing: 18) {
                    ClientCaloriePie(
                        value: day.caloriesKcal == nil ? 0 : completedCalories,
                        total: day.caloriesKcal ?? 1,
                        valueText: day.caloriesKcal.map { _ in "\(Int(completedCalories.rounded()))" } ?? "--",
                        detail: day.caloriesKcal.map { "di \(Int($0.rounded())) kcal" } ?? "kcal non disponibili",
                        size: 114
                    )
                    VStack(alignment: .leading, spacing: 5) {
                        Text(day.name).font(.title3.weight(.bold)).foregroundStyle(ClientClay.ink)
                        Text(completed == day.meals.count ? "Piano completato" : "\(day.meals.count - completed) pasti da completare")
                            .font(.subheadline).foregroundStyle(ClientClay.secondaryInk)
                        ClientProgressSegmentBar(completed: completed, total: day.meals.count, tint: ClientClay.sage)
                        Text("\(completed) di \(day.meals.count) completati")
                            .font(.caption.weight(.semibold)).foregroundStyle(ClientClay.sage)
                    }
                }
                ForEach(day.meals) { meal in
                    mealToggle(meal)
                }
            }
            .clayCard(padding: 18)
            .overlay(alignment: .topLeading) {
                Capsule().fill(ClientClay.sage).frame(width: 54, height: 4).padding(.leading, 20)
            }
        } else if identity.mode == .trainerConnected {
            ClientEmptyState(symbol: "leaf", title: "Nutrizione non programmata", message: "Nessun pasto è disponibile per oggi.")
        }
    }

    private func mealToggle(_ meal: ClientMeal) -> some View {
        let completed = session.activity.isMealCompleted(meal.id)
        return Button {
            withAnimation(.snappy(duration: 0.3)) { session.toggleMealCompletion(meal.id) }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: completed ? "checkmark" : "circle")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(completed ? .white : ClientClay.secondaryInk)
                    .frame(width: 32, height: 32)
                    .background(completed ? ClientClay.sage : ClientClay.surfaceElevated, in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text(meal.name).font(.body.weight(.semibold)).foregroundStyle(ClientClay.ink)
                    Text(completed ? "Completato" : "Da completare")
                        .font(.caption2.weight(.semibold)).foregroundStyle(completed ? ClientClay.sage : ClientClay.secondaryInk)
                }
                Spacer()
                Text(meal.caloriesKcal.map { "\(Int($0.rounded())) kcal" } ?? "-- kcal")
                    .font(.caption.weight(.semibold)).foregroundStyle(ClientClay.secondaryInk)
            }
            .padding(.horizontal, 11).padding(.vertical, 8)
            .frame(minHeight: 50)
            .background(completed ? ClientClay.sageSoft.opacity(0.72) : ClientClay.inset, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
            .overlay { RoundedRectangle(cornerRadius: 15, style: .continuous).stroke(completed ? ClientClay.sage.opacity(0.24) : ClientClay.border) }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(meal.name), \(completed ? "completato" : "da completare")")
        .accessibilityHint("Tocca due volte per cambiare lo stato del pasto")
    }

    @ViewBuilder private var stepsCard: some View {
        if let demo = demoSteps {
            dailyHero(stepCount: demo.count, target: demo.target, sourceDetail: "Dati demo · nessun dato reale")
        } else {
            switch healthKit.state {
            case .ready(let sample):
                dailyHero(stepCount: sample.count, target: 10_000, sourceDetail: "Apple Salute · \(sample.date.formatted(date: .omitted, time: .shortened))")
            case .loading:
                dailyHero(stepCount: nil, target: 10_000, sourceDetail: "Lettura da Apple Salute…")
            case .unavailable:
                dailyHero(stepCount: nil, target: 10_000, sourceDetail: "Apple Salute non disponibile")
            case .noData, .failed:
                dailyHero(stepCount: nil, target: 10_000, sourceDetail: "Passi non disponibili", actionTitle: "Riprova")
            case .notRequested:
                dailyHero(stepCount: nil, target: 10_000, sourceDetail: "Collega Apple Salute", actionTitle: "Collega")
            }
        }
    }

    private func dailyHero(stepCount: Int?, target: Int, sourceDetail: String, actionTitle: String? = nil) -> some View {
        let meals = todayMealProgress
        let pendingAgenda = homeAgendaTasks.filter { !$0.isCompleted }.count
        let workoutStatus = todayWorkout == nil ? "Riposo" : todayWorkoutExecution?.isCompleted == true ? "Fatto" : "Da fare"
        let workoutSymbol = todayWorkoutExecution?.isCompleted == true ? "checkmark" : todayWorkout == nil ? "moon.fill" : "dumbbell.fill"

        return VStack(alignment: .leading, spacing: 16) {
            header
            Divider().overlay(.white.opacity(0.13))
            VStack(alignment: .leading, spacing: 5) {
                Text("IL TUO OGGI").font(.caption.weight(.bold)).tracking(1.3).foregroundStyle(.white.opacity(0.66))
                Text(dayStatusHeadline).font(.system(.title2, design: .rounded, weight: .bold)).foregroundStyle(.white)
            }
            ViewThatFits {
                HStack(spacing: 18) { stepsRing(stepCount: stepCount, target: target); stepsCopy(sourceDetail: sourceDetail, actionTitle: actionTitle) }
                VStack(alignment: .leading, spacing: 14) { stepsRing(stepCount: stepCount, target: target); stepsCopy(sourceDetail: sourceDetail, actionTitle: actionTitle) }
            }
            ViewThatFits {
                HStack(spacing: 8) {
                    dayStatusMetric(value: workoutStatus, title: "Workout", symbol: workoutSymbol)
                    dayStatusMetric(value: meals.total == 0 ? "—" : "\(meals.completed)/\(meals.total)", title: "Pasti", symbol: "fork.knife")
                    dayStatusMetric(value: "\(pendingAgenda)", title: "Attività", symbol: "checklist")
                }
                VStack(spacing: 8) {
                    dayStatusMetric(value: workoutStatus, title: "Workout", symbol: workoutSymbol)
                    dayStatusMetric(value: meals.total == 0 ? "—" : "\(meals.completed)/\(meals.total)", title: "Pasti", symbol: "fork.knife")
                    dayStatusMetric(value: "\(pendingAgenda)", title: "Attività", symbol: "checklist")
                }
            }
        }
        .premiumCard(padding: 18)
        .accessibilityElement(children: .contain)
    }

    private func stepsRing(stepCount: Int?, target: Int) -> some View {
        ClientCircularProgress(
            value: Double(stepCount ?? 0), total: Double(target), title: "Passi di oggi",
            valueText: stepCount?.formatted() ?? "—", detail: "di \(target.formatted())",
            tint: stepCount.map { $0 >= target ? ClientClay.sage : ClientClay.accent } ?? ClientClay.tertiaryInk,
            size: 118, textColor: .white, detailColor: .white.opacity(0.66)
        )
    }

    private func stepsCopy(sourceDetail: String, actionTitle: String?) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Label("Passi di oggi", systemImage: "figure.walk").font(.headline).foregroundStyle(.white)
            Text(sourceDetail).font(.caption).foregroundStyle(.white.opacity(0.68))
            if let actionTitle {
                Button(actionTitle) { Task { await healthKit.requestAccessAndRefresh() } }
                    .font(.subheadline.weight(.bold)).foregroundStyle(ClientClay.accentSoft)
                    .frame(minHeight: 44).contentShape(Rectangle())
            }
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

    private func stepsUnavailable(_ message: String, actionTitle: String?, inverse: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Passi di oggi", systemImage: "figure.walk").font(.headline).foregroundStyle(inverse ? Color.white : ClientClay.accent)
            Text(message).font(.subheadline).foregroundStyle(inverse ? Color.white.opacity(0.7) : ClientClay.secondaryInk)
            if let actionTitle {
                Button(actionTitle) { Task { await healthKit.requestAccessAndRefresh() } }
                    .font(.subheadline.weight(.semibold)).foregroundStyle(inverse ? ClientClay.accentSoft : ClientClay.accent)
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
