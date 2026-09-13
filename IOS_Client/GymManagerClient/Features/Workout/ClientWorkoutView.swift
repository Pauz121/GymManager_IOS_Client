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

            Text("Scheda attuale").font(.title3.weight(.bold))
            ForEach(plan.sessions) { workout in
                sessionCard(plan: plan, workout: workout)
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
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 14) {
                Image(systemName: execution?.isCompleted == true ? "checkmark.circle.fill" : workout.id == plan.todaySessionID ? "play.circle.fill" : "figure.strengthtraining.traditional")
                    .font(.title2).foregroundStyle(execution?.isCompleted == true ? ClientClay.sage : workout.id == plan.todaySessionID ? ClientClay.accent : ClientClay.secondaryInk)
                VStack(alignment: .leading, spacing: 4) {
                    Text(workout.name).font(.headline)
                    Text("\(workout.exercises.count) esercizi").font(.subheadline).foregroundStyle(ClientClay.secondaryInk)
                }
                Spacer()
            }
            ForEach(workout.exercises) { exercise in
                HStack(alignment: .top, spacing: 10) {
                    Text(exercise.name).font(.subheadline.weight(.semibold))
                    Spacer()
                    Text([exercise.sets.map { "\($0) serie" }, exercise.repetitions.map { "\($0) reps" }].compactMap { $0 }.joined(separator: " · "))
                        .font(.caption).foregroundStyle(ClientClay.secondaryInk)
                }
            }
            if workout.id == plan.todaySessionID, execution?.isCompleted != true {
                Button {
                    session.beginWorkout(plan: plan, workoutSession: workout)
                    presentedWorkout = workout
                } label: { Text(execution == nil ? "Inizia" : "Riprendi") }
                    .buttonStyle(ClaySecondaryButtonStyle())
            }
        }
        .clayCard()
    }
}
