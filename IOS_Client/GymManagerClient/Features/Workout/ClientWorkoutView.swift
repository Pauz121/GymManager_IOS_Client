import SwiftUI

struct ClientWorkoutView: View {
    let plan: ClientWorkoutPlan?
    let identity: ClientIdentity

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                ClientPageTitle("La tua scheda", eyebrow: "Allenamento", subtitle: "Indicazioni pubblicate dal tuo Trainer, sempre consultabili e protette.")
                if let plan {
                    ReadOnlyPlanBadge()
                    VStack(alignment: .leading, spacing: 7) {
                        Text(plan.title).font(.system(.title2, design: .rounded, weight: .bold))
                        Text("Settimana \(plan.currentWeek)").font(.subheadline).foregroundStyle(ClientClay.secondaryInk)
                    }.clayCard()
                    ForEach(plan.sessions) { workout in
                        NavigationLink { ClientWorkoutSessionView(session: workout) } label: {
                            HStack(spacing: 14) {
                                Image(systemName: workout.id == plan.todaySessionID ? "play.circle.fill" : "figure.strengthtraining.traditional")
                                    .font(.title2).foregroundStyle(workout.id == plan.todaySessionID ? ClientClay.accent : ClientClay.sage)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(workout.name).font(.headline).foregroundStyle(ClientClay.ink)
                                    Text("\(workout.exercises.count) esercizi\(workout.durationMinutes.map { " · \($0) min" } ?? "")").font(.subheadline).foregroundStyle(ClientClay.secondaryInk)
                                }
                                Spacer(); Image(systemName: "chevron.right").foregroundStyle(ClientClay.secondaryInk)
                            }.clayCard()
                        }.buttonStyle(.plain)
                    }
                } else {
                    ClientEmptyState(symbol: "dumbbell", title: "Nessun piano pubblicato", message: identity.mode == .standalone ? "Quando collegherai un Trainer, la scheda attiva comparirà qui." : "Il tuo Trainer non ha ancora pubblicato una scheda attiva.")
                }
            }.padding(20)
        }.clientPage().navigationTitle("Scheda").navigationBarTitleDisplayMode(.inline)
    }
}

private struct ClientWorkoutSessionView: View {
    let session: ClientWorkoutSession

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ReadOnlyPlanBadge()
                ForEach(session.exercises) { exercise in
                    VStack(alignment: .leading, spacing: 10) {
                        Text(exercise.name).font(.title3.weight(.semibold))
                        HStack(spacing: 16) {
                            if let sets = exercise.sets { metric("Serie", sets) }
                            if let reps = exercise.repetitions { metric("Ripetizioni", reps) }
                            if let rest = exercise.restSeconds { metric("Recupero", "\(rest)s") }
                        }
                        if let load = exercise.loadKg { Label("Carico indicato: \(load.formatted()) kg", systemImage: "scalemass") .font(.subheadline) }
                        if let notes = exercise.notes, !notes.isEmpty { Text(notes).font(.subheadline).foregroundStyle(ClientClay.secondaryInk) }
                        if let url = exercise.videoURL { Link(destination: url) { Label("Guarda la dimostrazione", systemImage: "play.rectangle") }.font(.subheadline.weight(.semibold)) }
                    }.clayCard()
                }
            }.padding(20)
        }.clientPage().navigationTitle(session.name).navigationBarTitleDisplayMode(.inline)
    }

    private func metric(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) { Text(label).font(.caption).foregroundStyle(ClientClay.secondaryInk); Text(value).font(.headline) }
    }
}
