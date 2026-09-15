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
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var category: Category = .activity

    private var plan: ClientWorkoutPlan? { snapshot.workout }
    private var availableCategories: [Category] {
        Category.allCases.filter { $0 != .running || (snapshot.capabilities.runningEnabled && snapshot.runningPlan != nil) }
    }
    private var todayWorkout: ClientWorkoutSession? {
        guard let id = plan?.todaySessionID else { return nil }
        return plan?.sessions.first { $0.id == id }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                LazyVGrid(
                    columns: dynamicTypeSize.isAccessibilitySize
                        ? [GridItem(.flexible())]
                        : [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)],
                    spacing: 10
                ) {
                    ForEach(availableCategories, id: \.self) { item in
                        categoryCard(item)
                    }
                }
                .accessibilityLabel("Scegli Attività, Palestra, Corsa o Riepilogo")

                switch category {
                case .activity:
                    ClientActivityDashboardView(snapshot: snapshot)
                case .gym:
                    gymContent
                case .running:
                    if let runningPlan = snapshot.runningPlan { ClientRunningView(plan: runningPlan) }
                case .recap:
                    ClientActivityRecapView(snapshot: snapshot)
                }
            }
            .padding(.horizontal, ClientClay.pagePadding).padding(.vertical, 18)
        }
        .clientPage()
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

    private func categoryCard(_ item: Category) -> some View {
        Button {
            ClientHaptics.selection()
            withAnimation(.snappy(duration: 0.22)) { category = item }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: item.symbol)
                    .font(.title3.weight(.bold))
                    .frame(width: 38, height: 38)
                    .background((category == item ? Color.white : ClientClay.accent).opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
                Text(item.rawValue)
                    .font(.headline.weight(.bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                Spacer(minLength: 0)
            }
            .foregroundStyle(category == item ? Color.white : ClientClay.ink)
            .padding(13)
            .frame(maxWidth: .infinity, minHeight: 68, alignment: .leading)
            .background(category == item ? ClientClay.brandGradient : LinearGradient(colors: [ClientClay.surfaceElevated, ClientClay.surface], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay { RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(category == item ? ClientClay.accentSoft.opacity(0.52) : ClientClay.border) }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(category == item ? [.isSelected] : [])
        .accessibilityHint("Mostra la sezione \(item.rawValue)")
    }

    @ViewBuilder private var gymContent: some View {
        if let plan {
            NavigationLink {
                ClientWorkoutPlanDetailView(plan: plan, isHistorical: false)
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "list.bullet.clipboard.fill")
                        .font(.title3).foregroundStyle(ClientClay.accentSoft)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("PIANO ATTIVO").font(.caption2.weight(.bold)).tracking(1).foregroundStyle(.white.opacity(0.62))
                        Text(plan.title).font(.headline.weight(.bold)).foregroundStyle(.white).lineLimit(1)
                        Text("Settimana \(plan.currentWeek) · sola lettura").font(.caption).foregroundStyle(.white.opacity(0.68))
                    }
                    Spacer()
                    Image(systemName: "chevron.right").font(.caption.weight(.bold)).foregroundStyle(.white.opacity(0.7))
                }
                .premiumCard(tint: ClientClay.accent)
            }
            .buttonStyle(.plain)
            .accessibilityHint("Apre il piano attivo completo in sola lettura")

            if let today = todayWorkout {
                todayCard(plan: plan, workout: today)
            } else {
                ClientEmptyState(symbol: "moon.zzz", title: "Oggi riposo", message: "Puoi consultare le altre sessioni senza avviarne una per errore.")
            }

            ClientSectionHeader(title: "Allenamenti del piano", detail: "\(plan.sessions.count) sessioni", symbol: "list.bullet.rectangle.portrait")
            ForEach(plan.sessions) { workout in
                NavigationLink {
                    ClientWorkoutSessionDetailView(plan: plan, workout: workout)
                } label: {
                    sessionCard(plan: plan, workout: workout)
                }
                .buttonStyle(.plain)
            }

            ClientSectionHeader(title: "Storico schede", detail: "Sola lettura", symbol: "clock.arrow.circlepath")
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
                    .font(.subheadline).foregroundStyle(ClientClay.secondaryInk)
                    .clayCard(padding: 14)
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
        return NavigationLink {
            ClientWorkoutSessionDetailView(plan: plan, workout: workout)
        } label: {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Label("Allenamento di oggi", systemImage: execution?.isCompleted == true ? "checkmark.circle.fill" : "play.circle.fill")
                        .font(.headline).foregroundStyle(execution?.isCompleted == true ? ClientClay.sage : ClientClay.accentSoft)
                    Spacer()
                    Image(systemName: "chevron.right").foregroundStyle(.white.opacity(0.7))
                }
                Text(workout.name).font(.system(.title2, design: .rounded, weight: .heavy)).foregroundStyle(.white)
                Text("\(workout.exercises.count) esercizi\(workout.durationMinutes.map { " · \($0) min" } ?? "")")
                    .font(.subheadline).foregroundStyle(.white.opacity(0.68))
                Label(
                    execution?.isCompleted == true ? "Completato · consulta" : execution == nil ? "Apri e inizia" : "Apri e riprendi",
                    systemImage: execution?.isCompleted == true ? "checkmark.seal.fill" : "arrow.right.circle.fill"
                )
                .font(.headline).foregroundStyle(execution?.isCompleted == true ? ClientClay.sage : ClientClay.accentSoft)
            }
            .premiumCard(tint: execution?.isCompleted == true ? ClientClay.sage : ClientClay.accent)
        }
        .buttonStyle(.plain)
        .accessibilityHint("Apre l’allenamento di oggi")
    }

    private func historicalPlanRow(_ plan: ClientWorkoutPlan) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "archivebox.fill").foregroundStyle(ClientClay.secondaryInk)
            VStack(alignment: .leading, spacing: 3) {
                Text(plan.title).font(.headline).foregroundStyle(ClientClay.ink)
                Text([plan.startsOn, plan.endsOn].compactMap { $0 }.joined(separator: " – "))
                    .font(.caption).foregroundStyle(ClientClay.secondaryInk)
            }
            Spacer()
            Image(systemName: "lock.fill").font(.caption).foregroundStyle(ClientClay.secondaryInk)
            Image(systemName: "chevron.right").font(.caption.weight(.bold)).foregroundStyle(ClientClay.secondaryInk)
        }
        .clayCard(padding: 14)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Apre il piano precedente in sola lettura")
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
        .overlay {
            RoundedRectangle(cornerRadius: ClientClay.radius, style: .continuous)
                .stroke(workout.id == plan.todaySessionID ? ClientClay.accent.opacity(0.38) : ClientClay.border, lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityHint("Apre gli esercizi di \(workout.name)")
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
                        .font(.caption.weight(.bold)).tracking(1.1).foregroundStyle(.white.opacity(0.62))
                    Text(plan.title)
                        .font(.system(.title2, design: .rounded, weight: .heavy)).foregroundStyle(.white)
                    Text([plan.startsOn, plan.endsOn].compactMap { $0 }.joined(separator: " – "))
                        .font(.subheadline).foregroundStyle(.white.opacity(0.68))
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
        .overlay {
            RoundedRectangle(cornerRadius: ClientClay.radius, style: .continuous)
                .stroke(log?.isCompleted == true ? ClientClay.sage.opacity(0.30) : ClientClay.border, lineWidth: 1)
        }
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
                load: completedSets.compactMap(\.actualLoadKg).filter { $0 > 0 }.max(),
                note: log.note
            )
        }
        .sorted { $0.date > $1.date }
    }

    private var loadHistory: [ClientExerciseLoadPoint] {
        ClientActivityInsights.exerciseLoadHistory(exerciseID: exercise.id, state: session.activity)
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
                    loadProgressCard
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

    @ViewBuilder private var loadProgressCard: some View {
        if loadHistory.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Label("Carico migliore per sessione", systemImage: "chart.line.uptrend.xyaxis")
                    .font(.headline).foregroundStyle(ClientClay.accent)
                Text("Nessun carico registrato per questo esercizio.")
                    .font(.subheadline).foregroundStyle(ClientClay.secondaryInk)
            }
            .clayCard()
        } else {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("CARICO MIGLIORE PER SESSIONE")
                            .font(.caption.weight(.bold)).tracking(0.8).foregroundStyle(ClientClay.secondaryInk)
                        Text("\(loadHistory.last?.loadKg.formatted() ?? "—") kg")
                            .font(.system(.title2, design: .rounded, weight: .heavy)).foregroundStyle(ClientClay.ink)
                    }
                    Spacer()
                    if let delta = loadDelta {
                        ClientBadge(text: "\(delta >= 0 ? "+" : "")\(delta.formatted()) kg", tint: delta >= 0 ? ClientClay.sage : ClientClay.warning, symbol: delta >= 0 ? "arrow.up.right" : "arrow.down.right")
                    }
                }
                if loadHistory.count == 1 {
                    Text("Unica sessione registrata. Completa un altro allenamento per vedere il trend.")
                        .font(.subheadline).foregroundStyle(ClientClay.secondaryInk)
                } else {
                    Chart(loadHistory) { item in
                        LineMark(x: .value("Data", item.date), y: .value("Carico kg", item.loadKg))
                            .interpolationMethod(.catmullRom)
                            .foregroundStyle(ClientClay.accent)
                        PointMark(x: .value("Data", item.date), y: .value("Carico kg", item.loadKg))
                            .foregroundStyle(ClientClay.accentSoft)
                    }
                    .frame(height: 170)
                    .chartYAxisLabel("kg")
                    .chartPlotStyle { $0.background(ClientClay.inset.opacity(0.55)).clipShape(RoundedRectangle(cornerRadius: 12)) }
                    .accessibilityLabel("Grafico del carico migliore registrato per sessione")
                }
            }
            .clayCard()
        }
    }

    private var loadDelta: Double? {
        guard loadHistory.count > 1, let first = loadHistory.first?.loadKg, let last = loadHistory.last?.loadKg else { return nil }
        return last - first
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
