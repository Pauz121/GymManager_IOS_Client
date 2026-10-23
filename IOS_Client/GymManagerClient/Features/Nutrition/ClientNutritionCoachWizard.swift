import SwiftUI

/// Questionnaire only; generated plans enter the existing Nutrition creation/editor flow.
struct ClientNutritionCoachWizard: View {
    let initialInputs: ClientNutritionCoachInputs?
    let expectedOwnerID: UUID?
    let onGenerated: (ClientPersonalNutritionPlan, ClientNutritionCoachInputs) -> Void
    @EnvironmentObject private var session: ClientSessionStore
    @Environment(\.dismiss) private var dismiss
    @State private var inputs = ClientNutritionCoachInputs()
    @State private var step = ClientNutritionCoachStep.profile
    @State private var started = false
    @State private var generating = false
    @State private var message: String?
    @State private var correction: ClientNutritionCoachStep?
    @State private var showExclusions = false
    @State private var discard = false
    @FocusState private var focusedField: Field?
    private enum Field: Hashable { case age, height, weight }
    private var mode: ClientConnectionMode? {
        guard case .active(let identity, _, _) = session.state, identity.authUserID == expectedOwnerID else { return nil }
        return identity.mode
    }
    private var allowedOwner: Bool { (try? session.nutritionCoachOwner(expectedOwnerID: expectedOwnerID)) != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Passo \(step.rawValue + 1) di \(ClientNutritionCoachStep.allCases.count)").font(.subheadline).foregroundStyle(.secondary)
                    ProgressView(value: Double(step.rawValue + 1), total: Double(ClientNutritionCoachStep.allCases.count))
                        .tint(ClientClay.sage).accessibilityLabel("Avanzamento del questionario")
                }
                if !allowedOwner {
                    Section { Label("Account cambiato o piano gestito dal Trainer. Chiudi la bozza per continuare.", systemImage: "lock.fill") }
                } else {
                    stepContent
                }
                if let message {
                    Section("Da verificare") {
                        Label(message, systemImage: "exclamationmark.circle").accessibilityIdentifier("nutrition.coach.error")
                        if let correction { Button("Correggi: \(correction.title)") { step = correction; focusedField = correction == .profile ? .age : nil } }
                        if correction == nil && !generating { Button("Ricarica il catalogo e riprova") { generate(forceReload: true) }.disabled(step != .review || !allowedOwner) }
                    }
                }
            }
            .scrollContentBackground(.hidden).background(ClientClay.canvas)
            .navigationTitle(step.title).navigationBarTitleDisplayMode(.inline)
            .tint(ClientClay.sage)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Annulla") { discard = true }.disabled(generating) }
                ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Fine") { focusedField = nil } }
            }
            .safeAreaInset(edge: .bottom) { controls }
            .disabled(generating)
            .interactiveDismissDisabled()
            .confirmationDialog("Uscire dal questionario?", isPresented: $discard, titleVisibility: .visible) {
                Button("Scarta le risposte", role: .destructive) { dismiss() }; Button("Continua", role: .cancel) { }
            }
            .sheet(isPresented: $showExclusions) { ClientNutritionCoachExclusions(selected: $inputs.excludedFoodIDs) }
            .onAppear(perform: start)
            .onChange(of: expectedOwnerID) { _, _ in reuseProfile() }
        }
    }

    @ViewBuilder private var stepContent: some View {
        switch step {
        case .profile:
            Section {
                Text("Questi dati servono per stimare il fabbisogno energetico, non per misurarlo.").foregroundStyle(.secondary)
                TextField("Età in anni", value: $inputs.age, format: .number).keyboardType(.numberPad).focused($focusedField, equals: .age)
                if inputs.reusedSex {
                    LabeledContent("Sesso biologico dal profilo", value: inputs.biologicalSex?.title ?? "Da confermare")
                    Button("Correggi questo dato") { inputs.reusedSex = false }
                } else {
                    Picker("Sesso biologico per la formula", selection: $inputs.biologicalSex) {
                        Text("Seleziona").tag(ClientBiologicalSex?.none)
                        ForEach(ClientBiologicalSex.allCases) { Text($0.title).tag(ClientBiologicalSex?.some($0)) }
                    }
                }
                TextField("Altezza in centimetri", value: $inputs.heightCm, format: .number).keyboardType(.decimalPad).focused($focusedField, equals: .height)
                if inputs.reusedWeight {
                    LabeledContent("Peso registrato oggi", value: "\(inputs.weightKg?.formatted() ?? "") kg")
                    Button("Correggi il peso") { inputs.reusedWeight = false }
                } else {
                    TextField("Peso in chilogrammi", value: $inputs.weightKg, format: .number).keyboardType(.decimalPad).focused($focusedField, equals: .weight)
                }
            } footer: { Text("Riutilizziamo i dati affidabili disponibili; se manca una misura attuale, chiediamo di completarla. Non deduciamo età, altezza o attività da vecchie risposte.") }
        case .activity:
            Section("Oltre all'allenamento, la tua giornata è…") {
                option("Prevalentemente seduta", selected: inputs.dailyActivity == .seated) { inputs.dailyActivity = .seated }
                option("Mista: seduto e in movimento", selected: inputs.dailyActivity == .mixed) { inputs.dailyActivity = .mixed }
                option("Fisicamente attiva", selected: inputs.dailyActivity == .physical) { inputs.dailyActivity = .physical }
                Text("Considera lavoro, spostamenti e attività abituali. La palestra è nel prossimo passo.").font(.subheadline).foregroundStyle(.secondary)
            }
        case .training:
            Section("Quanti giorni ti alleni di solito ogni settimana?") {
                Picker("Giorni di allenamento", selection: $inputs.exerciseDays) {
                    Text("Seleziona").tag(Int?.none)
                    ForEach(0...7, id: \.self) { Text($0 == 0 ? "Non mi alleno" : "\($0) giorni").tag(Int?.some($0)) }
                }
                Text("Una scheda programmata non prova quanti allenamenti svolgi realmente. Conferma la tua frequenza abituale; non stimiamo calorie per singola sessione.").font(.subheadline).foregroundStyle(.secondary)
            }
        case .goal:
            Section("Cosa vuoi ottenere?") {
                option("Perdere peso · deficit moderato", selected: inputs.phase == .cut) { inputs.phase = .cut }
                option("Mantenere · un riferimento equilibrato", selected: inputs.phase == .maintenance) { inputs.phase = .maintenance }
                option("Aumentare massa · incremento moderato", selected: inputs.phase == .bulk) { inputs.phase = .bulk }
                Text("È una base orientativa per adulti sani, non una dieta terapeutica o una promessa di risultato.").font(.subheadline).foregroundStyle(.secondary)
            }
        case .preferences:
            Section("Il tuo stile alimentare") {
                ForEach(ClientNutritionDietPattern.allCases, id: \.self) { pattern in
                    option(pattern.title, selected: inputs.pattern == pattern) { inputs.pattern = pattern }
                }
                Text("Useremo solo alimenti compatibili con dati verificati. Se non sono sufficienti, la proposta non verrà generata. Puoi escludere gli alimenti non graditi nel prossimo passo.").font(.subheadline).foregroundStyle(.secondary)
            }
        case .safety:
            Section("Prima di generare") {
                yesNo("Confermi di usare il programma per fitness generale da adulto sano?", value: $inputs.health.healthyAdultAcknowledged)
                yesNo("Sei in gravidanza o allattamento?", value: $inputs.health.pregnantOrBreastfeeding)
                yesNo("Hai una storia o un rischio di disturbi alimentari?", value: $inputs.health.eatingDisorderRisk)
                yesNo("Hai condizioni che richiedono nutrizione clinica o indicazioni di un professionista?", value: $inputs.health.clinicalNutritionRequired)
                Text("Per esigenze cliniche il programma si ferma e rimanda a un professionista. Non formuliamo diagnosi.").font(.subheadline).foregroundStyle(.secondary)
            }
            Section("Allergie · vincoli obbligatori") {
                ForEach(ClientNutritionAllergen.allCases, id: \.self) { value in
                    Toggle(value.title, isOn: membership(value, in: $inputs.allergies))
                }
                Text("Anche le tracce note vengono escluse. Controlla sempre ingredienti ed etichette: il piano non certifica l'assenza di allergeni.").font(.subheadline).foregroundStyle(.secondary)
            }
            Section("Intolleranze ed esclusioni") {
                ForEach(ClientNutritionIntolerance.allCases, id: \.self) { value in Toggle(value.title, isOn: membership(value, in: $inputs.intolerances)) }
                Button("Alimenti esclusi: \(inputs.excludedFoodIDs.count)") { showExclusions = true }.frame(minHeight: 44)
                Toggle("Ho controllato allergie, intolleranze ed esclusioni, anche se non ne ho", isOn: $inputs.dietarySafetyReviewed)
            }
        case .meals:
            Section("Distribuzione, non metabolismo") {
                Picker("Pasti al giorno", selection: $inputs.mealCount) {
                    Text("Seleziona").tag(Int?.none); ForEach(3...6, id: \.self) { Text("\($0) pasti").tag(Int?.some($0)) }
                }
                Picker("Orizzonte del piano", selection: $inputs.dayCount) {
                    Text("Seleziona").tag(Int?.none); Text("Un giorno").tag(Int?.some(1)); Text("Settimana").tag(Int?.some(7))
                }
                if inputs.dayCount == 1 {
                    Picker("Giorno", selection: $inputs.referenceWeekday) {
                        ForEach(1...7, id: \.self) { Text(ClientNutritionDraft.weekdays[$0 - 1]).tag($0) }
                    }
                }
                Text("Scegli la distribuzione più comoda per la tua giornata.").foregroundStyle(.secondary)
            }
        case .review:
            Section("Le tue scelte") {
                LabeledContent("Età", value: inputs.age.map { "\($0) anni" } ?? "Manca")
                LabeledContent("Sesso biologico", value: inputs.biologicalSex?.title ?? "Manca")
                LabeledContent("Altezza", value: inputs.heightCm.map { "\($0.formatted()) cm" } ?? "Manca")
                LabeledContent("Peso", value: inputs.weightKg.map { "\($0.formatted()) kg" } ?? "Manca")
                LabeledContent("Attività quotidiana", value: activityTitle)
                LabeledContent("Allenamento", value: "\(inputs.exerciseDays ?? 0) giorni/settimana")
                LabeledContent("Obiettivo", value: goalTitle)
                LabeledContent("Stile alimentare", value: inputs.pattern?.title ?? "Manca")
                LabeledContent("Organizzazione", value: "\(inputs.mealCount ?? 0) pasti · \(inputs.dayCount ?? 0) giorni")
                LabeledContent("Allergie", value: inputs.allergies.map(\.title).sorted().joined(separator: ", ").nilIfEmpty ?? "Nessuna indicata")
                LabeledContent("Intolleranze", value: inputs.intolerances.map(\.title).sorted().joined(separator: ", ").nilIfEmpty ?? "Nessuna indicata")
                LabeledContent("Alimenti esclusi", value: "\(inputs.excludedFoodIDs.count)")
            }
            if let energy = try? inputs.target(mode: mode) { ClientNutritionTargetSummary(energy: energy) }
            else { Section { Text("La proposta automatica non è ancora disponibile per queste risposte. Correggi i dati senza perdere quanto inserito.") } }
        }
    }
    private var activityTitle: String {
        switch inputs.dailyActivity { case .seated: "Prevalentemente seduta"; case .mixed: "Mista"; case .physical: "Fisicamente attiva"; case nil: "Manca" }
    }
    private var goalTitle: String {
        switch inputs.phase { case .cut: "Perdere peso"; case .maintenance: "Mantenere"; case .bulk: "Aumentare massa"; case nil: "Manca" }
    }
    private var controls: some View {
        HStack(spacing: 12) {
            if step != .profile { Button("Indietro") { step = ClientNutritionCoachStep(rawValue: step.rawValue - 1) ?? .profile; message = nil }.frame(minHeight: 44) }
            Button {
                focusedField = nil; message = nil
                if step == .review { generate(forceReload: false) }
                else { step = ClientNutritionCoachStep(rawValue: step.rawValue + 1) ?? .review; ClientHaptics.selection() }
            } label: {
                HStack { if generating { ProgressView() }; Text(generating ? "Sto preparando il tuo piano…" : step == .review ? "Crea piano" : "Continua") }.frame(maxWidth: .infinity, minHeight: 44)
            }.buttonStyle(ClayPrimaryButtonStyle()).disabled(!allowedOwner || generating || !inputs.canAdvance(from: step))
        }.padding(16).background(ClientClay.canvas)
    }
    private func option(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button { action(); ClientHaptics.selection() } label: {
            HStack { Text(title).foregroundStyle(.primary); Spacer(); Image(systemName: selected ? "checkmark.circle.fill" : "circle").accessibilityHidden(true) }.frame(minHeight: 44)
        }.accessibilityAddTraits(selected ? [.isSelected] : [])
    }
    private func yesNo(_ title: String, value: Binding<Bool?>) -> some View {
        Picker(title, selection: value) { Text("Seleziona").tag(Bool?.none); Text("No").tag(Bool?.some(false)); Text("Sì").tag(Bool?.some(true)) }
    }
    private func membership<T: Hashable>(_ value: T, in set: Binding<Set<T>>) -> Binding<Bool> {
        Binding(get: { set.wrappedValue.contains(value) }, set: { enabled in if enabled { set.wrappedValue.insert(value) } else { set.wrappedValue.remove(value) } })
    }
    private func start() {
        guard !started else { return }; started = true
        if let initialInputs { inputs = initialInputs }
        reuseProfile()
    }
    private func reuseProfile() {
        if case .active(let identity, let snapshot, _) = session.state, identity.authUserID == expectedOwnerID {
            inputs.reuse(biologicalSex: identity.biologicalSex)
            if let progress = snapshot.progress.filter({ $0.weightKg != nil }).max(by: { $0.recordedAt < $1.recordedAt }) {
                inputs.reuse(weight: progress.weightKg, recordedAt: progress.recordedAt)
            }
        }
    }
    private func generate(forceReload: Bool) {
        guard !generating, allowedOwner else { return }
        do { _ = try inputs.target(mode: mode) }
        catch { show(error); return }
        generating = true
        Task { @MainActor in
            let catalog = await session.personalFoodCatalog(forceReload: forceReload)
            defer { generating = false }
            guard !Task.isCancelled else { return }
            do {
                let plan = try await session.generateNutritionCoach(inputs: inputs, catalog: catalog, variation: 0, expectedOwnerID: expectedOwnerID)
                onGenerated(plan, inputs)
            } catch { show(error) }
        }
    }
    private func show(_ error: Error) {
        message = error.localizedDescription
        correction = (error as? ClientNutritionGenerationEligibility).flatMap { ClientNutritionCoachFeedback.correction($0, inputs: inputs) }
    }
}

struct ClientNutritionTargetSummary: View {
    let energy: ClientNutritionEnergyCalculation
    var body: some View {
        Section("Target giornaliero · stima") {
            LabeledContent("Energia", value: "\(energy.target.calories.formatted(.number.precision(.fractionLength(0)))) kcal")
            Text("Proteine \(energy.target.protein.formatted(.number.precision(.fractionLength(0)))) g · Carboidrati \(energy.target.carbs.formatted(.number.precision(.fractionLength(0)))) g · Grassi \(energy.target.fat.formatted(.number.precision(.fractionLength(0)))) g").monospacedDigit()
            DisclosureGroup("Perché queste calorie?") {
                LabeledContent("Metabolismo a riposo stimato", value: "\(energy.estimatedRMR.formatted(.number.precision(.fractionLength(0)))) kcal")
                LabeledContent("Mantenimento stimato", value: "\(energy.estimatedMaintenance.formatted(.number.precision(.fractionLength(0)))) kcal")
                LabeledContent("Obiettivo", value: energy.goal == .cut ? "Perdere peso" : energy.goal == .bulk ? "Aumentare massa" : "Mantenere")
                LabeledContent("Adattamento del target", value: ClientNutritionCoachFeedback.signed(energy.goalAdjustment, unit: "kcal"))
                Text("La stima usa i tuoi dati, l'attività quotidiana e gli allenamenti. L'obiettivo applica una modifica moderata; non è una misura del tuo consumo reale.")
            }
            DisclosureGroup("Perché questi macro?") {
                Text("Proteine: in base a peso, allenamento e obiettivo. Grassi: quota prevista dal motore. Carboidrati: energia rimanente. Sono riferimenti orientativi, non una prescrizione medica.")
            }
        }
    }
}

private struct ClientNutritionCoachExclusions: View {
    @Binding var selected: Set<UUID>
    @EnvironmentObject private var session: ClientSessionStore
    @Environment(\.dismiss) private var dismiss
    @State private var catalog: [ClientFoodCatalogItem] = []
    @State private var query = ""
    @State private var loading = true
    var body: some View {
        NavigationStack {
            List {
                if loading { ProgressView("Caricamento catalogo…") }
                else if catalog.isEmpty { Text("Catalogo non disponibile. Nessuna esclusione è stata rimossa."); Button("Riprova") { Task { await load(force: true) } } }
                ForEach(catalog.filter { query.isEmpty || $0.name.localizedStandardContains(query) }) { food in
                    Toggle(food.name, isOn: Binding(get: { selected.contains(food.id) }, set: { if $0 { selected.insert(food.id) } else { selected.remove(food.id) } }))
                }
            }.searchable(text: $query, prompt: "Cerca alimento da escludere").navigationTitle("Alimenti esclusi")
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Fine") { dismiss() } } }
                .task { await load(force: false) }
        }
    }
    private func load(force: Bool) async { loading = true; catalog = await session.personalFoodCatalog(forceReload: force); loading = false }
}

private extension String { var nilIfEmpty: String? { isEmpty ? nil : self } }
