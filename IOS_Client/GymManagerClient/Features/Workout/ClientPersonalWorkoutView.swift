import SwiftUI

struct ClientPersonalWorkoutLibraryView: View {
    @EnvironmentObject private var session: ClientSessionStore
    @State private var editorPlan: ClientPersonalWorkoutPlan?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ClientSectionHeader(
                title: "Le mie schede",
                detail: session.personalContent.workoutPlans.isEmpty ? "Crea la prima" : "\(session.personalContent.workoutPlans.count) piani",
                symbol: "person.crop.rectangle.stack.fill"
            )

            if session.personalContent.workoutPlans.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Label("Nessuna scheda personale", systemImage: "sparkles.rectangle.stack")
                        .font(.headline).foregroundStyle(ClientClay.ink)
                    Text("Crea sessioni, scegli gli esercizi reali del catalogo e allenati subito anche senza Trainer.")
                        .font(.subheadline).foregroundStyle(ClientClay.secondaryInk)
                    Button { editorPlan = Self.newPlan() } label: {
                        Label("Crea scheda", systemImage: "plus.circle.fill").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(ClayPrimaryButtonStyle())
                }
                .clayCard()
            } else {
                ForEach(session.personalContent.workoutPlans) { plan in
                    personalPlanCard(plan)
                }
                Button { editorPlan = Self.newPlan() } label: {
                    Label("Nuovo piano personale", systemImage: "plus").frame(maxWidth: .infinity)
                }
                .buttonStyle(ClaySecondaryButtonStyle())
            }
        }
        .sheet(item: $editorPlan) { plan in
            ClientPersonalWorkoutPlanEditor(plan: plan) { updated in
                session.savePersonalWorkoutPlan(updated)
                editorPlan = nil
            }
        }
    }

    private func personalPlanCard(_ personal: ClientPersonalWorkoutPlan) -> some View {
        let plan = personal.asClientPlan()
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    ClientBadge(text: personal.status == .active ? "PERSONALE · ATTIVO" : "PERSONALE · \(personal.status.rawValue.uppercased())", tint: personal.status == .active ? ClientClay.sage : ClientClay.secondaryInk, symbol: "person.fill")
                    Text(personal.title).font(.title3.weight(.bold)).foregroundStyle(ClientClay.ink)
                    Text("\(personal.sessions.count) sessioni · modificabile").font(.caption).foregroundStyle(ClientClay.secondaryInk)
                }
                Spacer()
                Menu {
                    Button("Modifica", systemImage: "pencil") { editorPlan = personal }
                    Button("Duplica", systemImage: "plus.square.on.square") {
                        var copy = personal; copy.id = UUID(); copy.title += " · Copia"; copy.status = .draft; copy.updatedAt = Date(); session.savePersonalWorkoutPlan(copy)
                    }
                    Button(personal.status == .archived ? "Riattiva" : "Archivia", systemImage: "archivebox") {
                        var updated = personal; updated.status = personal.status == .archived ? .active : .archived; updated.updatedAt = Date(); session.savePersonalWorkoutPlan(updated)
                    }
                    Button("Elimina", systemImage: "trash", role: .destructive) { session.deletePersonalWorkoutPlan(personal.id) }
                } label: { Image(systemName: "ellipsis.circle").frame(width: 44, height: 44) }
            }

            if personal.status == .active {
                ForEach(plan.sessions) { workout in
                    NavigationLink {
                        ClientWorkoutSessionDetailView(plan: plan, workout: workout)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "figure.strengthtraining.traditional").foregroundStyle(ClientClay.accent)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(workout.name).font(.headline).foregroundStyle(ClientClay.ink)
                                Text("\(workout.exercises.count) esercizi").font(.caption).foregroundStyle(ClientClay.secondaryInk)
                            }
                            Spacer(); Image(systemName: "chevron.right").foregroundStyle(ClientClay.secondaryInk)
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .clayCard()
        .overlay { RoundedRectangle(cornerRadius: ClientClay.radius, style: .continuous).stroke(personal.status == .active ? ClientClay.sage.opacity(0.42) : ClientClay.border) }
    }

    static func newPlan() -> ClientPersonalWorkoutPlan {
        let now = Date()
        return ClientPersonalWorkoutPlan(
            id: UUID(), title: "La mia scheda", status: .active,
            sessions: [ClientPersonalWorkoutSession(id: UUID(), name: "Giorno A", weekday: nil, exercises: [])],
            createdAt: now, updatedAt: now
        )
    }
}

private struct ClientPersonalWorkoutPlanEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draft: ClientPersonalWorkoutPlan
    let onSave: (ClientPersonalWorkoutPlan) -> Void

    init(plan: ClientPersonalWorkoutPlan, onSave: @escaping (ClientPersonalWorkoutPlan) -> Void) {
        _draft = State(initialValue: plan); self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Scheda personale") {
                    TextField("Nome scheda", text: $draft.title)
                    Picker("Stato", selection: $draft.status) {
                        Text("Bozza").tag(ClientPersonalPlanStatus.draft)
                        Text("Attiva").tag(ClientPersonalPlanStatus.active)
                        Text("Archiviata").tag(ClientPersonalPlanStatus.archived)
                    }
                }
                Section("Sessioni") {
                    ForEach($draft.sessions) { $workout in
                        NavigationLink { ClientPersonalWorkoutSessionEditor(workout: $workout) } label: {
                            VStack(alignment: .leading) {
                                Text(workout.name).font(.headline)
                                Text("\(workout.exercises.count) esercizi").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                    .onDelete { draft.sessions.remove(atOffsets: $0) }
                    .onMove { draft.sessions.move(fromOffsets: $0, toOffset: $1) }
                    Button("Aggiungi sessione", systemImage: "plus") {
                        draft.sessions.append(ClientPersonalWorkoutSession(id: UUID(), name: "Nuova sessione", weekday: nil, exercises: []))
                    }
                }
            }
            .scrollContentBackground(.hidden).background(ClientClay.canvas)
            .navigationTitle("Modifica scheda").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Annulla") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salva") { draft.updatedAt = Date(); onSave(draft); dismiss() }
                        .disabled(draft.title.trimmingCharacters(in: .whitespacesAndNewlines).count < 2 || draft.sessions.isEmpty)
                }
                ToolbarItem(placement: .topBarTrailing) { EditButton() }
            }
        }
    }
}

private struct ClientPersonalWorkoutSessionEditor: View {
    @Binding var workout: ClientPersonalWorkoutSession
    @State private var showPicker = false

    var body: some View {
        Form {
            Section("Sessione") {
                TextField("Nome", text: $workout.name)
                Picker("Giorno", selection: $workout.weekday) {
                    Text("Libero").tag(Int?.none)
                    ForEach(Array(["Lunedì", "Martedì", "Mercoledì", "Giovedì", "Venerdì", "Sabato", "Domenica"].enumerated()), id: \.offset) { index, name in
                        Text(name).tag(Int?.some(index + 1))
                    }
                }
            }
            Section("Esercizi") {
                ForEach($workout.exercises) { $exercise in
                    NavigationLink { ClientPersonalExerciseEditor(exercise: $exercise) } label: {
                        VStack(alignment: .leading) {
                            Text(exercise.name).font(.headline)
                            Text("\(exercise.sets) × \(exercise.repetitions) · recupero \(exercise.restSeconds)s").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                .onDelete { workout.exercises.remove(atOffsets: $0) }
                .onMove { workout.exercises.move(fromOffsets: $0, toOffset: $1) }
                Button("Aggiungi esercizio", systemImage: "plus.circle.fill") { showPicker = true }
            }
        }
        .scrollContentBackground(.hidden).background(ClientClay.canvas)
        .navigationTitle(workout.name).toolbar { EditButton() }
        .sheet(isPresented: $showPicker) {
            ClientExercisePickerSheet { exercise in workout.exercises.append(exercise); showPicker = false }
        }
    }
}

private struct ClientPersonalExerciseEditor: View {
    @Binding var exercise: ClientPersonalExercise
    var body: some View {
        Form {
            Section("Prescrizione") {
                Stepper("Serie: \(exercise.sets)", value: $exercise.sets, in: 1...20)
                TextField("Ripetizioni", text: $exercise.repetitions)
                Stepper("Recupero: \(exercise.restSeconds)s", value: $exercise.restSeconds, in: 0...600, step: 15)
                TextField("Carico kg", value: $exercise.loadKg, format: .number).keyboardType(.decimalPad)
                TextField("RIR / RPE", text: $exercise.effortTarget)
            }
            Section("Indicazioni") { TextField("Note operative", text: $exercise.notes, axis: .vertical) }
        }
        .scrollContentBackground(.hidden).background(ClientClay.canvas).navigationTitle(exercise.name)
    }
}

private struct ClientExercisePickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var session: ClientSessionStore
    @State private var query = ""
    @State private var results: [ClientExerciseCatalogItem] = []
    @State private var customName = ""
    let onSelect: (ClientPersonalExercise) -> Void

    var body: some View {
        NavigationStack {
            List {
                Section("Database esercizi") {
                    if results.isEmpty { Text(query.isEmpty ? "Cerca nel catalogo globale" : "Nessun esercizio trovato").foregroundStyle(.secondary) }
                    ForEach(results) { item in
                        Button { onSelect(makeExercise(item.name, catalogID: item.id, muscle: item.muscleGroup ?? "", videoURL: item.videoURL)) } label: {
                            VStack(alignment: .leading) { Text(item.name); if let group = item.muscleGroup { Text(group).font(.caption).foregroundStyle(.secondary) } }
                        }
                    }
                }
                Section("Esercizio personale") {
                    TextField("Nome esercizio", text: $customName)
                    Button("Aggiungi esercizio personale", systemImage: "person.badge.plus") {
                        let exercise = makeExercise(customName, catalogID: nil, muscle: "", videoURL: nil)
                        session.savePersonalExercise(exercise)
                        onSelect(exercise)
                    }
                        .disabled(customName.trimmingCharacters(in: .whitespacesAndNewlines).count < 2)
                }
            }
            .searchable(text: $query, prompt: "Nome esercizio")
            .task(id: query) {
                try? await Task.sleep(for: .milliseconds(300))
                guard !Task.isCancelled else { return }
                results = await session.searchPersonalExercises(query)
            }
            .navigationTitle("Aggiungi esercizio").toolbar { ToolbarItem(placement: .cancellationAction) { Button("Chiudi") { dismiss() } } }
        }
    }

    private func makeExercise(_ name: String, catalogID: UUID?, muscle: String, videoURL: URL?) -> ClientPersonalExercise {
        ClientPersonalExercise(id: UUID(), catalogExerciseID: catalogID, name: name.trimmingCharacters(in: .whitespacesAndNewlines), muscleGroup: muscle, sets: 3, repetitions: "10", restSeconds: 90, loadKg: nil, effortTarget: "RIR 2", notes: "", videoURL: videoURL)
    }
}
