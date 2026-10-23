import SwiftUI

struct ClientManualWorkoutWizard: View {
    @EnvironmentObject private var session: ClientSessionStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var draft = ClientManualWorkoutDraft.newPlan()
    @State private var step = 0
    @State private var dayIndex = 0
    @State private var split: ClientManualWorkoutDraft.SuggestedSplit = .custom
    @State private var pendingDayCount: Int?
    @State private var showReduction = false
    @State private var showDiscard = false
    @State private var showPicker = false
    @State private var isSaving = false
    @State private var errorMessage: String?
    let onSaved: () -> Void

    private let titles = ["Quanti giorni vuoi allenarti?", "Scegli i gruppi per giorno", "Costruisci le tue giornate", "Serie e ripetizioni", "La tua scheda"]
    private var canEdit: Bool {
        guard case .active(let identity, _, _) = session.state else { return false }
        return ClientAccessPolicy.canManagePersonalWorkoutPlans(in: identity.mode)
    }
    private var canContinue: Bool {
        switch step {
        case 1: draft.sessions.allSatisfy { !($0.targetMuscles ?? []).isEmpty }
        case 2: draft.sessions.allSatisfy { !$0.exercises.isEmpty }
        case 3, 4: ClientManualWorkoutDraft.validationMessage(draft) == nil
        default: true
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    if !canEdit {
                        Label(ClientAccessPolicy.trainerManagedPlansMessage, systemImage: "lock.fill")
                            .foregroundStyle(ClientClay.secondaryInk).clayCard()
                    } else {
                        switch step {
                        case 0: daysStep
                        case 1: groupsStep
                        case 2: exercisesStep
                        case 3: prescriptionStep
                        default: previewStep
                        }
                    }
                    if let errorMessage {
                        Label(errorMessage, systemImage: "exclamationmark.circle")
                            .font(.subheadline).foregroundStyle(ClientClay.accent).clayCard(padding: 14)
                            .accessibilityAddTraits(.updatesFrequently)
                    }
                }
                .padding(ClientClay.pagePadding)
            }
            .disabled(isSaving)
            .clientPage()
            .navigationTitle("Crea da solo").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annulla") { showDiscard = true }.disabled(isSaving)
                }
            }
            .safeAreaInset(edge: .bottom) { navigationBar }
            .interactiveDismissDisabled()
            .confirmationDialog("Ridurre le giornate elimina le giornate finali e i loro esercizi.", isPresented: $showReduction, titleVisibility: .visible) {
                Button("Riduci giornate", role: .destructive) {
                    if let count = pendingDayCount { resizeDays(count) }
                    pendingDayCount = nil
                }
                Button("Mantieni tutte", role: .cancel) { pendingDayCount = nil }
            }
            .confirmationDialog("Uscire dalla creazione?", isPresented: $showDiscard, titleVisibility: .visible) {
                Button("Scarta la bozza", role: .destructive) { dismiss() }
                Button("Continua a creare", role: .cancel) { }
            } message: {
                Text("Gli eventuali tentativi di salvataggio conservati sul dispositivo non verranno eliminati.")
            }
            .sheet(isPresented: $showPicker) {
                ClientManualExercisePicker(groups: draft.sessions[dayIndex].targetMuscles ?? []) { item in
                    draft.sessions[dayIndex].exercises.append(ClientManualWorkoutDraft.exercise(from: item))
                    showPicker = false
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("PASSO \(step + 1) DI \(titles.count)").font(.caption.weight(.bold)).tracking(1).foregroundStyle(ClientClay.accent)
            ProgressView(value: Double(step + 1), total: Double(titles.count)).tint(ClientClay.accent)
            Text(titles[step]).font(.system(.title2, design: .rounded, weight: .bold))
            Text("Una scelta alla volta. I carichi reali li registrerai durante l’allenamento.")
                .font(.subheadline).foregroundStyle(ClientClay.secondaryInk)
        }
        .premiumCard(tint: ClientClay.accent)
    }

    private var daysStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 72))], spacing: 10) {
                ForEach(2...6, id: \.self) { count in
                    chip("\(count) giorni", selected: draft.sessions.count == count) {
                        if count < draft.sessions.count {
                            pendingDayCount = count; showReduction = true
                        } else { resizeDays(count) }
                    }
                }
            }
            Text("Vuoi partire da uno split suggerito?").font(.headline)
            ForEach(ClientManualWorkoutDraft.SuggestedSplit.allCases, id: \.self) { value in
                chip(value.rawValue, selected: split == value) {
                    split = value; ClientManualWorkoutDraft.apply(value, to: &draft)
                }
            }
            Text("Sono punti di partenza: puoi cambiare tutti i gruppi nel prossimo passo.")
                .font(.caption).foregroundStyle(ClientClay.secondaryInk)
        }.clayCard()
    }

    private var daySelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(draft.sessions.indices, id: \.self) { index in
                    chip("Giorno \(index + 1)", selected: dayIndex == index) { dayIndex = index }
                }
            }
        }
    }

    private var groupsStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            daySelector
            TextField("Nome giornata", text: $draft.sessions[dayIndex].name).clientInputField()
            Picker("Giorno della settimana", selection: $draft.sessions[dayIndex].weekday) {
                Text("Lo scelgo quando mi alleno").tag(Int?.none)
                ForEach(Array(["Lunedì", "Martedì", "Mercoledì", "Giovedì", "Venerdì", "Sabato", "Domenica"].enumerated()), id: \.offset) { index, name in
                    Text(name).tag(Int?.some(index + 1))
                }
            }.tint(ClientClay.ink)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 132))], spacing: 10) {
                ForEach(ClientMuscleRegion.allCases, id: \.self) { group in
                    chip(group.displayName, selected: (draft.sessions[dayIndex].targetMuscles ?? []).contains(group)) {
                        var groups = draft.sessions[dayIndex].targetMuscles ?? []
                        if groups.contains(group) { groups.removeAll { $0 == group } } else { groups.append(group) }
                        draft.sessions[dayIndex].targetMuscles = groups
                    }
                }
            }
            Text("Seleziona almeno un gruppo per ogni giornata. Cambiare i gruppi non elimina gli esercizi già scelti.")
                .font(.caption).foregroundStyle(ClientClay.secondaryInk)
        }.clayCard()
    }

    private var exercisesStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            daySelector
            Text(groupSummary(draft.sessions[dayIndex])).font(.subheadline).foregroundStyle(ClientClay.secondaryInk)
            ForEach(Array(draft.sessions[dayIndex].exercises.enumerated()), id: \.element.id) { index, exercise in
                VStack(alignment: .leading, spacing: 8) {
                    Text("\(index + 1). \(exercise.name)").font(.headline)
                    HStack {
                        Button { moveExercise(index, by: -1) } label: { Image(systemName: "arrow.up").frame(width: 44, height: 44) }
                            .disabled(index == 0).accessibilityLabel("Sposta \(exercise.name) prima")
                        Button { moveExercise(index, by: 1) } label: { Image(systemName: "arrow.down").frame(width: 44, height: 44) }
                            .disabled(index == draft.sessions[dayIndex].exercises.count - 1).accessibilityLabel("Sposta \(exercise.name) dopo")
                        Spacer()
                        Button {
                            var copy = exercise; copy.id = UUID()
                            draft.sessions[dayIndex].exercises.insert(copy, at: index + 1)
                        } label: { Image(systemName: "plus.square.on.square").frame(width: 44, height: 44) }
                            .accessibilityLabel("Duplica \(exercise.name)")
                        Button(role: .destructive) { draft.sessions[dayIndex].exercises.remove(at: index) } label: {
                            Image(systemName: "trash").frame(width: 44, height: 44)
                        }.accessibilityLabel("Elimina \(exercise.name)")
                    }
                }.clayCard(padding: 14)
                    .draggable(exercise.id.uuidString)
                    .dropDestination(for: String.self) { items, _ in
                        guard let value = items.first, let id = UUID(uuidString: value),
                              let source = draft.sessions[dayIndex].exercises.firstIndex(where: { $0.id == id }) else { return false }
                        draft.sessions[dayIndex].exercises.move(fromOffsets: IndexSet(integer: source), toOffset: index > source ? index + 1 : index)
                        return true
                    }
            }
            if draft.sessions[dayIndex].exercises.isEmpty {
                Text("Partiamo dal primo esercizio.").foregroundStyle(ClientClay.secondaryInk)
            } else if draft.sessions[dayIndex].exercises.count > 7 {
                Label("Questa giornata potrebbe risultare lunga. Puoi comunque mantenerla.", systemImage: "clock")
                    .font(.caption).foregroundStyle(ClientClay.secondaryInk)
            }
            Button { showPicker = true } label: { Label("Aggiungi esercizio", systemImage: "plus").frame(maxWidth: .infinity) }
                .buttonStyle(ClaySecondaryButtonStyle())
            Text("Completa tutte le giornate prima di continuare.").font(.caption).foregroundStyle(ClientClay.secondaryInk)
        }
    }

    private var prescriptionStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            daySelector
            ForEach($draft.sessions[dayIndex].exercises) { $exercise in
                DisclosureGroup {
                    VStack(alignment: .leading, spacing: 12) {
                        Stepper("Serie: \(exercise.sets)", value: $exercise.sets, in: 1...20)
                        TextField("Ripetizioni, es. 8–10", text: $exercise.repetitions).clientInputField()
                        Stepper("Recupero: \(exercise.restSeconds)s", value: $exercise.restSeconds, in: 0...600, step: 15)
                        TextField("RIR / RPE (facoltativo)", text: $exercise.effortTarget).clientInputField()
                        TextField("Note operative (facoltative)", text: $exercise.notes, axis: .vertical).clientInputField()
                    }.padding(.top, 12)
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(exercise.name).font(.headline)
                        Text("\(exercise.sets) × \(exercise.repetitions) · \(exercise.restSeconds)s · \(exercise.effortTarget)")
                            .font(.caption).foregroundStyle(ClientClay.secondaryInk)
                    }
                }.tint(ClientClay.accent).clayCard(padding: 14)
            }
        }
    }

    private var previewStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            TextField("Nome scheda", text: $draft.title).clientInputField()
            ForEach(Array(draft.sessions.enumerated()), id: \.element.id) { index, day in
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(day.name).font(.headline)
                            Text(groupSummary(day)).font(.caption).foregroundStyle(ClientClay.secondaryInk)
                        }
                        Spacer()
                        Button("Modifica") { dayIndex = index; step = 2 }
                            .frame(minHeight: 44)
                    }
                    ForEach(day.exercises) { exercise in
                        HStack(alignment: .top) {
                            Text(exercise.name).font(.subheadline)
                            Spacer()
                            Text("\(exercise.sets) × \(exercise.repetitions)").font(.subheadline.weight(.semibold))
                        }
                    }
                }.clayCard(padding: 14)
            }
            Label("Carichi liberi: li registrerai serie per serie durante l’esecuzione.", systemImage: "dumbbell.fill")
                .font(.caption).foregroundStyle(ClientClay.secondaryInk)
        }
    }

    private var navigationBar: some View {
        HStack(spacing: 12) {
            if step > 0 {
                Button("Indietro") { step -= 1; errorMessage = nil }.buttonStyle(ClaySecondaryButtonStyle()).disabled(isSaving)
            }
            Button {
                errorMessage = nil
                if step == titles.count - 1 { save() } else { withAnimation(reduceMotion ? nil : .snappy) { step += 1 } }
            } label: {
                HStack {
                    if isSaving { ProgressView().tint(ClientClay.color(.textOnAccent)) }
                    Text(isSaving ? "Verifica salvataggio…" : step == titles.count - 1 ? "Salva scheda" : "Continua")
                }.frame(maxWidth: .infinity)
            }.buttonStyle(ClayPrimaryButtonStyle()).disabled(!canEdit || !canContinue || isSaving)
        }.padding(.horizontal, ClientClay.pagePadding).padding(.vertical, 12).background(ClientClay.canvas)
    }

    private func chip(_ text: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button { ClientHaptics.selection(); action() } label: {
            Text(text).font(.subheadline.weight(.semibold)).frame(maxWidth: .infinity, minHeight: 44)
                .padding(.horizontal, 10)
                .background(selected ? ClientClay.accent.opacity(0.18) : ClientClay.surfaceElevated, in: RoundedRectangle(cornerRadius: 14))
                .overlay { RoundedRectangle(cornerRadius: 14).stroke(selected ? ClientClay.accent : ClientClay.border) }
                .foregroundStyle(ClientClay.ink)
        }.buttonStyle(.plain).accessibilityAddTraits(selected ? [.isSelected] : [])
    }

    private func resizeDays(_ count: Int) {
        ClientManualWorkoutDraft.resize(&draft, count: count)
        dayIndex = min(dayIndex, draft.sessions.count - 1)
        // Reapply suggestions only to newly added days, preserving customized existing groups.
        var suggested = draft
        ClientManualWorkoutDraft.apply(split, to: &suggested)
        for index in draft.sessions.indices where draft.sessions[index].targetMuscles == nil {
            draft.sessions[index].targetMuscles = suggested.sessions[index].targetMuscles
        }
    }

    private func moveExercise(_ index: Int, by offset: Int) {
        let destination = index + offset
        guard draft.sessions[dayIndex].exercises.indices.contains(destination) else { return }
        draft.sessions[dayIndex].exercises.swapAt(index, destination)
    }

    private func groupSummary(_ day: ClientPersonalWorkoutSession) -> String {
        (day.targetMuscles ?? []).map(\.displayName).joined(separator: " + ")
    }

    private func save() {
        guard canEdit, !isSaving else { return }
        if let message = ClientManualWorkoutDraft.validationMessage(draft) { errorMessage = message; return }
        draft.updatedAt = Date()
        isSaving = true
        Task { @MainActor in
            let saved = await session.savePersonalWorkoutPlanConfirmed(draft)
            isSaving = false
            if saved { onSaved() }
            else { errorMessage = session.notice ?? "Salvataggio non confermato. La bozza è ancora qui: riprova." }
        }
    }
}

private struct ClientManualExercisePicker: View {
    let groups: [ClientMuscleRegion]
    let onSelect: (ClientExerciseCatalogItem) -> Void
    @EnvironmentObject private var session: ClientSessionStore
    @Environment(\.dismiss) private var dismiss
    @State private var catalog: [ClientExerciseCatalogItem] = []
    @State private var query = ""
    @State private var loading = true
    @State private var showAllGroups = false

    private var results: [ClientExerciseCatalogItem] {
        catalog.filter {
            (showAllGroups || ClientManualWorkoutDraft.catalogMatches($0, groups: groups)) &&
            (query.isEmpty || $0.name.localizedStandardContains(query))
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Toggle("Mostra anche altri gruppi", isOn: $showAllGroups)
                    Text("Catalogo globale · nessuna libreria privata Trainer").font(.caption).foregroundStyle(.secondary)
                }
                if loading { ProgressView("Caricamento catalogo…") }
                else if catalog.isEmpty {
                    Text("Catalogo non disponibile. Controlla la connessione e riprova.")
                    Button("Riprova") { Task { await load(force: true) } }
                } else if results.isEmpty {
                    Text("Nessun esercizio compatibile con questa ricerca.")
                    Button("Mostra tutti gli esercizi") { query = ""; showAllGroups = true }
                }
                ForEach(results) { item in
                    Button { onSelect(item) } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.name).font(.headline)
                            Text(item.primaryMuscles.map(\.displayName).joined(separator: " + "))
                                .font(.caption).foregroundStyle(.secondary)
                        }.frame(minHeight: 44)
                    }
                }
            }
            .scrollContentBackground(.hidden).background(ClientClay.canvas)
            .searchable(text: $query, prompt: "Cerca esercizio")
            .navigationTitle("Scegli esercizio").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Chiudi") { dismiss() } } }
            .task { await load(force: false) }
        }
    }

    private func load(force: Bool) async {
        loading = true
        catalog = await session.personalExerciseCatalog(forceReload: force)
        loading = false
    }
}
