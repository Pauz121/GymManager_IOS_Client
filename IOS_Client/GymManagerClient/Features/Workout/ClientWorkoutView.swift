import SwiftUI

struct ClientWorkoutView: View {
    private enum Category: String, CaseIterable { case gym = "Palestra"; case running = "Corsa" }

    let snapshot: ClientSnapshot
    let identity: ClientIdentity
    @EnvironmentObject private var session: ClientSessionStore
    @State private var category: Category = .gym
    @State private var presentedWorkout: ClientWorkoutSession?

    private var plan: ClientWorkoutPlan? { snapshot.workout }
    private var todayWorkout: ClientWorkoutSession? {
        guard let id = plan?.todaySessionID else { return nil }
        return plan?.sessions.first { $0.id == id }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                ClientPageTitle("Allenamento", eyebrow: "Il tuo percorso", subtitle: "Apri la sessione di oggi e registra ogni serie con un solo tocco.")
                if snapshot.capabilities.runningEnabled, snapshot.runningPlan != nil {
                    Picker("Tipo di allenamento", selection: $category) {
                        ForEach(Category.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityLabel("Scegli palestra o corsa")
                }

                if category == .running, let runningPlan = snapshot.runningPlan {
                    ClientRunningView(plan: runningPlan)
                } else {
                    gymContent
                }
            }
            .padding(20)
        }
        .clientPage()
        .navigationTitle("Scheda")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Dettagli piano") { session.notice = plan.map { "\($0.title) · Settimana \($0.currentWeek)" } ?? "Nessun piano attivo." }
                    Button("Storico") { session.notice = "Lo storico completo sarà disponibile nella prossima fase." }
                    Button("Informazioni") { session.notice = "La programmazione del Trainer resta protetta e non modificabile." }
                } label: {
                    Image(systemName: "ellipsis.circle").frame(width: 44, height: 44)
                }
                .accessibilityLabel("Azioni piano")
            }
        }
        .fullScreenCover(item: $presentedWorkout) { workout in
            if let plan { ClientWorkoutExecutionView(plan: plan, workoutSession: workout) }
        }
    }

    @ViewBuilder private var gymContent: some View {
        if let plan {
            ReadOnlyPlanBadge()
            VStack(alignment: .leading, spacing: 7) {
                Text(plan.title).font(.system(.title2, design: .rounded, weight: .bold))
                Text("Settimana \(plan.currentWeek)").font(.subheadline).foregroundStyle(ClientClay.secondaryInk)
            }
            .clayCard()

            if let today = todayWorkout {
                todayCard(plan: plan, workout: today)
            } else {
                ClientEmptyState(symbol: "moon.zzz", title: "Oggi riposo", message: "Puoi consultare le altre sessioni senza avviarne una per errore.")
            }

            Text("Scheda completa").font(.title3.weight(.bold))
            ForEach(plan.sessions) { workout in
                NavigationLink {
                    ClientWorkoutSessionDetailView(plan: plan, workout: workout)
                } label: {
                    sessionCard(plan: plan, workout: workout)
                }
                .buttonStyle(.plain)
            }
        } else {
            ClientEmptyState(
                symbol: "dumbbell",
                title: "Nessun piano pubblicato",
                message: identity.mode == .standalone ? "Puoi collegare un Trainer; i piani personali arriveranno nella prossima fase." : "Il tuo Trainer non ha ancora pubblicato una scheda attiva."
            )
        }
    }

    private func todayCard(plan: ClientWorkoutPlan, workout: ClientWorkoutSession) -> some View {
        let execution = session.workoutExecution(sessionID: workout.id)
        return VStack(alignment: .leading, spacing: 12) {
            Label("Allenamento di oggi", systemImage: execution?.isCompleted == true ? "checkmark.circle.fill" : "play.circle.fill")
                .font(.headline).foregroundStyle(execution?.isCompleted == true ? ClientClay.sage : ClientClay.accent)
            Text(workout.name).font(.title2.weight(.bold))
            Text("\(workout.exercises.count) esercizi\(workout.durationMinutes.map { " · \($0) min" } ?? "")")
                .font(.subheadline).foregroundStyle(ClientClay.secondaryInk)
            if execution?.isCompleted == true {
                Label("Completato\(execution?.durationMinutes.map { " · \($0) min" } ?? "")", systemImage: "checkmark.seal.fill")
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
    }

    private func sessionCard(plan: ClientWorkoutPlan, workout: ClientWorkoutSession) -> some View {
        let execution = session.workoutExecution(sessionID: workout.id)
        return HStack(spacing: 14) {
            Image(systemName: execution?.isCompleted == true ? "checkmark.circle.fill" : workout.id == plan.todaySessionID ? "play.circle.fill" : "figure.strengthtraining.traditional")
                .font(.title2).foregroundStyle(execution?.isCompleted == true ? ClientClay.sage : workout.id == plan.todaySessionID ? ClientClay.accent : ClientClay.secondaryInk)
            VStack(alignment: .leading, spacing: 4) {
                Text(workout.name).font(.headline).foregroundStyle(ClientClay.ink)
                Text("\(workout.exercises.count) esercizi\(workout.durationMinutes.map { " · \($0) min" } ?? "")")
                    .font(.subheadline).foregroundStyle(ClientClay.secondaryInk)
                if execution?.isCompleted == true {
                    Text("Completato · consultabile").font(.caption.weight(.semibold)).foregroundStyle(ClientClay.sage)
                } else if workout.id == plan.todaySessionID {
                    Text("Allenamento di oggi").font(.caption.weight(.semibold)).foregroundStyle(ClientClay.accent)
                }
            }
            Spacer()
            Image(systemName: "chevron.right").font(.caption.weight(.bold)).foregroundStyle(ClientClay.secondaryInk)
        }
        .clayCard(padding: 15)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Apre gli esercizi di \(workout.name)")
    }
}

private struct ClientWorkoutSessionDetailView: View {
    let plan: ClientWorkoutPlan
    let workout: ClientWorkoutSession
    @EnvironmentObject private var session: ClientSessionStore
    @State private var showingExecution = false
    @State private var selectedExercise: ClientExercise?

    private var execution: ClientWorkoutExecution? {
        session.workoutExecution(sessionID: workout.id)
    }

    private var isToday: Bool { plan.todaySessionID == workout.id }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(plan.title).font(.caption.weight(.bold)).foregroundStyle(ClientClay.accent)
                    Text(workout.name).font(.system(.largeTitle, design: .rounded, weight: .bold))
                    Text("Settimana \(plan.currentWeek) · \(workout.exercises.count) esercizi")
                        .font(.subheadline).foregroundStyle(ClientClay.secondaryInk)
                    if execution?.isCompleted == true {
                        ClientBadge(text: "Allenamento completato · scheda consultabile", tint: ClientClay.sage, symbol: "checkmark.seal.fill")
                    } else if !isToday {
                        ClientBadge(text: "Consultazione · non programmato oggi", tint: ClientClay.secondaryInk, symbol: "eye.fill")
                    }
                }
                .clayCard()

                ForEach(Array(workout.exercises.enumerated()), id: \.element.id) { index, exercise in
                    Button { selectedExercise = exercise } label: {
                        exerciseCard(exercise, number: index + 1)
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Apre tutti i dettagli di \(exercise.name)")
                }

                if isToday, execution?.isCompleted != true {
                    Button {
                        session.beginWorkout(plan: plan, workoutSession: workout)
                        showingExecution = true
                    } label: {
                        Label(execution == nil ? "Inizia allenamento" : "Riprendi allenamento", systemImage: "play.fill")
                    }
                    .buttonStyle(ClayPrimaryButtonStyle())
                }
            }
            .padding(20)
        }
        .clientPage()
        .navigationTitle(workout.name)
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(isPresented: $showingExecution) {
            ClientWorkoutExecutionView(plan: plan, workoutSession: workout)
        }
        .sheet(item: $selectedExercise) { exercise in
            ClientExerciseDetailSheet(plan: plan, workout: workout, exercise: exercise)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }

    private func exerciseCard(_ exercise: ClientExercise, number: Int) -> some View {
        let log = execution?.exercises.first { $0.exerciseID == exercise.id }
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                Text("\(number)").font(.caption.weight(.bold)).foregroundStyle(.white)
                    .frame(width: 28, height: 28).background(ClientClay.accent, in: Circle())
                VStack(alignment: .leading, spacing: 4) {
                    Text(exercise.name).font(.headline)
                    Text([exercise.sets.map { "\($0) serie" }, exercise.repetitions.map { "\($0) reps" }].compactMap { $0 }.joined(separator: " · "))
                        .font(.subheadline).foregroundStyle(ClientClay.secondaryInk)
                }
                Spacer()
                if log?.isCompleted == true {
                    Image(systemName: "checkmark.circle.fill").font(.title2).foregroundStyle(ClientClay.sage)
                        .accessibilityLabel("Esercizio completato")
                } else {
                    Image(systemName: "chevron.right.circle.fill")
                        .font(.title2).foregroundStyle(ClientClay.accent.opacity(0.72))
                }
            }
            HStack(spacing: 12) {
                if let load = exercise.loadKg { Label("\(load.formatted()) kg", systemImage: "scalemass") }
                if let rest = exercise.restSeconds { Label("\(rest)s", systemImage: "timer") }
            }
            .font(.caption).foregroundStyle(ClientClay.secondaryInk)
            if let note = exercise.notes, !note.isEmpty {
                Label(note, systemImage: "text.bubble").font(.caption).foregroundStyle(ClientClay.secondaryInk)
            }
            if let log, !log.sets.isEmpty {
                Text("\(log.sets.count) / \(exercise.setCount) serie registrate")
                    .font(.caption.weight(.semibold)).foregroundStyle(log.isCompleted ? ClientClay.sage : ClientClay.accent)
            }
        }
        .clayCard(padding: 15)
    }
}

private struct ClientExerciseDetailSheet: View {
    let plan: ClientWorkoutPlan
    let workout: ClientWorkoutSession
    let exercise: ClientExercise

    @EnvironmentObject private var session: ClientSessionStore
    @Environment(\.dismiss) private var dismiss

    private struct HistoryItem: Identifiable {
        let id: UUID
        let date: Date
        let completedSets: Int
        let totalSets: Int
        let load: Double?
        let note: String
    }

    private var history: [HistoryItem] {
        session.activity.workouts.compactMap { execution in
            guard let log = execution.exercises.first(where: { $0.exerciseID == exercise.id }) else { return nil }
            let completedSets = log.sets.filter(\.isCompleted)
            return HistoryItem(
                id: log.id,
                date: execution.completedAt ?? execution.startedAt,
                completedSets: completedSets.count,
                totalSets: log.sets.count,
                load: completedSets.compactMap(\.actualLoadKg).last,
                note: log.note
            )
        }
        .sorted { $0.date > $1.date }
    }

    private var detailColumns: [GridItem] {
        [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 7) {
                        Text(workout.name.uppercased())
                            .font(.caption.weight(.bold)).tracking(1.1).foregroundStyle(ClientClay.accentSoft)
                        Text(exercise.name)
                            .font(.system(.largeTitle, design: .rounded, weight: .bold))
                            .foregroundStyle(.white)
                        Text("\(plan.title) · Settimana \(plan.currentWeek)")
                            .font(.subheadline).foregroundStyle(.white.opacity(0.7))
                    }
                    .premiumCard()

                    ClientSectionHeader(title: "Prescrizione", symbol: "list.bullet.clipboard.fill")
                    LazyVGrid(columns: detailColumns, spacing: 10) {
                        prescriptionTile(title: "Serie", value: exercise.sets ?? "—", symbol: "square.stack.3d.up.fill")
                        prescriptionTile(title: "Ripetizioni", value: exercise.repetitions ?? "—", symbol: "repeat")
                        prescriptionTile(title: "Recupero", value: exercise.restSeconds.map { "\($0) sec" } ?? "—", symbol: "timer")
                        prescriptionTile(title: "Carico", value: exercise.loadKg.map { "\($0.formatted()) kg" } ?? "—", symbol: "scalemass.fill")
                    }

                    if let notes = exercise.notes, !notes.isEmpty {
                        VStack(alignment: .leading, spacing: 9) {
                            Label("Note operative", systemImage: "text.bubble.fill")
                                .font(.headline).foregroundStyle(ClientClay.accent)
                            Text(notes).font(.body).foregroundStyle(ClientClay.ink)
                        }
                        .clayCard()
                    }

                    if let videoURL = exercise.videoURL {
                        Link(destination: videoURL) {
                            HStack(spacing: 13) {
                                Image(systemName: "play.rectangle.fill").font(.title2).foregroundStyle(ClientClay.accent)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("Video dell’esercizio").font(.headline).foregroundStyle(ClientClay.ink)
                                    Text("Apri la dimostrazione fornita dal Trainer")
                                        .font(.caption).foregroundStyle(ClientClay.secondaryInk)
                                }
                                Spacer()
                                Image(systemName: "arrow.up.right").foregroundStyle(ClientClay.accent)
                            }
                            .clayCard()
                        }
                        .buttonStyle(.plain)
                    }

                    ClientSectionHeader(title: "Storico personale", detail: history.isEmpty ? "Nessun dato" : "Ultimi \(min(3, history.count))", symbol: "clock.arrow.circlepath")
                    if history.isEmpty {
                        ClientEmptyState(symbol: "clock", title: "Ancora nessuna esecuzione", message: "Serie, carichi effettivi e note compariranno qui dopo il primo allenamento registrato.")
                    } else {
                        ForEach(history.prefix(3)) { item in
                            historyRow(item)
                        }
                    }
                }
                .padding(20)
            }
            .clientPage()
            .navigationTitle("Dettaglio esercizio")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fine") { dismiss() }.fontWeight(.semibold)
                }
            }
        }
    }

    private func prescriptionTile(title: String, value: String, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: symbol).foregroundStyle(ClientClay.accent)
            Text(value).font(.system(.title3, design: .rounded, weight: .bold)).foregroundStyle(ClientClay.ink)
            Text(title).font(.caption).foregroundStyle(ClientClay.secondaryInk)
        }
        .clayCard(padding: 14)
    }

    private func historyRow(_ item: HistoryItem) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Label(item.date.formatted(date: .abbreviated, time: .omitted), systemImage: "calendar")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("\(item.completedSets)/\(item.totalSets) serie")
                    .font(.caption.weight(.bold)).foregroundStyle(item.completedSets == item.totalSets ? ClientClay.sage : ClientClay.warning)
            }
            if let load = item.load {
                Label("Ultimo carico: \(load.formatted()) kg", systemImage: "scalemass")
                    .font(.caption).foregroundStyle(ClientClay.secondaryInk)
            }
            if !item.note.isEmpty {
                Label(item.note, systemImage: "note.text")
                    .font(.caption).foregroundStyle(ClientClay.secondaryInk)
            }
        }
        .clayCard(padding: 15)
    }
}
