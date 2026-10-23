import SwiftUI

struct ClientNutritionCreationChoiceView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selected = false
    let onSelect: (ClientPersonalNutritionSource) -> Void
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                Text("Come vuoi creare il tuo piano alimentare?")
                    .font(.system(.title2, design: .rounded, weight: .bold))
                Text("Pochi passi, alimenti del catalogo reale e una base sempre modificabile.")
                    .foregroundStyle(ClientClay.secondaryInk)
                Button { selected = true; onSelect(.guided) } label: {
                    Label("Crea per me", systemImage: "wand.and.stars").frame(maxWidth: .infinity)
                }.buttonStyle(ClayPrimaryButtonStyle())
                Button { selected = true; onSelect(.manual) } label: {
                    Label("Crea da solo", systemImage: "slider.horizontal.3").frame(maxWidth: .infinity)
                }.buttonStyle(ClaySecondaryButtonStyle())
                Text("La proposta automatica è una stima per adulti sani, non una prescrizione medica.")
                    .font(.caption).foregroundStyle(ClientClay.secondaryInk)
                Spacer()
            }.disabled(selected).padding(ClientClay.pagePadding).clientPage()
                .navigationTitle("Nuovo piano").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Chiudi") { dismiss() } } }
        }
    }
}

struct ClientNutritionCreationWizard: View {
    let mode: ClientPersonalNutritionSource
    let onSaved: () -> Void
    @EnvironmentObject private var session: ClientSessionStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var draft: ClientPersonalNutritionPlan
    @State private var answers: ClientNutritionCreationAnswers
    @State private var step: Int
    @State private var editingGenerated = false
    @State private var dayIndex = 0
    @State private var mealIndex = 0
    @State private var saving = false
    @State private var generating = false
    @State private var variation = 0
    @State private var message: String?
    @State private var showDiscard = false
    @State private var showSetupWarning = false
    @State private var showCopyWarning = false
    @State private var copyTargets: [Int] = []
    @State private var showFoodPicker = false
    @State private var showExclusions = false
    @State private var prefilled = false
    @State private var expectedOwnerID: UUID?
    @State private var ownerCaptured = false
    @State private var coachInputs: ClientNutritionCoachInputs?
    @State private var coachOriginal: ClientPersonalNutritionPlan?
    @State private var coachLayout: ClientNutritionEditingLayout?
    @State private var coachCatalog: [ClientFoodCatalogItem] = []
    @State private var saveState: ClientNutritionCoachSaveState = .localDraft
    @State private var coachLoading = false

    init(mode: ClientPersonalNutritionSource, plan: ClientPersonalNutritionPlan? = nil, onSaved: @escaping () -> Void) {
        self.mode = mode; self.onSaved = onSaved
        var answers = plan?.creationAnswers ?? ClientNutritionCreationAnswers()
        if let plan {
            answers.dayCount = plan.days.count == 1 ? 1 : 7
            answers.mealCount = min(6, max(3, plan.days.first?.meals.count ?? 4))
        }
        _answers = State(initialValue: answers)
        _draft = State(initialValue: plan ?? ClientNutritionDraft.newPlan(answers: answers))
        _step = State(initialValue: plan == nil ? 0 : 1)
        _editingGenerated = State(initialValue: plan != nil)
        _prefilled = State(initialValue: plan != nil)
        _coachOriginal = State(initialValue: plan?.generationMetadata == nil ? nil : plan)
        _coachLayout = State(initialValue: plan?.editProvenance?.nutritionLayout ?? plan.flatMap(ClientNutritionEditingLayout.generated))
        if plan?.generationMetadata != nil { _step = State(initialValue: 0) }
    }

    private var guided: Bool { mode == .guided && !editingGenerated }
    private var titles: [String] {
        isCoachPlan ? ["Il tuo piano"] : ["Organizziamo i pasti", "Dai un nome ai pasti", "Scegli gli alimenti", "Le tue quantità", "Il tuo piano"]
    }
    private var isCoachPlan: Bool { draft.generationMetadata != nil }
    private var coachReview: ClientEditedNutritionPlanValidator.Result? {
        guard let coachOriginal, case .active(let identity, _, _) = session.state else { return nil }
        return ClientNutritionCoachEditing.review(original: coachOriginal, draft: draft, layout: coachLayout, mode: identity.mode, catalog: coachCatalog)
    }
    private var canEdit: Bool {
        guard case .active(let identity, _, _) = session.state else { return false }
        return identity.authUserID == expectedOwnerID && ClientAccessPolicy.canManagePersonalNutritionPlans(in: identity.mode)
    }
    private var busy: Bool { saving || generating || coachLoading }
    private var canContinue: Bool {
        if isCoachPlan { return coachReview?.canSave == true }
        if step == 1 { return draft.days.allSatisfy { $0.meals.allSatisfy { !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty } } }
        if step >= 2 { return ClientNutritionDraft.validationMessage(draft) == nil }
        return true
    }

    var body: some View {
        Group {
            if !ownerCaptured {
                ProgressView("Preparazione della bozza…").padding()
            } else if guided {
                ClientNutritionCoachWizard(initialInputs: coachInputs, expectedOwnerID: expectedOwnerID) { plan, inputs in
                    draft = plan; answers = plan.creationAnswers ?? inputs.answers; coachInputs = inputs
                    coachOriginal = plan; coachLayout = plan.editProvenance?.nutritionLayout
                    editingGenerated = true; step = 0; dayIndex = 0; saveState = .localDraft
                }
            } else { editorBody }
        }
        .onAppear {
            guard !ownerCaptured else { return }; ownerCaptured = true
            if case .active(let identity, _, _) = session.state { expectedOwnerID = identity.authUserID }
        }
    }

    private var editorBody: some View {
        NavigationStack {
            Group {
            if isCoachPlan {
                Form {
                    if !canEdit { Section { Label(ClientAccessPolicy.trainerManagedPlansMessage, systemImage: "lock.fill") } }
                    else if coachLoading { Section { ProgressView("Caricamento catalogo verificato…") } }
                    else if !draft.days.indices.contains(dayIndex) { Section { Text("Il piano non contiene una giornata leggibile. Chiudilo e crea una nuova proposta, senza sovrascrivere lo storico.") } }
                    else {
                        ClientNutritionCoachEditorSections(draft: $draft, layout: $coachLayout, dayIndex: $dayIndex,
                            catalog: coachCatalog, expectedOwnerID: expectedOwnerID, issues: coachReview?.issues ?? [.metadata],
                            replacementPlan: coachReview?.canSave == true ? coachReview?.plan : nil) { updated in
                                draft = updated; coachOriginal = updated; coachLayout = updated.editProvenance?.nutritionLayout
                            }
                        if let energy = draft.generationMetadata?.energy { ClientNutritionTargetSummary(energy: energy) }
                        if coachInputs != nil {
                            Section("Un'altra proposta") {
                                Button("Rigenera con le stesse risposte") { variation = 0; generate() }
                                Button("Genera un'alternativa") { variation += 1; generate() }.disabled(variation >= 1000)
                                Button("Rivedi le risposte") { showCoachQuestionnaire() }
                                Text("Rigenerare sostituisce le modifiche della bozza, non i piani salvati. Le risposte e i vincoli restano gli stessi.").font(.subheadline).foregroundStyle(.secondary)
                            }
                        }
                    }
                    if let message { Section("Da verificare") { Text(message); Button("Ricarica catalogo") { Task { await loadCoachCatalog(force: true) } } } }
                    Section { saveFeedback }
                }.scrollContentBackground(.hidden).background(ClientClay.canvas)
            } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    if !canEdit {
                        Label(ClientAccessPolicy.trainerManagedPlansMessage, systemImage: "lock.fill").clayCard()
                    } else {
                        switch step {
                        case 0: setupStep
                        case 1: mealNamesStep
                        case 2: foodsStep
                        case 3: quantitiesStep
                        default: previewStep
                        }
                    }
                    if let message {
                        Label(message, systemImage: "exclamationmark.circle")
                            .font(.subheadline).foregroundStyle(ClientClay.accent).clayCard(padding: 14)
                    }
                }.padding(ClientClay.pagePadding)
            }
            .clientPage()
            }
            }
            .disabled(busy || saveState.isConfirmed)
            .navigationTitle(isCoachPlan ? "Il tuo piano alimentare" : "Crea da solo").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button(saveState.isConfirmed ? "Chiudi" : "Annulla") { if saveState.isConfirmed { onSaved() } else { showDiscard = true } }.disabled(busy) } }
            .safeAreaInset(edge: .bottom) { bottomBar }
            .interactiveDismissDisabled()
            .task { prefill(); if isCoachPlan { await loadCoachCatalog(force: false) } }
            .onChange(of: draft) { _, _ in if !saving && !saveState.isConfirmed { saveState = .localDraft } }
            .onChange(of: coachLayout) { _, _ in if !saving && !saveState.isConfirmed { saveState = .localDraft } }
            .confirmationDialog("Uscire dalla creazione?", isPresented: $showDiscard, titleVisibility: .visible) {
                Button("Scarta la bozza", role: .destructive) { dismiss() }
                Button("Continua a creare", role: .cancel) { }
            }
            .confirmationDialog("Ridurre giorni o pasti rimuoverà parte della bozza.", isPresented: $showSetupWarning, titleVisibility: .visible) {
                Button("Conferma riduzione", role: .destructive) { applySetup(); step = 1 }
                Button("Mantieni la bozza", role: .cancel) { answers.dayCount = draft.days.count == 1 ? 1 : 7; answers.mealCount = draft.days[dayIndex].meals.count }
            }
            .confirmationDialog("Sostituire i pasti dei giorni selezionati?", isPresented: $showCopyWarning, titleVisibility: .visible) {
                Button("Copia giorno", role: .destructive) {
                    let source = draft.days[dayIndex]
                    for index in copyTargets where draft.days.indices.contains(index) {
                        ClientNutritionDraft.copyDay(source, into: &draft.days[index])
                    }
                    copyTargets = []
                }
                Button("Annulla", role: .cancel) { copyTargets = [] }
            }
            .sheet(isPresented: $showFoodPicker) {
                ClientFoodPickerSheet { food in
                    draft.days[dayIndex].meals[mealIndex].foods.append(food)
                    showFoodPicker = false
                }
            }
            .sheet(isPresented: $showExclusions) { ClientNutritionExclusionPicker(selectedIDs: $answers.excludedFoodIDs) }
        }
    }

    @ViewBuilder private var saveFeedback: some View {
        switch saveState {
        case .localDraft: Label("Bozza locale · non ancora salvata", systemImage: "square.and.pencil")
        case .saving: ProgressView("Salvataggio e verifica del database…")
        case .confirmed(let demo): Label(demo ? "Salvato solo nella demo locale" : "Piano salvato e verificato nel database", systemImage: "checkmark.circle")
        case .failure(let reason): Label(reason, systemImage: "exclamationmark.circle")
        }
    }
    private func loadCoachCatalog(force: Bool) async {
        coachLoading = true; message = nil; defer { coachLoading = false }
        coachCatalog = await session.personalFoodCatalog(forceReload: force)
        do { _ = try session.nutritionCoachOwner(expectedOwnerID: expectedOwnerID) }
        catch { message = error.localizedDescription }
        if coachCatalog.isEmpty { message = ClientNutritionGenerationEligibility.insufficientFoodData.localizedDescription }
    }
    private func showCoachQuestionnaire() { editingGenerated = false; message = nil }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("PASSO \(step + 1) DI \(titles.count)").font(.caption.weight(.bold)).tracking(1).foregroundStyle(ClientClay.sage)
            ProgressView(value: Double(step + 1), total: Double(titles.count)).tint(ClientClay.sage)
            Text(titles[step]).font(.system(.title2, design: .rounded, weight: .bold))
            Text(guided ? "Una base orientativa, poi ogni scelta resta tua." : "Costruisci una giornata alla volta, senza un editor vuoto.")
                .font(.subheadline).foregroundStyle(ClientClay.secondaryInk)
        }.premiumCard(tint: ClientClay.sage)
    }

    private var setupStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Quanti pasti vuoi organizzare?").font(.headline)
            HStack { ForEach(3...6, id: \.self) { value in choice("\(value)", selected: answers.mealCount == value) { answers.mealCount = value } } }
            Text("Per un giorno o tutta la settimana?").font(.headline)
            HStack {
                choice("Un giorno", selected: answers.dayCount == 1) { answers.dayCount = 1 }
                choice("Settimana", selected: answers.dayCount == 7) { answers.dayCount = 7 }
            }
            Text("Potrai copiare un pasto o un giorno per partire più velocemente.").font(.caption).foregroundStyle(ClientClay.secondaryInk)
        }.clayCard()
    }

    private var daySelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(draft.days.indices, id: \.self) { index in
                    choice(String(draft.days[index].name.prefix(3)), selected: dayIndex == index) { dayIndex = index; mealIndex = 0 }
                }
            }
        }
    }

    private var copyDayMenu: some View {
        Menu {
            ForEach(draft.days.indices.filter { $0 != dayIndex }, id: \.self) { index in
                Button("In \(draft.days[index].name)") { copyTargets = [index]; showCopyWarning = true }
            }
            if draft.days.count > 1 {
                Button("In tutti gli altri giorni") { copyTargets = draft.days.indices.filter { $0 != dayIndex }; showCopyWarning = true }
            }
        } label: { Label("Copia questo giorno", systemImage: "doc.on.doc").frame(minHeight: 44) }
            .disabled(draft.days.count == 1)
    }

    private var mealNamesStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            daySelector
            if draft.days.count == 1 {
                Picker("Giorno", selection: $draft.days[0].weekday) {
                    ForEach(1...7, id: \.self) { weekday in Text(ClientNutritionDraft.weekdays[weekday - 1]).tag(weekday) }
                }.onChange(of: draft.days[0].weekday) { _, weekday in draft.days[0].name = ClientNutritionDraft.weekdays[weekday - 1] }
            }
            ForEach($draft.days[dayIndex].meals) { $meal in
                TextField("Nome del pasto", text: $meal.name).clientInputField()
            }
            Text("Puoi mantenere i nomi suggeriti oppure personalizzarli.").font(.caption).foregroundStyle(ClientClay.secondaryInk)
            copyDayMenu
        }.clayCard()
    }

    private var foodsStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            daySelector
            macroSummary
            ForEach(Array(draft.days[dayIndex].meals.enumerated()), id: \.element.id) { index, meal in
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text(meal.name).font(.headline); Spacer()
                        Menu {
                            Button("Copia pasto") { draft.days[dayIndex].meals.insert(ClientNutritionDraft.copy(meal), at: index + 1) }
                            if !session.personalContent.mealTemplates.isEmpty {
                                Menu("Usa pasto abituale") {
                                    ForEach(session.personalContent.mealTemplates) { template in
                                        Button(template.name) {
                                            var imported = ClientNutritionDraft.copy(template.meal)
                                            imported.id = meal.id
                                            draft.days[dayIndex].meals[index] = imported
                                        }
                                    }
                                }
                            }
                            Button("Salva come pasto abituale") {
                                session.savePersonalMealTemplate(ClientPersonalMealTemplate(id: UUID(), name: meal.name, meal: meal, updatedAt: Date()))
                            }.disabled(meal.foods.isEmpty)
                            Button("Elimina pasto", role: .destructive) {
                                draft.days[dayIndex].meals.remove(at: index)
                                mealIndex = 0
                            }
                        } label: { Image(systemName: "ellipsis.circle").frame(width: 44, height: 44) }
                    }
                    ForEach(meal.foods) { food in
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(food.name).font(.subheadline)
                                Text(food.quantityDescription).font(.caption).foregroundStyle(ClientClay.secondaryInk)
                            }
                            Spacer()
                            Button(role: .destructive) { draft.days[dayIndex].meals[index].foods.removeAll { $0.id == food.id } } label: {
                                Image(systemName: "minus.circle").frame(width: 44, height: 44)
                            }.accessibilityLabel("Rimuovi \(food.name)")
                        }
                    }
                    Button { mealIndex = index; showFoodPicker = true } label: { Label("Aggiungi alimento", systemImage: "plus").frame(maxWidth: .infinity) }
                        .buttonStyle(ClaySecondaryButtonStyle())
                }.clayCard(padding: 14)
            }
            Button("Aggiungi pasto", systemImage: "plus") { draft.days[dayIndex].meals.append(ClientPersonalMeal(id: UUID(), name: "Nuovo pasto", foods: [])) }
                .frame(minHeight: 44)
            copyDayMenu
            Text("Completa un giorno e copialo negli altri; potrai poi modificare ciascuno.").font(.caption).foregroundStyle(ClientClay.secondaryInk)
        }
    }

    private var quantitiesStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            daySelector
            macroSummary
            ForEach($draft.days[dayIndex].meals) { $meal in
                VStack(alignment: .leading, spacing: 12) {
                    Text(meal.name).font(.headline)
                    ForEach($meal.foods) { $food in
                        VStack(alignment: .leading, spacing: 5) {
                            Text(food.name).font(.subheadline.weight(.semibold))
                            if let pieceWeight = food.gramsPerPiece, pieceWeight > 0 {
                                Stepper(food.quantityDescription, value: Binding(
                                    get: { max(1, Int((food.quantityGrams / pieceWeight).rounded())) },
                                    set: { food.quantityGrams = Double($0) * pieceWeight }
                                ), in: 1...20)
                            } else {
                                HStack { TextField("Grammi", value: $food.quantityGrams, format: .number).keyboardType(.decimalPad).clientInputField(); Text("g") }
                            }
                            Text("\(food.calories.formatted(.number.precision(.fractionLength(0)))) kcal")
                                .font(.caption).foregroundStyle(ClientClay.secondaryInk)
                        }
                    }
                }.clayCard(padding: 14)
            }
            copyDayMenu
        }
    }

    private var macroSummary: some View {
        let meals = draft.days[dayIndex].meals
        let kcal = meals.reduce(0) { $0 + $1.calories }
        let p = meals.reduce(0) { $0 + $1.protein }
        let c = meals.reduce(0) { $0 + $1.carbs }
        let f = meals.reduce(0) { $0 + $1.fat }
        let complete = meals.flatMap(\.foods).allSatisfy { $0.proteinPer100g != nil && $0.carbsPer100g != nil && $0.fatPer100g != nil }
        return VStack(alignment: .leading, spacing: 8) {
            Text(draft.target == nil ? "TOTALE ATTUALE" : "RIEPILOGO · STIMA INDICATIVA").font(.caption.weight(.bold)).foregroundStyle(ClientClay.sage)
            Text("\(kcal.formatted(.number.precision(.fractionLength(0))))\(draft.target.map { " / \($0.calories.formatted(.number.precision(.fractionLength(0))))" } ?? "") kcal").font(.title2.weight(.bold))
            Text("P \(p.formatted(.number.precision(.fractionLength(0)))) g · C \(c.formatted(.number.precision(.fractionLength(0)))) g · G \(f.formatted(.number.precision(.fractionLength(0)))) g")
                .font(.subheadline.weight(.semibold))
            if let target = draft.target {
                Text("Riferimento: P \(target.protein.formatted(.number.precision(.fractionLength(0)))) · C \(target.carbs.formatted(.number.precision(.fractionLength(0)))) · G \(target.fat.formatted(.number.precision(.fractionLength(0)))) g")
                    .font(.caption).foregroundStyle(ClientClay.secondaryInk)
            }
            if !complete { Label("Macro parziali: alcuni alimenti non hanno tutti i dati.", systemImage: "info.circle").font(.caption) }
        }.clayCard(padding: 14)
    }

    private var previewStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            TextField("Nome piano", text: $draft.title).clientInputField()
            daySelector
            macroSummary
            ForEach(draft.days[dayIndex].meals) { meal in
                VStack(alignment: .leading, spacing: 8) {
                    Text(meal.name).font(.headline)
                    ForEach(meal.foods) { food in
                        HStack(alignment: .top) { Text(food.name).font(.subheadline); Spacer(); Text(food.quantityDescription).font(.subheadline.weight(.semibold)) }
                    }
                }.clayCard(padding: 14)
            }
            Button("Modifica", systemImage: "pencil") { editingGenerated = true; step = 2 }.buttonStyle(ClaySecondaryButtonStyle())
            if guided {
                Button("Rigenera", systemImage: "arrow.clockwise") { variation += 1; generate() }.frame(minHeight: 44)
                Text("Quantità riferite agli alimenti del catalogo, non una dieta terapeutica. Verifica ingredienti ed etichette; la proposta non certifica assenza di allergeni.")
                    .font(.caption).foregroundStyle(ClientClay.secondaryInk)
            }
        }
    }


    private var bottomBar: some View {
        VStack(alignment: .leading, spacing: 8) {
        if !isCoachPlan { saveFeedback }
        if saveState.isConfirmed {
            Button("Fine") { onSaved() }.buttonStyle(ClayPrimaryButtonStyle()).frame(minHeight: 44)
        } else {
        HStack(spacing: 12) {
            if step > 0 { Button("Indietro") { step -= 1; message = nil }.buttonStyle(ClaySecondaryButtonStyle()).disabled(busy) }
            Button { advance() } label: {
                HStack {
                    if busy { ProgressView().tint(ClientClay.color(.textOnAccent)) }
                    Text(saving ? "Verifica salvataggio…" : generating ? "Creazione proposta…" : step == titles.count - 1 ? "Salva piano" : "Continua")
                }.frame(maxWidth: .infinity)
            }.buttonStyle(ClayPrimaryButtonStyle()).disabled(!canEdit || !canContinue || busy)
        }
        }
        }.padding(.horizontal, ClientClay.pagePadding).padding(.vertical, 12).background(ClientClay.canvas)
    }

    private func choice(_ text: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button { ClientHaptics.selection(); action() } label: {
            Text(text).font(.subheadline.weight(.semibold)).frame(maxWidth: .infinity, minHeight: 44)
                .padding(.horizontal, 12)
                .background(selected ? ClientClay.sage.opacity(0.15) : ClientClay.surfaceElevated, in: RoundedRectangle(cornerRadius: 14))
                .overlay { RoundedRectangle(cornerRadius: 14).stroke(selected ? ClientClay.sage : ClientClay.border) }
                .foregroundStyle(ClientClay.ink)
        }.buttonStyle(.plain).accessibilityAddTraits(selected ? [.isSelected] : [])
    }

    private func prefill() {
        if isCoachPlan { prefilled = true; return }
        guard !prefilled else { return }; prefilled = true
        if let previous = session.personalContent.nutritionPlans.compactMap(\.creationAnswers).first { answers = previous }
        // A NEW manual draft must not inherit a prior coach contract or medical consent.
        answers.coachProfile = nil
        if case .active(let identity, let snapshot, _) = session.state {
            answers.biologicalSex = identity.biologicalSex ?? answers.biologicalSex
            let latestWeight = snapshot.progress.sorted { $0.recordedAt > $1.recordedAt }.compactMap(\.weightKg).first
            answers.weightKg = latestWeight ?? answers.weightKg
        }
        // Each new proposal requires fresh safety confirmation; never inherit consent.
        answers.healthyAdultConfirmed = false
    }

    private func applySetup() {
        let selectedDayID = draft.days[dayIndex].id
        ClientNutritionDraft.resize(&draft, answers: answers, selectedDayID: selectedDayID)
        dayIndex = min(dayIndex, draft.days.count - 1); mealIndex = 0
    }

    private func advance() {
        guard canEdit, !busy else { return }; message = nil
        if step == titles.count - 1 { save(); return }
        if !guided && step == 0 {
            let hasFoods = draft.days.flatMap(\.meals).contains { !$0.foods.isEmpty }
            if hasFoods && (draft.days.count > answers.dayCount || draft.days.contains { $0.meals.count > answers.mealCount }) {
                showSetupWarning = true; return
            }
            applySetup()
        }
        ClientHaptics.selection()
        withAnimation(reduceMotion ? nil : .snappy) { step += 1 }
    }

    private func generate() {
        guard let coachInputs, canEdit else { return }
        generating = true; message = nil
        Task { @MainActor in
            let catalog = await session.personalFoodCatalog()
            guard canEdit else { generating = false; message = ClientAccessPolicy.trainerManagedPlansMessage; return }
            do {
                draft = try await session.generateNutritionCoach(inputs: coachInputs, catalog: catalog, variation: variation, expectedOwnerID: expectedOwnerID)
                coachOriginal = draft; coachLayout = draft.editProvenance?.nutritionLayout; coachCatalog = catalog
                dayIndex = 0; mealIndex = 0; step = 0; saveState = .localDraft
            } catch { message = error.localizedDescription }
            generating = false
        }
    }

    private func save() {
        guard canEdit, !saving else { return }
        if let error = ClientNutritionDraft.validationMessage(draft) { message = error; return }
        if isCoachPlan {
            guard let result = coachReview, result.canSave else { message = "Correggi la bozza prima di salvare."; return }
            draft = result.plan
        } else { draft.creationAnswers = answers }
        draft.updatedAt = Date(); saving = true; saveState = .saving
        Task { @MainActor in
            saveState = await session.saveNutritionCoachPlan(draft, catalog: coachCatalog, expectedOwnerID: expectedOwnerID)
            saving = false
            if case .failure(let reason) = saveState { message = reason }
        }
    }
}

private struct ClientNutritionExclusionPicker: View {
    @Binding var selectedIDs: [UUID]
    @EnvironmentObject private var session: ClientSessionStore
    @Environment(\.dismiss) private var dismiss
    @State private var catalog: [ClientFoodCatalogItem] = []
    @State private var query = ""
    var body: some View {
        NavigationStack {
            List(catalog.filter { query.isEmpty || $0.name.localizedStandardContains(query) }) { food in
                Button {
                    if selectedIDs.contains(food.id) { selectedIDs.removeAll { $0 == food.id } } else { selectedIDs.append(food.id) }
                } label: {
                    HStack { Text(food.name); Spacer(); Image(systemName: selectedIDs.contains(food.id) ? "checkmark.circle.fill" : "circle") }.frame(minHeight: 44)
                }
            }.searchable(text: $query, prompt: "Cerca nel catalogo")
                .task { catalog = await session.personalFoodCatalog() }
                .navigationTitle("Escludi alimenti")
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Fine") { dismiss() } } }
        }
    }
}
