import SwiftUI

struct ClientWorkoutCreationChoiceView: View {
    enum Choice { case manual, guided }

    let onSelect: (Choice) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var selected = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("COME VUOI CREARLA?")
                            .font(.caption.weight(.bold)).tracking(1.3).foregroundStyle(ClientClay.accent)
                        Text("Il tuo prossimo programma")
                            .font(.system(.title, design: .rounded, weight: .heavy)).foregroundStyle(ClientClay.ink)
                        Text("Scegli ogni dettaglio con una guida passo passo oppure lascia che GymManager costruisca una base coerente, sempre modificabile.")
                            .font(.subheadline).foregroundStyle(ClientClay.secondaryInk)
                    }
                    .premiumCard(tint: ClientClay.accent)

                    choiceCard(
                        title: "Crea da solo",
                        detail: "Ti guidiamo: giorni, gruppi, esercizi e serie. Un passo alla volta.",
                        symbol: "slider.horizontal.3",
                        tint: ClientClay.sage
                    ) { select(.manual) }

                    choiceCard(
                        title: "Crea per me",
                        detail: "Rispondi a poche domande e ricevi un programma guidato, controllato e modificabile.",
                        symbol: "wand.and.stars",
                        tint: ClientClay.accent
                    ) { select(.guided) }

                    Label("Disponibile solo senza Trainer collegato", systemImage: "lock.shield.fill")
                        .font(.caption.weight(.semibold)).foregroundStyle(ClientClay.secondaryInk)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .padding(ClientClay.pagePadding)
            }
            .clientPage()
            .navigationTitle("Nuova scheda")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Chiudi") { dismiss() } } }
        }
    }

    private func choiceCard(
        title: String,
        detail: String,
        symbol: String,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: symbol)
                    .font(.title2.weight(.bold)).foregroundStyle(ClientClay.ink)
                    .frame(width: 52, height: 52)
                    .background(tint.gradient, in: RoundedRectangle(cornerRadius: 17, style: .continuous))
                VStack(alignment: .leading, spacing: 5) {
                    Text(title).font(.title3.weight(.bold)).foregroundStyle(ClientClay.ink)
                    Text(detail).font(.subheadline).foregroundStyle(ClientClay.secondaryInk).multilineTextAlignment(.leading)
                }
                Spacer(minLength: 4)
                Image(systemName: "chevron.right").font(.headline).foregroundStyle(tint)
            }
            .clayCard()
        }
        .buttonStyle(.plain)
        .disabled(selected)
        .accessibilityHint(detail)
    }

    private func select(_ choice: Choice) {
        guard !selected else { return }
        selected = true
        onSelect(choice)
    }
}

struct ClientGuidedWorkoutView: View {
    let onSaved: () -> Void
    let onEdit: (ClientPersonalWorkoutPlan) -> Void

    @EnvironmentObject private var session: ClientSessionStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var draft = ClientWorkoutCoachDraft()
    @State private var step: ClientWorkoutCoachStep = .experience
    @State private var catalog: [ClientExerciseCatalogItem] = []
    @State private var loadingCatalog = true
    @State private var generating = false
    @State private var feedback: ClientWorkoutCoachFeedback?
    @State private var result: ClientGeneratedWorkoutResult?
    @State private var saveState: ClientWorkoutCoachSaveState = .localDraft
    @State private var variation = 0
    @State private var selectedSessionID: UUID?
    @State private var showExclusions = false
    @State private var showDiscard = false
    @State private var ownerID: UUID?
    @FocusState private var focusedNumber: NumberField?
    @AccessibilityFocusState private var feedbackFocused: Bool
    private enum NumberField: Hashable { case total, recent }
    private var saving: Bool { saveState == .saving }
    private var confirmed: Bool { if case .confirmed = saveState { return true }; return false }
    private var currentIssue: ClientWorkoutCoachFeedback? {
        step == .review
            ? ClientWorkoutCoachStep.allCases.compactMap { draft.issue(at: $0, catalog: catalog) }.first
            : draft.issue(at: step, catalog: catalog)
    }

    var body: some View {
        NavigationStack {
            Group { if let result { preview(result) } else { questionnaire } }
                .clientPage()
                .navigationTitle(result == nil ? "Crea per me" : "Il tuo programma")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(confirmed ? "Fine" : "Chiudi") {
                            if confirmed { onSaved(); dismiss() } else { showDiscard = true }
                        }.disabled(saving || generating)
                    }
                    ToolbarItemGroup(placement: .keyboard) {
                        Spacer()
                        Button("Fine") { focusedNumber = nil }
                    }
                }
                .task {
                    if ownerID == nil, case .active(let identity, _, _) = session.state { ownerID = identity.authUserID }
                    if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" { loadingCatalog = false }
                    else { await loadCatalog() }
                }
                .onChange(of: feedback) { _, value in feedbackFocused = value != nil }
                .sheet(isPresented: $showExclusions) {
                    ClientCoachExclusionsSheet(catalog: catalog, selected: $draft.excludedIDs)
                }
                .confirmationDialog("Uscire dal programma guidato?", isPresented: $showDiscard, titleVisibility: .visible) {
                    Button("Esci senza confermare", role: .destructive) { dismiss() }
                    Button("Continua", role: .cancel) {}
                } message: {
                    Text("Le risposte non salvate andranno perse. Eventuali copie già conservate sul dispositivo non vengono eliminate.")
                }
        }
        .interactiveDismissDisabled()
    }

    private var questionnaire: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: ClientSpacing.related) {
                Text("Passo \(step.rawValue + 1) di \(ClientWorkoutCoachStep.allCases.count)")
                    .font(.subheadline).foregroundStyle(ClientClay.secondaryInk)
                ProgressView(value: Double(step.rawValue + 1), total: Double(ClientWorkoutCoachStep.allCases.count))
                    .tint(ClientClay.accent)
                    .accessibilityLabel("Avanzamento questionario")
                Text(step.title).font(ClientTypography.section).foregroundStyle(ClientClay.ink)
            }.padding(ClientSpacing.page)
            Form {
                if let feedback { feedbackSection(feedback) }
                stepContent
                if let issue = currentIssue, feedback == nil, step != .review {
                    Section { Text(issue.message).font(.subheadline).foregroundStyle(ClientClay.secondaryInk) }
                }
            }
            .scrollContentBackground(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .disabled(generating)
        }
        .safeAreaInset(edge: .bottom) { navigationBar }
    }

    @ViewBuilder private var stepContent: some View {
        switch step {
        case .experience:
            Section {
                TextField("Mesi totali di allenamento", text: $draft.totalMonths)
                    .keyboardType(.numberPad).focused($focusedNumber, equals: .total)
                TextField("Mesi recenti senza lunghe interruzioni", text: $draft.recentMonths)
                    .keyboardType(.numberPad).focused($focusedNumber, equals: .recent)
                Picker("Allenamenti recenti a settimana", selection: $draft.recentFrequency) {
                    Text("Seleziona").tag(Int?.none)
                    ForEach(0...7, id: \.self) { Text("\($0)").tag(Int?.some($0)) }
                }
                Picker("Come ti descriveresti?", selection: $draft.perceivedLevel) {
                    Text("Seleziona").tag(ClientTrainingExperience?.none)
                    ForEach(ClientTrainingExperience.allCases, id: \.self) { Text($0.displayName).tag(ClientTrainingExperience?.some($0)) }
                }
            } header: { Text("La tua esperienza") } footer: { Text("Puoi indicare zero mesi o zero allenamenti. Non è una valutazione della tua forza.") }
        case .skills:
            Section {
                yesNo("Conosci la tecnica dei multiarticolari?", selection: $draft.compoundFamiliarity)
                yesNo("Sai stimare quante ripetizioni ti restano (RIR)?", selection: $draft.canUseRIR)
                yesNo("Hai già aumentato i carichi con una progressione?", selection: $draft.hasUsedProgression)
            } header: { Text("Quello che conosci già") } footer: { Text("Rispondi anche No: ci aiuta a non proporre complessità non necessaria.") }
            if let level = draft.effectiveLevel {
                Section {
                    LabeledContent("Livello stimato", value: level.displayName)
                    Text("Abbiamo considerato continuità e familiarità, senza superare il livello che hai indicato.")
                        .font(.subheadline).foregroundStyle(ClientClay.secondaryInk)
                }
            }
        case .availability:
            Section {
                Picker("Giorni a settimana", selection: $draft.frequency) {
                    Text("Seleziona").tag(Int?.none)
                    ForEach(2...6, id: \.self) { Text("\($0) giorni").tag(Int?.some($0)) }
                }
                .onChange(of: draft.frequency) { _, _ in draft.resizeCustomSplit() }
                Picker("Minuti per sessione", selection: $draft.minutes) {
                    Text("Seleziona").tag(Int?.none)
                    ForEach([30,45,60,75,90], id: \.self) { Text("\($0) minuti").tag(Int?.some($0)) }
                }
            } header: { Text("La tua disponibilità") } footer: {
                Text("Queste scelte influenzano esercizi, split e volume. La durata stimata comprende anche i recuperi.")
            }
        case .equipment:
            equipmentStep
        case .goal:
            Section("Obiettivo") {
                Picker("Cosa cerchi?", selection: $draft.goal) {
                    Text("Seleziona").tag(ClientTrainingGoal?.none)
                    ForEach(ClientTrainingGoal.allCases, id: \.self) { Text($0.displayName).tag(ClientTrainingGoal?.some($0)) }
                }
                Picker("Fase attuale", selection: $draft.phase) {
                    Text("Seleziona").tag(ClientNutritionPhase?.none)
                    ForEach(ClientNutritionPhase.allCases, id: \.self) { Text($0.displayName).tag(ClientNutritionPhase?.some($0)) }
                }
                Picker("Durata del programma", selection: $draft.weeks) {
                    Text("Seleziona").tag(Int?.none)
                    ForEach([4,6,8,12], id: \.self) { Text("\($0) settimane").tag(Int?.some($0)) }
                }
                Text("Obiettivo e fase modificano struttura e volume, non trasformano automaticamente ogni esercizio in un diverso range di ripetizioni.")
                    .font(.subheadline).foregroundStyle(ClientClay.secondaryInk)
            }
        case .split:
            Section {
                Picker("Organizzazione", selection: $draft.split) {
                    Text("Seleziona").tag(ClientWorkoutSplitPreference?.none)
                    ForEach(ClientWorkoutSplitPreference.allCases, id: \.self) { option in
                        Text(splitName(option)).tag(ClientWorkoutSplitPreference?.some(option))
                            .disabled(!draft.isSplitAvailable(option))
                    }
                }
                .onChange(of: draft.split) { _, _ in draft.resizeCustomSplit() }
                Text("Decidi tu usa anche tempo, esperienza e priorità. Le scelte incompatibili non vengono corrette di nascosto.")
                    .font(.subheadline).foregroundStyle(ClientClay.secondaryInk)
            }
            if draft.split == .custom {
                ForEach(0..<(draft.frequency ?? 0), id: \.self) { day in
                    Section("Giorno \(day + 1)") {
                        ForEach(ClientMuscleRegion.allCases, id: \.self) { muscle in
                            Toggle(muscle.displayName, isOn: customMuscle(muscle, day: day))
                        }
                    }
                }
            }
            if draft.issue(at: .split, catalog: catalog) != nil, draft.split != nil {
                Section { Button("Usa Decidi tu") { draft.split = .automatic } }
            }
        case .priorities:
            Section {
                ForEach(ClientMuscleRegion.allCases, id: \.self) { muscle in
                    Toggle(muscle.displayName, isOn: membership(muscle, in: $draft.priorities))
                }
                Button("Nessuno in particolare") { draft.priorities.removeAll() }
            } header: { Text("Gruppi prioritari · facoltativo") } footer: {
                Text("La priorità aumenta moderatamente l'attenzione senza trascurare il resto del corpo. Scegli poche priorità: molte richieste possono non entrare nel tempo disponibile.")
            }
        case .exclusions:
            Section {
                Button("Scegli dal catalogo · \(draft.excludedIDs.count) esclusi") { showExclusions = true }
                    .frame(minHeight: ClientControlSize.minimumTarget)
                ForEach(ClientWorkoutCoachDraft.visibleCatalogRows(catalog).filter { draft.excludedIDs.contains($0.id) }) { item in
                    HStack {
                        Text(item.name)
                        Spacer()
                        Button("Rimuovi") { draft.excludedIDs.remove(item.id) }
                            .frame(minHeight: ClientControlSize.minimumTarget)
                    }
                }
            } header: { Text("Esercizi da evitare · facoltativo") } footer: {
                Text("Salviamo la selezione dell'esercizio reale, senza chiedere una motivazione medica.")
            }
        case .safety:
            Section {
                Text("GymManager genera programmi per attività fitness generale e non sostituisce prescrizioni mediche o riabilitative.")
                Toggle("Confermo di cercare fitness generale per adulti sani, non riabilitazione", isOn: Binding(
                    get: { draft.acknowledgement == true }, set: { draft.acknowledgement = $0 }))
                TextField("Preferenze o limitazioni · facoltativo", text: $draft.limitations, axis: .vertical)
            } header: { Text("Attività fitness generale") } footer: {
                Text("Con dolore importante o infortunio, fermati e rivolgiti a un professionista. Non vengono creati protocolli riabilitativi.")
            }
        case .review:
            Section("Prima di creare") {
                summaryRow("Livello stimato", draft.effectiveLevel?.displayName)
                summaryRow("Giorni", draft.frequency.map { "\($0) a settimana" })
                summaryRow("Durata", draft.minutes.map { "\($0) min per sessione" })
                summaryRow("Attrezzatura", equipmentSummary)
                summaryRow("Obiettivo", draft.goal?.displayName)
                summaryRow("Fase", draft.phase?.displayName)
                summaryRow("Split", draft.split.map(splitName))
                summaryRow("Priorità", draft.priorities.isEmpty ? "Nessuna" : draft.priorities.map(\.displayName).sorted().joined(separator: ", "))
                summaryRow("Esercizi esclusi", "\(draft.excludedIDs.count)")
                summaryRow("Programma", draft.weeks.map { "\($0) settimane" })
            }
            if let first = ClientWorkoutCoachStep.allCases.compactMap({ draft.issue(at: $0, catalog: catalog) }).first {
                feedbackSection(first)
            }
        }
    }

    @ViewBuilder private var equipmentStep: some View {
        Section("Contesti verificati nel catalogo") {
            if loadingCatalog { ProgressView("Caricamento catalogo…") }
            ForEach(draft.availableEquipment(in: catalog), id: \.self) { value in
                Button {
                    draft.equipment = value
                    feedback = nil
                } label: {
                    Label(value.displayName, systemImage: draft.equipment == value ? "checkmark.circle.fill" : "circle")
                        .frame(maxWidth: .infinity, minHeight: ClientControlSize.minimumTarget, alignment: .leading)
                }
                .accessibilityAddTraits(draft.equipment == value ? .isSelected : [])
            }
            if !loadingCatalog && draft.availableEquipment(in: catalog).isEmpty {
                Text("Il catalogo disponibile non ha abbastanza varianti verificate per queste risposte. Non proponiamo opzioni che il motore non sa coprire.")
                    .font(.subheadline)
            }
            Button("Ricarica catalogo") { Task { await loadCatalog(forceReload: true) } }.disabled(loadingCatalog)
        }
        if let equipment = draft.equipment, equipment != .fullGym {
            Section("Quello che hai davvero") {
                ForEach(draft.verifiedInventory(in: catalog), id: \.self) { item in
                    Toggle(item.title, isOn: membership(item, in: $draft.inventory))
                }
            }
        }
        if draft.equipment == .fullGym {
            Section { Text("Scegli Palestra completa solo se hai accesso a macchine, cavi, bilanciere con supporti, panca e manubri.") }
        }
    }

    private var navigationBar: some View {
        VStack(spacing: ClientSpacing.related) {
            if generating { Text("Sto preparando la tua scheda").font(.subheadline).accessibilityAddTraits(.updatesFrequently) }
            HStack(spacing: ClientSpacing.control) {
                if step.rawValue > 0 {
                    Button("Indietro") { move(to: ClientWorkoutCoachStep(rawValue: step.rawValue - 1)!) }
                        .buttonStyle(ClaySecondaryButtonStyle())
                }
                Button {
                    focusedNumber = nil
                    if step == .review { generate() }
                    else if let next = ClientWorkoutCoachStep(rawValue: step.rawValue + 1) { move(to: next) }
                } label: {
                    HStack {
                        if generating { ProgressView().tint(ClientClay.color(.textOnAccent)) }
                        Text(step == .review ? "Crea scheda" : "Continua").frame(maxWidth: .infinity)
                            .foregroundStyle(ClientClay.color(.textOnAccent))
                    }
                }
                .buttonStyle(ClayPrimaryButtonStyle())
                .disabled(generating || loadingCatalog && step == .equipment || currentIssue != nil)
            }
        }
        .padding(ClientSpacing.page).background(ClientClay.canvas)
        .disabled(generating)
    }

    private func preview(_ generated: ClientGeneratedWorkoutResult) -> some View {
        Form {
            Section {
                Text(generated.plan.title).font(ClientTypography.section)
                summaryRow("Livello stimato", generated.plan.generationMetadata?.effectiveExperience.displayName)
                summaryRow("Organizzazione", generated.plan.generationMetadata?.strategy.coachTitle)
                summaryRow("Allenamenti", "\(generated.plan.sessions.count) a settimana")
                summaryRow("Durata stimata", generated.plan.generationMetadata.map { $0.estimatedSessionMinutes.map { "\($0)" }.joined(separator: " / ") + " min" })
                Text(saveState.message).font(.subheadline).foregroundStyle(ClientClay.secondaryInk)
            }
            Section("Perché questo programma") {
                ForEach(ClientWorkoutCoachExplanation.lines(for: generated.plan), id: \.self) { Text($0).font(.subheadline) }
            }
            Section("Le tue sessioni") {
                Picker("Sessione", selection: $selectedSessionID) {
                    ForEach(generated.plan.sessions) { Text($0.name).tag(UUID?.some($0.id)) }
                }
                if let workout = generated.plan.sessions.first(where: { $0.id == selectedSessionID }) ?? generated.plan.sessions.first {
                    Text("\(workout.name) · circa \(workout.durationMinutes ?? 0) min").font(.headline)
                    ForEach(workout.exercises) { exercise in
                        VStack(alignment: .leading, spacing: ClientSpacing.micro) {
                            Text(exercise.name).font(.headline)
                            Text("\(exercise.sets) × \(exercise.repetitions) · \(exercise.effortTarget) · recupero \(exercise.restSeconds)s")
                                .font(.subheadline).foregroundStyle(ClientClay.secondaryInk)
                        }.padding(.vertical, ClientSpacing.micro)
                    }
                }
            }
            if let feedback { feedbackSection(feedback) }
            Section {
                if confirmed {
                    Button("Fine") { onSaved(); dismiss() }.frame(minHeight: ClientControlSize.minimumTarget)
                } else {
                    Button("Salva e attiva questa scheda") { Task { await save(generated.plan) } }
                        .frame(minHeight: ClientControlSize.minimumTarget)
                    Button("Modifica prima di salvare") { onEdit(generated.plan) }
                        .frame(minHeight: ClientControlSize.minimumTarget)
                    Button("Rigenera con le stesse risposte") { variation += 1; generate() }
                        .frame(minHeight: ClientControlSize.minimumTarget)
                    Button("Rivedi le risposte") { result = nil; move(to: .review) }
                        .frame(minHeight: ClientControlSize.minimumTarget)
                }
            } header: { Text("La tua scheda") } footer: { Text("Il carico reale si registra durante l'allenamento. La bozza non è una conferma di salvataggio.") }
        }
        .scrollContentBackground(.hidden)
        .disabled(saving || generating)
        .overlay { if saving || generating { ProgressView(saving ? "Salvataggio e verifica…" : "Sto preparando la tua scheda").padding().background(.regularMaterial, in: RoundedRectangle(cornerRadius: ClientRadius.compact)) } }
    }

    private func feedbackSection(_ value: ClientWorkoutCoachFeedback) -> some View {
        Section {
            Label(value.message, systemImage: "exclamationmark.triangle")
                .accessibilityFocused($feedbackFocused)
            if let destination = value.step {
                Button("Correggi: \(destination.title)") { result = nil; move(to: destination) }
                    .frame(minHeight: ClientControlSize.minimumTarget)
            }
        }
    }
    private func summaryRow(_ title: String, _ value: String?) -> some View { LabeledContent(title, value: value ?? "Da scegliere") }
    private func yesNo(_ title: String, selection: Binding<Bool?>) -> some View {
        Picker(title, selection: selection) {
            Text("Seleziona").tag(Bool?.none)
            Text("Sì").tag(Bool?.some(true))
            Text("No").tag(Bool?.some(false))
        }
    }
    private func membership<T: Hashable>(_ item: T, in set: Binding<Set<T>>) -> Binding<Bool> {
        Binding(get: { set.wrappedValue.contains(item) }, set: { if $0 { set.wrappedValue.insert(item) } else { set.wrappedValue.remove(item) } })
    }
    private func customMuscle(_ muscle: ClientMuscleRegion, day: Int) -> Binding<Bool> {
        Binding(get: { draft.customGroups.indices.contains(day) && draft.customGroups[day].contains(muscle) },
                set: { selected in
                    draft.resizeCustomSplit()
                    guard draft.customGroups.indices.contains(day) else { return }
                    if selected && !draft.customGroups[day].contains(muscle) { draft.customGroups[day].append(muscle) }
                    else if !selected { draft.customGroups[day].removeAll { $0 == muscle } }
                })
    }
    private var equipmentSummary: String? {
        guard let equipment = draft.equipment else { return nil }
        return equipment == .fullGym ? equipment.displayName
            : draft.inventory.map(\.title).sorted().joined(separator: ", ")
    }
    private func splitName(_ value: ClientWorkoutSplitPreference) -> String { value == .automatic ? "Decidi tu" : value.displayName }
    private func move(to destination: ClientWorkoutCoachStep) {
        focusedNumber = nil
        if reduceMotion { step = destination } else { withAnimation(.easeOut(duration: 0.18)) { step = destination } }
        feedback = nil
    }
    private func loadCatalog(forceReload: Bool = false) async {
        guard !loadingCatalog || catalog.isEmpty else { return }
        loadingCatalog = true
        let items = await session.personalExerciseCatalog(forceReload: forceReload)
        guard !Task.isCancelled else { return }
        // Keep raw conflicts for fail-closed admission; visible lists separately deduplicate safe rows.
        catalog = items
        loadingCatalog = false
    }
    private func generate() {
        guard !generating && !saving else { return }
        generating = true; feedback = nil
        Task { @MainActor in
            await Task.yield()
            defer { generating = false }
            do {
                guard case .active(let identity, _, _) = session.state, identity.authUserID == ownerID else {
                    throw ClientWorkoutGenerationEligibility.deniedUnauthenticated
                }
                let answers = try draft.completeAnswers(catalog: catalog)
                result = try session.generatePersonalWorkout(answers: answers, catalog: catalog, variation: variation)
                selectedSessionID = result?.plan.sessions.first?.id
                saveState = .localDraft
                ClientHaptics.success()
            } catch {
                result = nil
                feedback = ClientWorkoutCoachFeedback.generation(error)
                ClientHaptics.warning()
            }
        }
    }
    private func save(_ plan: ClientPersonalWorkoutPlan) async {
        guard !saving else { return }
        saveState = .saving; feedback = nil
        saveState = await session.saveWorkoutCoachPlan(plan, catalog: catalog, expectedOwnerID: ownerID)
        if case .failure(let message) = saveState {
            feedback = .init(message: message, step: nil)
            ClientHaptics.warning()
        } else { ClientHaptics.success() }
    }
}

private struct ClientCoachExclusionsSheet: View {
    let catalog: [ClientExerciseCatalogItem]
    @Binding var selected: Set<UUID>
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    private var matches: [ClientExerciseCatalogItem] {
        ClientWorkoutCoachDraft.visibleCatalogRows(catalog).filter { query.isEmpty || $0.name.localizedCaseInsensitiveContains(query) }
    }
    var body: some View {
        NavigationStack {
            List {
                if matches.isEmpty { Text("Nessun esercizio nel catalogo disponibile.") }
                ForEach(matches) { item in
                    Toggle(item.name, isOn: Binding(get: { selected.contains(item.id) },
                        set: { if $0 { selected.insert(item.id) } else { selected.remove(item.id) } }))
                        .frame(minHeight: ClientControlSize.minimumTarget)
                }
            }
            .searchable(text: $query, prompt: "Nome esercizio")
            .navigationTitle("Esercizi da evitare")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Fine") { dismiss() } } }
        }
    }
}
