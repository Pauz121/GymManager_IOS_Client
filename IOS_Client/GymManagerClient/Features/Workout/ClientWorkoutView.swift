import Charts
import SwiftUI

struct ClientWorkoutView: View {
    private enum Category: String, CaseIterable, Hashable {
        case activity = "Attività"
        case gym = "Palestra"
        case running = "Corsa"
        case recap = "Riepilogo"

        var symbol: String {
            switch self {
            case .activity: "calendar"
            case .gym: "dumbbell.fill"
            case .running: "figure.run"
            case .recap: "chart.bar.fill"
            }
        }
    }

    let snapshot: ClientSnapshot
    let identity: ClientIdentity
    @EnvironmentObject private var session: ClientSessionStore
    @State private var category: Category = .activity

    private var plan: ClientWorkoutPlan? { snapshot.workout }
    private var workoutFailure: String? {
        snapshot.warnings.first { $0.hasPrefix("Allenamento:") }
    }
    private var availableCategories: [Category] { Category.allCases }
    private var runningPlan: ClientRunningPlan {
        snapshot.runningPlan ?? ClientRunningPlan(
            id: UUID(uuidString: "F1700000-0000-0000-0000-000000000001")!,
            title: "Corsa libera", detail: "Registra distanza, tempo, passo e velocità.",
            targetMinutes: nil, targetDistanceKm: nil
        )
    }
    private var todayWorkout: ClientWorkoutSession? {
        guard let plan, plan.isEffective(), let id = plan.todaySessionID else { return nil }
        return plan.sessions.first { $0.id == id }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                ClientCompactSelector(values: availableCategories, selection: $category,
                                      title: { $0.rawValue }, accessibilityTitle: "Sezioni Allenamento")

                switch category {
                case .activity:
                    ClientActivityDashboardView(snapshot: snapshot)
                case .gym:
                    ClientContentGate(section: .workout, state: snapshot.contentState(for: .workout), isRefreshing: session.isRefreshing,
                                      retry: { Task { await session.refresh() } }) { gymContent }
                case .running:
                    ClientRunningView(plan: runningPlan)
                case .recap:
                    ClientActivityRecapView(snapshot: snapshot)
                }
            }
            .padding(.horizontal, ClientClay.pagePadding).padding(.vertical, 18)
        }
        .clientPage()
        .refreshable { await session.refresh() }
        .navigationTitle("Allenamento")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Dettagli piano") { session.notice = plan.map { "\($0.title) · Settimana \($0.currentWeek)" } ?? "Nessun piano attivo." }
                    Button("Storico schede") { withAnimation(.snappy) { category = .gym } }
                    Button("Informazioni") { session.notice = "La programmazione del Trainer resta protetta e non modificabile." }
                } label: {
                    Image(systemName: "ellipsis.circle").frame(width: 44, height: 44)
                }
                .accessibilityLabel("Azioni piano")
            }
        }
    }

    private var gymContent: some View {
        VStack(alignment: .leading, spacing: ClientSpacing.control) {
        if let plan {
            NavigationLink {
                ClientWorkoutPlanDetailView(plan: plan, isHistorical: false)
            } label: {
                ClientGymPlanHeader(plan: plan)
            }
            .buttonStyle(.plain)
            .accessibilityHint("Apre il piano attivo completo in sola lettura")

            if !plan.isEffective() {
                gymStatus("Piano in arrivo · già consultabile", symbol: "calendar.badge.clock")
            } else if let today = todayWorkout {
                todayCard(plan: plan, workout: today)
            } else {
                gymStatus("Oggi riposo · consulta le sessioni del piano", symbol: "moon.zzz")
            }

            Label("Allenamenti del piano · \(plan.sessions.count) sessioni", systemImage: "list.bullet.rectangle.portrait")
                .font(.headline).foregroundStyle(ClientClay.color(.textPrimary))
                .padding(.top, ClientSpacing.related)
            ForEach(plan.sessions) { workout in
                NavigationLink {
                    ClientWorkoutSessionDetailView(plan: plan, workout: workout)
                } label: {
                    sessionCard(plan: plan, workout: workout)
                }
                .buttonStyle(.plain)
            }

            Label("Storico schede · sola lettura", systemImage: "clock.arrow.circlepath")
                .font(.headline).foregroundStyle(ClientClay.color(.textPrimary))
                .padding(.top, ClientSpacing.related)
            if let history = snapshot.workoutHistory, !history.isEmpty {
                ForEach(history) { oldPlan in
                    NavigationLink {
                        ClientWorkoutPlanDetailView(plan: oldPlan, isHistorical: true)
                    } label: {
                        historicalPlanRow(oldPlan)
                    }
                    .buttonStyle(.plain)
                }
            } else {
                Text("Nessun piano precedente disponibile.")
                    .font(.subheadline).foregroundStyle(ClientClay.color(.textSecondary))
                    .padding(.vertical, ClientSpacing.related)
            }
        } else if let workoutFailure {
            ClientFailureView(message: workoutFailure) { Task { await session.refresh() } }
        } else if identity.mode == .trainerConnected {
            ClientEmptyState(symbol: "dumbbell", title: "Nessun piano Trainer", message: "Il tuo Trainer non ha ancora pubblicato una scheda attiva.")
        }
        ClientPersonalWorkoutLibraryView(
            allowsEditing: ClientAccessPolicy.canManagePersonalWorkoutPlans(in: identity.mode)
        )
        }
    }

    private func gymStatus(_ text: String, symbol: String) -> some View {
        Label(text, systemImage: symbol)
            .font(.subheadline)
            .foregroundStyle(ClientClay.color(.textSecondary))
            .fixedSize(horizontal: false, vertical: true)
            .padding(.vertical, ClientSpacing.related)
    }

    private func todayCard(plan: ClientWorkoutPlan, workout: ClientWorkoutSession) -> some View {
        let execution = session.workoutExecution(sessionID: workout.id)
        return NavigationLink {
            ClientWorkoutSessionDetailView(plan: plan, workout: workout)
        } label: {
            VStack(alignment: .leading, spacing: ClientSpacing.micro) {
                HStack(alignment: .top) {
                    Label("Allenamento di oggi", systemImage: execution?.isCompleted == true ? "checkmark.circle.fill" : "play.circle.fill")
                        .font(.subheadline.weight(.semibold)).foregroundStyle(ClientClay.color(execution?.isCompleted == true ? .success : .workoutAccent))
                    Spacer()
                    Image(systemName: "chevron.right").foregroundStyle(ClientClay.color(.textSecondary))
                }
                Text(workout.name).font(.headline).foregroundStyle(ClientClay.color(.textPrimary))
                Text("\(workout.exercises.count) esercizi\(workout.durationMinutes.map { " · \($0) min" } ?? "")")
                    .font(.caption).foregroundStyle(ClientClay.color(.textSecondary))
                Label(
                    execution?.isCompleted == true ? "Completato · consulta" : execution == nil ? "Apri e inizia" : "Apri e riprendi",
                    systemImage: execution?.isCompleted == true ? "checkmark.seal.fill" : "arrow.right.circle.fill"
                )
                .font(.subheadline).foregroundStyle(ClientClay.color(execution?.isCompleted == true ? .success : .workoutAccent))
            }
            .frame(maxWidth: .infinity, minHeight: ClientControlSize.minimumTarget, alignment: .leading)
            .clayCard(padding: ClientSpacing.control, appearance: .adaptive)
        }
        .buttonStyle(.plain)
        .accessibilityHint("Apre l’allenamento di oggi")
    }

    private func historicalPlanRow(_ plan: ClientWorkoutPlan) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "archivebox.fill").foregroundStyle(ClientClay.color(.textSecondary))
            VStack(alignment: .leading, spacing: 3) {
                Text(plan.title).font(.headline).foregroundStyle(ClientClay.color(.textPrimary))
                Text([plan.startsOn, plan.endsOn].compactMap { $0 }.joined(separator: " – "))
                    .font(.caption).foregroundStyle(ClientClay.color(.textSecondary))
            }
            Spacer()
            Image(systemName: "lock.fill").font(.caption).foregroundStyle(ClientClay.color(.textSecondary))
            Image(systemName: "chevron.right").font(.caption.weight(.bold)).foregroundStyle(ClientClay.color(.textSecondary))
        }
        .frame(minHeight: ClientControlSize.minimumTarget)
        .clayCard(padding: ClientSpacing.control, appearance: .adaptive)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Apre il piano precedente in sola lettura")
    }

    private func sessionCard(plan: ClientWorkoutPlan, workout: ClientWorkoutSession) -> some View {
        let execution = session.workoutExecution(sessionID: workout.id)
        return HStack(spacing: ClientSpacing.control) {
            Image(systemName: execution?.isCompleted == true ? "checkmark.circle.fill" : workout.id == plan.todaySessionID ? "play.circle.fill" : "figure.strengthtraining.traditional")
                .font(.title3).foregroundStyle(ClientClay.color(execution?.isCompleted == true ? .success : workout.id == plan.todaySessionID ? .workoutAccent : .textSecondary))
            VStack(alignment: .leading, spacing: 4) {
                Text(workout.name).font(.headline).foregroundStyle(ClientClay.color(.textPrimary))
                Text("\(workout.exercises.count) esercizi\(workout.durationMinutes.map { " · \($0) min" } ?? "")")
                    .font(.caption).foregroundStyle(ClientClay.color(.textSecondary))
                if execution?.isCompleted == true {
                    Text("Completato · consultabile").font(.caption.weight(.semibold)).foregroundStyle(ClientClay.color(.success))
                } else if workout.id == plan.todaySessionID {
                    Text("Allenamento di oggi").font(.caption.weight(.semibold)).foregroundStyle(ClientClay.color(.workoutAccent))
                }
            }
            Spacer()
            Image(systemName: "chevron.right").font(.caption.weight(.bold)).foregroundStyle(ClientClay.color(.textSecondary))
        }
        .frame(minHeight: ClientControlSize.minimumTarget)
        .clayCard(padding: ClientSpacing.control, appearance: .adaptive)
        .overlay {
            RoundedRectangle(cornerRadius: ClientClay.radius, style: .continuous)
                .stroke(ClientClay.color(workout.id == plan.todaySessionID ? .workoutAccent : .borderSubtle), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityHint("Apre gli esercizi di \(workout.name)")
    }
}

struct ClientGymPlanHeader: View {
    let plan: ClientWorkoutPlan

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "list.bullet.clipboard.fill")
                .font(.title3).foregroundStyle(ClientClay.color(.workoutAccent))
            VStack(alignment: .leading, spacing: 3) {
                Text(plan.isEffective() ? "PIANO ATTIVO" : "PIANO PUBBLICATO")
                    .font(.caption.weight(.semibold)).foregroundStyle(ClientClay.color(.textSecondary))
                Text(plan.title).font(.headline.weight(.bold)).foregroundStyle(ClientClay.color(.textPrimary))
                    .fixedSize(horizontal: false, vertical: true)
                Text(plan.isEffective() ? "Settimana \(plan.currentWeek) · sola lettura" : "Disponibile dal \(plan.startsOn ?? "periodo indicato dal Trainer")")
                    .font(.caption).foregroundStyle(ClientClay.color(.textSecondary))
                    .fixedSize(horizontal: false, vertical: true)
                Text("\(plan.sessions.count) sessioni").font(.caption).foregroundStyle(ClientClay.color(.textSecondary))
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right").font(.caption.weight(.bold)).foregroundStyle(ClientClay.color(.textSecondary))
        }
        .fixedSize(horizontal: false, vertical: true)
        .clayCard(padding: ClientSpacing.control, appearance: .adaptive)
    }
}

private struct ClientWorkoutPlanDetailView: View {
    let plan: ClientWorkoutPlan
    let isHistorical: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 7) {
                    Text(isHistorical ? "PIANO PRECEDENTE" : "PIANO ATTIVO")
                        .font(.caption.weight(.bold)).tracking(1.1).foregroundStyle(ClientClay.secondaryInk)
                    Text(plan.title)
                        .font(.system(.title2, design: .rounded, weight: .heavy)).foregroundStyle(ClientClay.ink)
                    Text([plan.startsOn, plan.endsOn].compactMap { $0 }.joined(separator: " – "))
                        .font(.subheadline).foregroundStyle(ClientClay.secondaryInk)
                    ClientBadge(
                        text: isHistorical ? "Archivio · sola lettura" : "Piano del Trainer · sola lettura",
                        tint: isHistorical ? ClientClay.secondaryInk : ClientClay.sage,
                        symbol: "lock.fill"
                    )
                }
                .premiumCard(tint: isHistorical ? ClientClay.inkSoft : ClientClay.accent)

                ClientSectionHeader(title: "Sessioni", detail: "\(plan.sessions.count)", symbol: "list.bullet.rectangle.portrait")
                ForEach(plan.sessions) { workout in
                    NavigationLink {
                        ClientWorkoutSessionDetailView(plan: plan, workout: workout)
                    } label: {
                        HStack(spacing: 13) {
                            Image(systemName: "figure.strengthtraining.traditional")
                                .font(.title3).foregroundStyle(ClientClay.accent)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(workout.name).font(.headline).foregroundStyle(ClientClay.ink)
                                Text("\(workout.exercises.count) esercizi")
                                    .font(.caption).foregroundStyle(ClientClay.secondaryInk)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").font(.caption.weight(.bold)).foregroundStyle(ClientClay.secondaryInk)
                        }
                        .clayCard(padding: 14)
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Apre la sessione in sola lettura")
                }
            }
            .padding(.horizontal, ClientClay.pagePadding).padding(.vertical, 18)
        }
        .clientPage()
        .navigationTitle(isHistorical ? "Storico schede" : "Piano attivo")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct ClientWorkoutSessionDetailView: View {
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
                .premiumCard(tint: execution?.isCompleted == true ? ClientClay.sage : ClientClay.accent)

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
            .padding(.horizontal, ClientClay.pagePadding).padding(.vertical, 18)
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
                Text("\(number)").font(.caption.weight(.bold)).foregroundStyle(ClientClay.color(.textOnAccent))
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
        .overlay {
            RoundedRectangle(cornerRadius: ClientClay.radius, style: .continuous)
                .stroke(log?.isCompleted == true ? ClientClay.sage.opacity(0.30) : ClientClay.border, lineWidth: 1)
        }
    }
}
