import SwiftUI

struct ClientPersonalWorkoutLibraryView: View {
    let allowsEditing: Bool
    @EnvironmentObject private var session: ClientSessionStore
    @State private var modal: ClientPersonalWorkoutModal?
    @State private var pendingModal: ClientPersonalWorkoutModal?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ClientSectionHeader(
                title: allowsEditing ? "Le mie schede" : "Schede personali precedenti",
                detail: libraryDetail,
                symbol: "person.crop.rectangle.stack.fill"
            )

            if !allowsEditing {
                Label(ClientAccessPolicy.trainerManagedPlansMessage, systemImage: "person.crop.circle.badge.checkmark")
                    .font(.subheadline)
                    .foregroundStyle(ClientClay.secondaryInk)
                    .clayCard(padding: 14)
            }

            if session.personalContent.workoutPlans.isEmpty {
                if allowsEditing {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Nessuna scheda personale", systemImage: "sparkles.rectangle.stack")
                            .font(.headline).foregroundStyle(ClientClay.ink)
                        Text("Crea sessioni, scegli gli esercizi reali del catalogo e allenati subito anche senza Trainer.")
                            .font(.subheadline).foregroundStyle(ClientClay.secondaryInk)
                        Button { modal = .creation } label: {
                            Label("+ Nuova scheda", systemImage: "plus.circle.fill").frame(maxWidth: .infinity)
                        }
                        .buttonStyle(ClayPrimaryButtonStyle())
                    }
                    .clayCard()
                } else {
                    Text("Nessuna scheda personale precedente.")
                        .font(.subheadline)
                        .foregroundStyle(ClientClay.secondaryInk)
                        .clayCard(padding: 14)
                }
            } else {
                ForEach(session.personalContent.workoutPlans) { plan in
                    personalPlanCard(plan)
                }
                if allowsEditing {
                    Button { modal = .creation } label: {
                        Label("Nuovo piano personale", systemImage: "plus").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(ClaySecondaryButtonStyle())
                }
            }
        }
        .sheet(item: $modal, onDismiss: presentPendingModal) { destination in
            switch destination {
            case .creation:
                ClientWorkoutCreationChoiceView { choice in
                    replaceModal(afterDismissWith: choice == .manual ? .manual : .guided)
                }
            case .manual:
                ClientManualWorkoutWizard(onSaved: { modal = nil })
            case .editor(let plan):
                ClientPersonalWorkoutPlanEditor(plan: plan, onSaved: { modal = nil })
            case .guided:
                ClientGuidedWorkoutView(
                    onSaved: { modal = nil },
                    onEdit: { plan in replaceModal(afterDismissWith: .editor(plan)) }
                )
            }
        }
        .onDisappear { pendingModal = nil }
    }

    private var libraryDetail: String {
        if session.personalContent.workoutPlans.isEmpty {
            return allowsEditing ? "Crea la prima" : "Nessuna"
        }
        return allowsEditing
            ? "\(session.personalContent.workoutPlans.count) piani"
            : "Storico · \(session.personalContent.workoutPlans.count)"
    }

    private func personalPlanCard(_ personal: ClientPersonalWorkoutPlan) -> some View {
        let plan = personal.asClientPlan()
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    ClientBadge(
                        text: allowsEditing
                            ? (personal.status == .active ? "PERSONALE · ATTIVO" : "PERSONALE · \(personal.status.rawValue.uppercased())")
                            : "PERSONALE · STORICO",
                        tint: allowsEditing && personal.status == .active ? ClientClay.sage : ClientClay.secondaryInk,
                        symbol: allowsEditing ? "person.fill" : "lock.fill"
                    )
                    Text(personal.title).font(.title3.weight(.bold)).foregroundStyle(ClientClay.ink)
                    Text("\(personal.sessions.count) sessioni · \(allowsEditing ? "modificabile" : "sola lettura")")
                        .font(.caption).foregroundStyle(ClientClay.secondaryInk)
                }
                Spacer()
                if allowsEditing {
                    Menu {
                        Button("Modifica", systemImage: "pencil") { modal = .editor(personal) }
                        Button("Duplica", systemImage: "plus.square.on.square") {
                            var copy = personal; copy.id = UUID(); copy.title += " · Copia"; copy.status = .draft; copy.updatedAt = Date(); session.savePersonalWorkoutPlan(copy)
                        }
                        Button(personal.status == .archived ? "Riattiva" : "Archivia", systemImage: "archivebox") {
                            var updated = personal; updated.status = personal.status == .archived ? .active : .archived; updated.updatedAt = Date(); session.savePersonalWorkoutPlan(updated)
                        }
                        Button("Elimina", systemImage: "trash", role: .destructive) { session.deletePersonalWorkoutPlan(personal.id) }
                    } label: { Image(systemName: "ellipsis.circle").frame(width: 44, height: 44) }
                } else {
                    Image(systemName: "lock.fill")
                        .font(.caption)
                        .foregroundStyle(ClientClay.secondaryInk)
                }
            }

            if allowsEditing && personal.status == .active {
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
            } else if !allowsEditing {
                ForEach(personal.sessions) { workout in
                    HStack(spacing: 12) {
                        Image(systemName: "figure.strengthtraining.traditional")
                            .foregroundStyle(ClientClay.secondaryInk)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(workout.name).font(.headline).foregroundStyle(ClientClay.ink)
                            Text("\(workout.exercises.count) esercizi")
                                .font(.caption).foregroundStyle(ClientClay.secondaryInk)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 4)
                    .accessibilityElement(children: .combine)
                }
            }
        }
        .clayCard()
        .overlay {
            RoundedRectangle(cornerRadius: ClientClay.radius, style: .continuous)
                .stroke(allowsEditing && personal.status == .active ? ClientClay.sage.opacity(0.42) : ClientClay.border)
        }
    }

    static func newPlan() -> ClientPersonalWorkoutPlan {
        let now = Date()
        return ClientPersonalWorkoutPlan(
            id: UUID(), title: "La mia scheda", status: .active,
            sessions: [ClientPersonalWorkoutSession(id: UUID(), name: "Giorno A", weekday: nil, exercises: [])],
            createdAt: now, updatedAt: now, source: .manual
        )
    }

    private func replaceModal(afterDismissWith destination: ClientPersonalWorkoutModal) {
        pendingModal = destination
        modal = nil
    }

    private func presentPendingModal() {
        let destination = pendingModal
        pendingModal = nil
        guard allowsEditing, case .active(let identity, _, _) = session.state,
              ClientAccessPolicy.canManagePersonalWorkoutPlans(in: identity.mode) else { return }
        modal = destination
    }
}

private enum ClientPersonalWorkoutModal: Identifiable {
    case creation
    case manual
    case editor(ClientPersonalWorkoutPlan)
    case guided

    var id: String {
        switch self {
        case .creation: "creation"
        case .manual: "manual"
        case .editor(let plan): "editor-\(plan.id.uuidString)"
        case .guided: "guided"
        }
    }
}

private struct ClientPersonalWorkoutPlanEditor: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var session: ClientSessionStore
    @State private var draft: ClientPersonalWorkoutPlan
    @State private var catalog: [ClientExerciseCatalogItem] = []
    @State private var loading = true
    @State private var ownerID: UUID?
    @State private var saveState: ClientWorkoutCoachSaveState = .localDraft
    @State private var showDiscard = false
    let onSaved: () -> Void

    init(plan: ClientPersonalWorkoutPlan, onSaved: @escaping () -> Void) {
        _draft = State(initialValue: plan); self.onSaved = onSaved
    }
    private var isCoach: Bool { draft.generationMetadata != nil }
    private var saving: Bool { saveState == .saving }
    private var confirmed: Bool { if case .confirmed = saveState { return true }; return false }
    private var validation: ClientEditedWorkoutPlanValidator.Result? {
        isCoach && !loading ? ClientEditedWorkoutPlanValidator().inspect(draft, catalog: catalog) : nil
    }
    private var coach: ClientWorkoutCoachEditingContext? {
        guard isCoach, let answers = draft.generationAnswers else { return nil }
        return .init(answers: answers, catalog: catalog)
    }
    private var canSave: Bool {
        !loading && !saving && draft.title.trimmingCharacters(in: .whitespacesAndNewlines).count >= 2
            && !draft.sessions.isEmpty && (!isCoach || validation?.canSave == true)
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
                    if isCoach {
                        Text("Programma di \(draft.durationWeeks ?? 0) settimane. Per cambiare preferenze o durata, torna al questionario.")
                            .font(.subheadline).foregroundStyle(ClientClay.secondaryInk)
                    } else if draft.source == .guided {
                        Picker("Durata programma", selection: Binding(get: { draft.durationWeeks ?? 8 }, set: { draft.durationWeeks = $0 })) {
                            ForEach([4,6,8,12], id: \.self) { Text("\($0) settimane").tag($0) }
                        }
                    }
                    Text(draft.status == .active ? "Salvando attiverai questa scheda e archivierai la precedente." : "La scheda non verrà attivata automaticamente.")
                        .font(.subheadline).foregroundStyle(ClientClay.secondaryInk)
                }
                Section {
                    if loading { ProgressView("Preparazione editor…") }
                    ForEach($draft.sessions) { $workout in
                        NavigationLink {
                            ClientPersonalWorkoutSessionEditor(workout: $workout, coach: coach)
                        } label: {
                            VStack(alignment: .leading, spacing: ClientSpacing.micro) {
                                Text(workout.name).font(.headline)
                                Text("\(workout.exercises.count) esercizi").font(.subheadline).foregroundStyle(.secondary)
                            }
                        }
                        .disabled(isCoach && coach == nil)
                        .deleteDisabled(isCoach)
                    }
                    .onDelete { draft.sessions.remove(atOffsets: $0) }
                    .onMove { draft.sessions.move(fromOffsets: $0, toOffset: $1) }
                    if !isCoach {
                        Button("Aggiungi sessione", systemImage: "plus") {
                            draft.sessions.append(.init(id: UUID(), name: "Nuova sessione", weekday: nil, exercises: []))
                        }
                    }
                } header: { Text("Sessioni") } footer: {
                    Text(isCoach ? "Rinomina, riordina e modifica gli esercizi. Scorri una riga a sinistra per sostituirla. Ogni modifica viene ricontrollata." : "Modifica liberamente la tua scheda personale.")
                }
                if let validation, !validation.canSave {
                    Section("Da correggere prima di salvare") {
                        ForEach(validation.messages, id: \.self) { Label($0, systemImage: "exclamationmark.triangle") }
                    }
                }
                Section {
                    Text(saveState.message).font(.subheadline)
                    if isCoach && !loading && catalog.isEmpty {
                        Button("Ricarica catalogo") { Task { await loadEditor(forceReload: true) } }
                    }
                }
            }
            .disabled(saving || confirmed || loading)
            .interactiveDismissDisabled()
            .scrollContentBackground(.hidden).background(ClientClay.canvas)
            .navigationTitle("Modifica scheda").navigationBarTitleDisplayMode(.inline)
            .task { await loadEditor() }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Annulla") { showDiscard = true }.disabled(saving || confirmed) }
                ToolbarItem(placement: .confirmationAction) {
                    if confirmed {
                        Button("Fine") { onSaved(); dismiss() }
                    } else {
                        Button(saving ? "Verifica…" : "Salva") {
                            guard canSave else { return }
                            draft.updatedAt = Date(); saveState = .saving
                            Task { @MainActor in
                                saveState = await session.saveWorkoutCoachPlan(validation?.plan ?? draft, catalog: catalog, expectedOwnerID: ownerID)
                                if case .confirmed = saveState { ClientHaptics.success() } else { ClientHaptics.warning() }
                            }
                        }.disabled(!canSave)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) { EditButton().disabled(saving || confirmed || loading) }
            }
            .confirmationDialog("Scartare le modifiche non confermate?", isPresented: $showDiscard, titleVisibility: .visible) {
                Button("Esci", role: .destructive) { dismiss() }
                Button("Continua a modificare", role: .cancel) {}
            } message: { Text("Eventuali copie già conservate sul dispositivo non vengono eliminate.") }
        }
    }
    private func loadEditor(forceReload: Bool = false) async {
        if ownerID == nil, case .active(let identity, _, _) = session.state { ownerID = identity.authUserID }
        loading = true
        if isCoach { catalog = await session.personalExerciseCatalog(forceReload: forceReload) }
        loading = false
    }
}

private struct ClientPersonalWorkoutSessionEditor: View {
    @Binding var workout: ClientPersonalWorkoutSession
    var coach: ClientWorkoutCoachEditingContext? = nil
    @State private var showPicker = false
    @State private var replacement: ClientPersonalExercise?
    private var usedIDs: Set<UUID> { Set(workout.exercises.compactMap(\.catalogExerciseID)) }
    private var addCandidates: [ClientWorkoutCatalogPolicy.Candidate]? {
        coach.map { $0.candidates.filter { !usedIDs.contains($0.item.id) && $0.primary.isSubset(of: Set(workout.targetMuscles ?? [])) } }
    }

    var body: some View {
        Form {
            Section("Sessione") {
                TextField("Nome", text: $workout.name)
                Picker("Giorno", selection: $workout.weekday) {
                    if coach == nil { Text("Libero").tag(Int?.none) }
                    ForEach(Array(["Lunedì","Martedì","Mercoledì","Giovedì","Venerdì","Sabato","Domenica"].enumerated()), id: \.offset) { index, name in
                        Text(name).tag(Int?.some(index + 1))
                    }
                }
                if coach == nil {
                    Stepper("Durata target: \(workout.durationMinutes ?? 60) min",
                        value: Binding(get: { workout.durationMinutes ?? 60 }, set: { workout.durationMinutes = $0 }), in: 30...120, step: 15)
                } else {
                    Text("Durata stimata: \(ClientWorkoutCoachRules.minutes(workout.exercises)) min, inclusi i recuperi.")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
            }
            Section("Esercizi") {
                ForEach($workout.exercises) { $exercise in
                    NavigationLink { ClientPersonalExerciseEditor(exercise: $exercise, isCoach: coach != nil) } label: {
                        VStack(alignment: .leading, spacing: ClientSpacing.micro) {
                            Text(exercise.name).font(.headline)
                            Text("\(exercise.sets) × \(exercise.repetitions) · recupero \(exercise.restSeconds)s").font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        if coach != nil {
                            Button("Sostituisci", systemImage: "arrow.triangle.2.circlepath") { replacement = exercise }
                        } else {
                            Button("Duplica", systemImage: "plus.square.on.square") { duplicateExercise(exercise.id) }.tint(ClientClay.accent)
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
            ClientExercisePickerSheet(coachCandidates: addCandidates) { exercise in
                workout.exercises.append(exercise); showPicker = false
            }
        }
        .sheet(item: $replacement) { original in
            ClientExercisePickerSheet(coachCandidates: coach?.alternatives(to: original, usedIDs: usedIDs), replacing: original) { exercise in
                if let index = workout.exercises.firstIndex(where: { $0.id == original.id }) { workout.exercises[index] = exercise }
                replacement = nil
            }
        }
    }
    private func duplicateExercise(_ id: UUID) {
        guard let index = workout.exercises.firstIndex(where: { $0.id == id }) else { return }
        var copy = workout.exercises[index]; copy.id = UUID()
        workout.exercises.insert(copy, at: index + 1)
    }
}

private struct ClientPersonalExerciseEditor: View {
    @Binding var exercise: ClientPersonalExercise
    var isCoach = false
    private var minimumRest: Int { isCoach ? (exercise.exerciseKind == .compound ? 90 : 45) : 0 }
    var body: some View {
        Form {
            Section("Prescrizione") {
                Stepper("Serie: \(exercise.sets)", value: $exercise.sets, in: 1...(isCoach ? 5 : 20))
                TextField("Ripetizioni", text: $exercise.repetitions)
                Stepper("Recupero: \(exercise.restSeconds)s", value: $exercise.restSeconds, in: minimumRest...(isCoach ? 300 : 600), step: 15)
                Text("Il carico reale si registra durante l'allenamento.").font(.subheadline).foregroundStyle(.secondary)
                if isCoach {
                    Picker("RIR prescritto", selection: $exercise.effortTarget) {
                        ForEach(1...4, id: \.self) { Text("RIR \($0)").tag("RIR \($0)") }
                    }
                } else { TextField("RIR / RPE", text: $exercise.effortTarget) }
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
    let coachCandidates: [ClientWorkoutCatalogPolicy.Candidate]?
    let replacing: ClientPersonalExercise?
    let onSelect: (ClientPersonalExercise) -> Void

    init(coachCandidates: [ClientWorkoutCatalogPolicy.Candidate]? = nil, replacing: ClientPersonalExercise? = nil,
         onSelect: @escaping (ClientPersonalExercise) -> Void) {
        self.coachCandidates = coachCandidates; self.replacing = replacing; self.onSelect = onSelect
    }
    var body: some View {
        NavigationStack {
            List {
                Section(replacing == nil ? "Database esercizi" : "Alternative compatibili") {
                    if results.isEmpty {
                        Text(coachCandidates == nil ? "Cerca nel catalogo globale" : "Nessuna variante verificata con questi vincoli. Mantieni l'esercizio o rivedi il programma.")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(results) { item in
                        Button { onSelect(makeExercise(item)) } label: {
                            VStack(alignment: .leading) {
                                Text(item.name)
                                if let group = item.muscleGroup { Text(group).font(.subheadline).foregroundStyle(.secondary) }
                            }.frame(minHeight: ClientControlSize.minimumTarget)
                        }
                    }
                }
                if coachCandidates == nil {
                    Section("Esercizio personale") {
                        TextField("Nome esercizio", text: $customName)
                        Button("Aggiungi esercizio personale", systemImage: "person.badge.plus") {
                            let exercise = ClientPersonalExercise(id: UUID(), catalogExerciseID: nil,
                                name: customName.trimmingCharacters(in: .whitespacesAndNewlines), muscleGroup: "",
                                sets: 3, repetitions: "10", restSeconds: 90, loadKg: nil, effortTarget: "RIR 2", notes: "", videoURL: nil)
                            session.savePersonalExercise(exercise); onSelect(exercise)
                        }.disabled(customName.trimmingCharacters(in: .whitespacesAndNewlines).count < 2)
                    }
                } else {
                    Text("Stesso ruolo muscolare e di movimento per le sostituzioni; attrezzatura, esclusioni e difficoltà verificati. Nessuna sostituzione casuale.")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
            }
            .searchable(text: $query, prompt: "Nome esercizio")
            .task(id: query) {
                if let coachCandidates {
                    results = coachCandidates.map(\.item).filter { query.isEmpty || $0.name.localizedCaseInsensitiveContains(query) }
                } else {
                    try? await Task.sleep(for: .milliseconds(300))
                    guard !Task.isCancelled else { return }
                    let matches = await session.searchPersonalExercises(query)
                    guard !Task.isCancelled else { return }
                    results = matches
                }
            }
            .navigationTitle(replacing == nil ? "Aggiungi esercizio" : "Sostituisci esercizio")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Chiudi") { dismiss() } } }
        }
    }
    private func makeExercise(_ item: ClientExerciseCatalogItem) -> ClientPersonalExercise {
        if let candidate = coachCandidates?.first(where: { $0.item.id == item.id }) {
            return ClientWorkoutCoachEditingContext.exercise(candidate, replacing: replacing)
        }
        let metadata = ClientExerciseMetadataNormalizer.enrich(item)
        return ClientPersonalExercise(id: UUID(), catalogExerciseID: metadata.id, catalogSourceKey: metadata.sourceKey,
            name: metadata.name, muscleGroup: metadata.primaryMuscles.first?.displayName ?? metadata.muscleGroup ?? "",
            sets: 3, repetitions: "10", restSeconds: 90, loadKg: nil, effortTarget: "RIR 2", notes: "", videoURL: metadata.videoURL,
            primaryMuscles: metadata.primaryMuscles, secondaryMuscles: metadata.secondaryMuscles,
            movementPattern: metadata.movementPattern, compatibleEquipment: metadata.compatibleEquipment,
            exerciseKind: metadata.kind, animationKey: metadata.animationKey, technique: metadata.instructions,
            difficultyLevel: metadata.difficultyLevel, catalogMuscles: metadata.catalogMuscles)
    }
}
