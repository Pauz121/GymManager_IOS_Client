import Combine
import SwiftUI

struct ClientWorkoutExecutionView: View {
    let plan: ClientWorkoutPlan
    let workoutSession: ClientWorkoutSession
    @EnvironmentObject private var session: ClientSessionStore
    @Environment(\.dismiss) private var dismiss
    @State private var repetitionsDraft: [String: String] = [:]
    @State private var loadDraft: [String: String] = [:]
    @State private var noteExercise: ClientExercise?
    @State private var detailExercise: ClientExercise?
    @State private var selectedExerciseID: UUID?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showingFeedback = false
    @State private var showingExitConfirmation = false
    @FocusState private var focusedField: String?

    private var execution: ClientWorkoutExecution? {
        session.workoutExecution(sessionID: workoutSession.id)
    }

    private var allExercisesComplete: Bool {
        execution?.exercises.allSatisfy(\.isCompleted) == true
    }

    private var visualExercise: ClientExercise? {
        if let timer = session.activity.restTimer,
           let resting = workoutSession.exercises.first(where: { $0.id == timer.exerciseID }) { return resting }
        return workoutSession.exercises.first { exerciseLog(for: $0.id)?.isCompleted != true }
            ?? workoutSession.exercises.last
    }

    private var focusedExercise: ClientExercise? {
        selectedExerciseID.flatMap { id in workoutSession.exercises.first { $0.id == id } } ?? visualExercise
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    if execution?.isCompleted == true {
                        completionSummary
                    } else if let exercise = focusedExercise {
                        exerciseCard(exercise)
                        if let index = workoutSession.exercises.firstIndex(where: { $0.id == exercise.id }),
                           index + 1 < workoutSession.exercises.count {
                            let next = workoutSession.exercises[index + 1]
                            Button {
                                selectedExerciseID = next.id
                            } label: {
                                Label("Prossimo: \(next.name)", systemImage: "arrow.right.circle")
                                    .frame(minHeight: ClientControlSize.minimumTarget)
                                    .multilineTextAlignment(.leading)
                            }.tint(ClientClay.color(.brandAccent))
                                .anchorPreference(key: ClientWorkoutAvoidanceKey.self, value: .bounds) { [$0] }
                        }
                    }
                    DisclosureGroup("Tutti gli esercizi · \(workoutSession.exercises.count)") {
                        ForEach(workoutSession.exercises) { exercise in
                            Button {
                                if execution?.isCompleted == true { detailExercise = exercise }
                                else { selectedExerciseID = exercise.id }
                            } label: {
                                Label(exercise.name, systemImage: exerciseLog(for: exercise.id)?.isCompleted == true ? "checkmark.circle.fill" : "circle")
                                    .frame(maxWidth: .infinity, minHeight: ClientControlSize.minimumTarget, alignment: .leading)
                                    .foregroundStyle(ClientClay.color(.textPrimary))
                            }.buttonStyle(.plain)
                        }
                    }
                    .anchorPreference(key: ClientWorkoutAvoidanceKey.self, value: .bounds) { [$0] }
                }
                .padding(.horizontal, ClientClay.pagePadding).padding(.vertical, 18)
            }
            .clientPage()
            .navigationTitle(workoutSession.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Chiudi") { showingExitConfirmation = true }
                }
                ToolbarItem(placement: .principal) {
                    WorkoutElapsedView(startedAt: execution?.startedAt)
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 8) {
                VStack(spacing: 8) {
                    if allExercisesComplete, execution?.isCompleted != true {
                        Button { showingFeedback = true } label: {
                            Label("Termina allenamento", systemImage: "checkmark.seal.fill")
                        }
                        .buttonStyle(ClayPrimaryButtonStyle())
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
                .background(ClientClay.canvas.opacity(0.97))
                .anchorPreference(key: ClientWorkoutAvoidanceKey.self, value: .bounds) { [$0] }
            }
            .onAppear {
                session.finishRestTimerIfElapsed()
                session.beginWorkout(plan: plan, workoutSession: workoutSession)
                prepareDrafts()
            }
            .sheet(item: $noteExercise) { exercise in
                ExerciseNoteSheet(
                    sessionID: workoutSession.id,
                    exercise: exercise,
                    initialNote: exerciseLog(for: exercise.id)?.note ?? ""
                )
                .presentationDetents([.medium])
            }
            .sheet(item: $detailExercise) { exercise in
                ClientExerciseDetailSheet(plan: plan, workout: workoutSession, exercise: exercise)
                    .presentationDetents([.large])
            }
            .sheet(isPresented: $showingFeedback) {
                PostWorkoutSheet(sessionID: workoutSession.id) { showingFeedback = false }
                    .presentationDetents([.large])
            }
            .onChange(of: execution?.completedExerciseCount) { _, _ in
                selectedExerciseID = nil
                focusedField = nil
            }
            .confirmationDialog("Interrompere l'allenamento?", isPresented: $showingExitConfirmation, titleVisibility: .visible) {
                Button("Esci · i progressi restano salvati") { dismiss() }
                Button("Continua ad allenarti", role: .cancel) {}
            } message: {
                Text("Le serie completate restano su questo dispositivo e potrai riprendere dalla Home.")
            }
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Fine") { focusedField = nil }.fontWeight(.semibold)
                }
            }
        }
        .clientFloatingRestTimer()
    }

    private var header: some View {
        let completed = execution?.completedExerciseCount ?? 0

        return VStack(alignment: .leading, spacing: 10) {
            Text(execution?.isCompleted == true ? "Sessione completata" : "Sessione in corso").font(.caption.weight(.semibold)).foregroundStyle(ClientClay.color(.textSecondary))
            Text(workoutSession.name).font(.title3.weight(.bold)).foregroundStyle(ClientClay.color(.textPrimary))
            Text("\(plan.title) · Settimana \(plan.currentWeek)")
                .font(.subheadline).foregroundStyle(ClientClay.color(.textSecondary))
            ClientProgressSegmentBar(completed: completed, total: workoutSession.exercises.count, tint: ClientClay.sage)
            Text("\(completed) / \(workoutSession.exercises.count) esercizi completati")
                .font(.caption.weight(.semibold)).foregroundStyle(ClientClay.color(.textSecondary))
        }
        .padding(.vertical, ClientSpacing.related)
    }

    private func exerciseCard(_ exercise: ClientExercise) -> some View {
        let log = exerciseLog(for: exercise.id)
        let isCurrent = log?.isCompleted != true && workoutSession.exercises.first(where: { exerciseLog(for: $0.id)?.isCompleted != true })?.id == exercise.id
        return VStack(alignment: .leading, spacing: 13) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    if isCurrent {
                        Text("ESERCIZIO ATTIVO").font(.caption2.weight(.bold)).tracking(1).foregroundStyle(ClientClay.accent)
                    }
                    Button { detailExercise = exercise } label: {
                        Label(exercise.name.uppercased(), systemImage: "figure.strengthtraining.traditional")
                            .font(.headline).frame(minHeight: 44).multilineTextAlignment(.leading)
                    }.buttonStyle(.plain).accessibilityHint("Apri tecnica, anatomia e prescrizione")
                    ClientExercisePrescriptionView(exercise: exercise)
                }
                Spacer()
                if log?.isCompleted == true {
                    ClientBadge(text: "Completato", tint: ClientClay.sage, symbol: "checkmark.circle.fill")
                }
                Button { noteExercise = exercise } label: {
                    Image(systemName: (log?.note.isEmpty == false) ? "note.text.badge.plus" : "note.text")
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("Nota per \(exercise.name)")
            }
            if let notes = exercise.notes, !notes.isEmpty {
                Label(notes, systemImage: "text.bubble").font(.subheadline).foregroundStyle(ClientClay.secondaryInk)
            }
            if let startedAt = execution?.startedAt,
               let previousLoad = ClientActivityInsights.previousExerciseLoad(exerciseID: exercise.id, state: session.activity, before: startedAt) {
                Label("Ultima volta: \(previousLoad.formatted()) kg", systemImage: "clock.arrow.circlepath")
                    .font(.caption.weight(.semibold)).foregroundStyle(ClientClay.secondaryInk)
            }

            if let current = log?.sets.first(where: { !$0.isCompleted }) {
                Text("Serie \(current.number) di \(exercise.setCount)").font(.title3.weight(.bold))
                setRow(exercise: exercise, number: current.number, log: current)
                if current.number < exercise.setCount {
                    Text("Poi: serie \(current.number + 1) · \(exercise.repetitions ?? "target della scheda")")
                        .font(.caption).foregroundStyle(ClientClay.color(.textSecondary))
                }
            } else if log?.isCompleted == true {
                Label("Esercizio completato", systemImage: "checkmark.seal.fill")
                    .foregroundStyle(ClientClay.color(.success))
            }
            ForEach(log?.sets.filter(\.isCompleted) ?? []) { completedSet in
                HStack {
                    Label("Serie \(completedSet.number) · \(completedSetDescription(completedSet))", systemImage: "checkmark.circle.fill")
                        .font(.subheadline).foregroundStyle(ClientClay.color(.success))
                    Spacer()
                    Button("Annulla") { session.undoSet(sessionID: workoutSession.id, exerciseID: exercise.id, setNumber: completedSet.number) }
                        .font(.caption).frame(minHeight: ClientControlSize.minimumTarget)
                }
            }
        }
        .clayCard(padding: ClientSpacing.page, appearance: .adaptive)
        .overlay {
            RoundedRectangle(cornerRadius: ClientClay.radius, style: .continuous)
                .stroke(isCurrent ? ClientClay.accent.opacity(0.72) : log?.isCompleted == true ? ClientClay.sage.opacity(0.34) : ClientClay.border, lineWidth: isCurrent ? 1.5 : 1)
        }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.18), value: log?.sets.filter(\.isCompleted).count)
        .anchorPreference(key: ClientWorkoutAvoidanceKey.self, value: .bounds) { [$0] }
    }

    private var completionSummary: some View {
        VStack(alignment: .leading, spacing: ClientSpacing.control) {
            Label("Allenamento completato", systemImage: "checkmark.seal.fill")
                .font(.title2.weight(.bold)).foregroundStyle(ClientClay.color(.success))
            Text("\(execution?.completedExerciseCount ?? 0) esercizi · \(execution?.exercises.flatMap(\.sets).filter(\.isCompleted).count ?? 0) serie registrate")
                .font(.headline)
            if let minutes = execution?.durationMinutes { Text("Durata: \(minutes) min").monospacedDigit() }
            Text("I dettagli restano consultabili nella scheda e nello storico.").font(.subheadline)
            Button("Torna alla giornata") { dismiss() }.buttonStyle(ClayPrimaryButtonStyle())
        }.clayCard(padding: ClientSpacing.page, appearance: .adaptive)
            .anchorPreference(key: ClientWorkoutAvoidanceKey.self, value: .bounds) { [$0] }
    }

    @ViewBuilder private func setRow(exercise: ClientExercise, number: Int, log: ClientSetLog?) -> some View {
        if let log, log.isCompleted {
            HStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill").font(.title2).foregroundStyle(ClientClay.sage)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Serie \(number)").font(.headline)
                    Text(completedSetDescription(log)).font(.subheadline).foregroundStyle(ClientClay.secondaryInk)
                }
                Spacer()
                Button("Annulla") { session.undoSet(sessionID: workoutSession.id, exerciseID: exercise.id, setNumber: number) }
                    .font(.caption.weight(.semibold))
            }
            .frame(minHeight: 52)
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(ClientClay.sageSoft.opacity(0.68), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .accessibilityElement(children: .combine)
        } else {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Serie \(number)").font(.headline)
                    Spacer()
                    Text("Da fare").font(.caption.weight(.bold)).foregroundStyle(ClientClay.accent)
                }
                ViewThatFits {
                    HStack(spacing: 10) { setInputs(exercise: exercise, number: number) }
                    VStack(spacing: 10) { setInputs(exercise: exercise, number: number) }
                }
                Button {
                    complete(exercise: exercise, number: number)
                } label: {
                    Label("Completa serie", systemImage: "checkmark")
                }
                .buttonStyle(ClayPrimaryButtonStyle())
                .accessibilityHint("Registra la serie e avvia automaticamente il recupero")
            }
            .padding(12)
            .background(ClientClay.inset, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay { RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(ClientClay.border) }
        }
    }

    @ViewBuilder private func setInputs(exercise: ClientExercise, number: Int) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Eseguito · reps").font(.caption).foregroundStyle(ClientClay.secondaryInk)
            TextField("–", text: draftBinding(storage: $repetitionsDraft, key: key(exercise.id, number), fallback: exercise.suggestedActualRepetitions.map(String.init) ?? ""))
                .keyboardType(.numberPad).focused($focusedField, equals: "\(key(exercise.id, number))-reps").clientInputField()
        }
        VStack(alignment: .leading, spacing: 4) {
            Text("Eseguito · kg").font(.caption).foregroundStyle(ClientClay.secondaryInk)
            TextField("–", text: draftBinding(storage: $loadDraft, key: key(exercise.id, number), fallback: exercise.loadKg.map { $0.formatted() } ?? ""))
                .keyboardType(.decimalPad).focused($focusedField, equals: "\(key(exercise.id, number))-load").clientInputField()
        }
    }

    private func prescription(for exercise: ClientExercise) -> String {
        ["\(exercise.setCount) serie", exercise.repetitions.map { "\($0) reps" }, exercise.loadKg.map { "\($0.formatted()) kg" }, exercise.restSeconds.map { "recupero \($0)s" }]
            .compactMap { $0 }.joined(separator: " · ")
    }

    private func completedSetDescription(_ log: ClientSetLog) -> String {
        let reps = log.actualRepetitions.map { "\($0) reps" } ?? log.prescribedRepetitions.map { "\($0) reps" }
        let load = log.actualLoadKg.map { "\($0.formatted()) kg" } ?? log.prescribedLoadKg.map { "\($0.formatted()) kg" }
        return [reps, load].compactMap { $0 }.joined(separator: " · ")
    }

    private func exerciseLog(for exerciseID: UUID) -> ClientExerciseLog? {
        execution?.exercises.first { $0.exerciseID == exerciseID }
    }

    private func key(_ exerciseID: UUID, _ number: Int) -> String { "\(exerciseID.uuidString)-\(number)" }

    private func draftBinding(storage: Binding<[String: String]>, key: String, fallback: String) -> Binding<String> {
        Binding(
            get: { storage.wrappedValue[key] ?? fallback },
            set: { storage.wrappedValue[key] = $0 }
        )
    }

    private func prepareDrafts() {
        for exercise in workoutSession.exercises {
            for number in 1...exercise.setCount {
                let draftKey = key(exercise.id, number)
                repetitionsDraft[draftKey] = repetitionsDraft[draftKey] ?? exercise.suggestedActualRepetitions.map(String.init)
                loadDraft[draftKey] = loadDraft[draftKey] ?? exercise.loadKg.map { $0.formatted() }
            }
        }
    }

    private func complete(exercise: ClientExercise, number: Int) {
        let draftKey = key(exercise.id, number)
        let reps = repetitionsDraft[draftKey].flatMap(Int.init) ?? exercise.suggestedActualRepetitions
        let loadText = loadDraft[draftKey]?.replacingOccurrences(of: ",", with: ".")
        let load = loadText.flatMap(Double.init) ?? exercise.loadKg
        session.completeSet(
            sessionID: workoutSession.id,
            exercise: exercise,
            setNumber: number,
            actualRepetitions: reps,
            actualLoadKg: load
        )
    }
}

private struct WorkoutElapsedView: View {
    let startedAt: Date?

    var body: some View {
        if let startedAt {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                Text(duration(context.date.timeIntervalSince(startedAt)))
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .accessibilityLabel("Durata allenamento \(duration(context.date.timeIntervalSince(startedAt)))")
            }
        }
    }

    private func duration(_ seconds: TimeInterval) -> String {
        let value = max(0, Int(seconds))
        return String(format: "%02d:%02d", value / 60, value % 60)
    }
}

private struct ExerciseNoteSheet: View {
    let sessionID: UUID
    let exercise: ClientExercise
    @EnvironmentObject private var session: ClientSessionStore
    @Environment(\.dismiss) private var dismiss
    @State private var note: String

    init(sessionID: UUID, exercise: ClientExercise, initialNote: String) {
        self.sessionID = sessionID
        self.exercise = exercise
        _note = State(initialValue: initialNote)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Come è andato?") {
                    TextField("Nota facoltativa", text: $note, axis: .vertical).lineLimit(3...6)
                }
                Section { Text("La nota riguarda solo questa esecuzione e non modifica la scheda del Trainer.").font(.footnote) }
            }
            .scrollContentBackground(.hidden)
            .background(ClientClay.canvas)
            .navigationTitle(exercise.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Annulla") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salva") {
                        session.saveExerciseNote(sessionID: sessionID, exerciseID: exercise.id, note: note)
                        dismiss()
                    }
                }
            }
        }
    }
}

private struct PostWorkoutSheet: View {
    let sessionID: UUID
    let onComplete: () -> Void
    @EnvironmentObject private var session: ClientSessionStore
    @Environment(\.dismiss) private var dismiss
    @State private var effort = 3
    @State private var quality = 3
    @State private var hasPain = false
    @State private var note = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Fatica percepita") { rating($effort) }
                Section("Qualità allenamento") { rating($quality) }
                Section("Dolori o fastidi?") { Picker("Dolori o fastidi", selection: $hasPain) { Text("No").tag(false); Text("Sì").tag(true) }.pickerStyle(.segmented) }
                Section("Vuoi aggiungere qualcosa?") { TextField("Nota facoltativa", text: $note, axis: .vertical).lineLimit(2...5) }
            }
            .scrollContentBackground(.hidden)
            .background(ClientClay.canvas)
            .navigationTitle("Com'è andata?")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) {
                Button {
                    session.finishWorkout(sessionID: sessionID, feedback: ClientWorkoutFeedback(effort: effort, quality: quality, hasPain: hasPain, note: note))
                    dismiss()
                    onComplete()
                } label: { Label("Salva e termina", systemImage: "checkmark") }
                    .buttonStyle(ClayPrimaryButtonStyle()).padding()
                    .background(ClientClay.canvas.opacity(0.97))
            }
        }
    }

    private func rating(_ value: Binding<Int>) -> some View {
        HStack {
            ForEach(1...5, id: \.self) { number in
                Button { value.wrappedValue = number } label: {
                    Text("\(number)").font(.headline).frame(maxWidth: .infinity, minHeight: 44)
                        .background(value.wrappedValue == number ? ClientClay.accent : ClientClay.surfaceElevated, in: RoundedRectangle(cornerRadius: 12))
                        .foregroundStyle(value.wrappedValue == number ? ClientClay.color(.textOnAccent) : ClientClay.ink)
                }
                .buttonStyle(.plain)
            }
        }
    }
}
