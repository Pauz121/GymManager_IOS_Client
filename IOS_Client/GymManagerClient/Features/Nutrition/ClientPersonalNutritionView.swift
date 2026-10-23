import SwiftUI

struct ClientPersonalNutritionLibraryView: View {
    let allowsEditing: Bool
    @EnvironmentObject private var session: ClientSessionStore
    @State private var modal: ClientNutritionCreationModal?
    @State private var pendingModal: ClientNutritionCreationModal?
    @State private var selectedWeekday = ClientDateLogic.weekday(for: Date())

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ClientSectionHeader(
                title: allowsEditing ? "Piano personale" : "Piani personali precedenti",
                detail: allowsEditing ? "Creato da te" : "Storico · sola lettura",
                symbol: "person.crop.circle.badge.checkmark"
            )

            if !allowsEditing {
                Label(ClientAccessPolicy.trainerManagedPlansMessage, systemImage: "person.crop.circle.badge.checkmark")
                    .font(.subheadline)
                    .foregroundStyle(ClientClay.secondaryInk)
                    .clayCard(padding: 14)
            }

            if allowsEditing {
                if let plan = session.personalContent.activeNutrition {
                    planHeader(plan)
                    daySelector(plan)
                    if let day = plan.days.first(where: { $0.weekday == selectedWeekday }) ?? plan.days.first {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(day.name).font(.title2.weight(.bold)).foregroundStyle(ClientClay.ink)
                            Text("\(Int(day.meals.reduce(0) { $0 + $1.calories }.rounded())) kcal · P \(Int(day.meals.reduce(0) { $0 + $1.protein }.rounded())) g · C \(Int(day.meals.reduce(0) { $0 + $1.carbs }.rounded())) g · G \(Int(day.meals.reduce(0) { $0 + $1.fat }.rounded())) g")
                                .font(.caption).foregroundStyle(ClientClay.secondaryInk)
                        }
                        ForEach(day.meals) { meal in personalMealCard(meal, plan: plan) }
                    }
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Nessun piano personale", systemImage: "leaf.circle").font(.headline).foregroundStyle(ClientClay.ink)
                        Text("Crea i tuoi giorni, pasti e alimenti usando il database nutrizionale reale.").font(.subheadline).foregroundStyle(ClientClay.secondaryInk)
                        Button { modal = .creation } label: { Label("Crea piano", systemImage: "plus.circle.fill").frame(maxWidth: .infinity) }
                            .buttonStyle(ClayPrimaryButtonStyle())
                    }
                    .clayCard()
                }
            } else if session.personalContent.nutritionPlans.isEmpty {
                Text("Nessun piano alimentare personale precedente.")
                    .font(.subheadline)
                    .foregroundStyle(ClientClay.secondaryInk)
                    .clayCard(padding: 14)
            } else {
                ForEach(session.personalContent.nutritionPlans) { plan in
                    historicalPlanCard(plan)
                }
            }
        }
        .sheet(item: $modal, onDismiss: presentPendingModal) { destination in
            switch destination {
            case .creation:
                ClientNutritionCreationChoiceView { choice in
                    pendingModal = choice == .guided ? .guided : .manual
                    modal = nil
                }
            case .manual:
                ClientNutritionCreationWizard(mode: .manual, onSaved: { modal = nil })
            case .guided:
                ClientNutritionCreationWizard(mode: .guided, onSaved: { modal = nil })
            case .editor(let plan):
                ClientNutritionCreationWizard(mode: plan.source ?? .manual, plan: plan, onSaved: { modal = nil })
            }
        }
        .onDisappear { pendingModal = nil }
    }

    private func presentPendingModal() {
        let destination = pendingModal
        pendingModal = nil
        guard allowsEditing, case .active(let identity, _, _) = session.state,
              ClientAccessPolicy.canManagePersonalNutritionPlans(in: identity.mode) else { return }
        modal = destination
    }

    private func historicalPlanCard(_ plan: ClientPersonalNutritionPlan) -> some View {
        let mealCount = plan.days.reduce(0) { $0 + $1.meals.count }
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "archivebox.fill")
                    .font(.title3)
                    .foregroundStyle(ClientClay.secondaryInk)
                VStack(alignment: .leading, spacing: 4) {
                    ClientBadge(text: "PERSONALE · STORICO", tint: ClientClay.secondaryInk, symbol: "lock.fill")
                    Text(plan.title).font(.headline).foregroundStyle(ClientClay.ink)
                    Text("\(plan.days.count) giorni · \(mealCount) pasti · sola lettura")
                        .font(.caption).foregroundStyle(ClientClay.secondaryInk)
                }
                Spacer()
            }
            ForEach(plan.days) { day in
                HStack {
                    Text(day.name).font(.subheadline.weight(.semibold)).foregroundStyle(ClientClay.ink)
                    Spacer()
                    Text("\(day.meals.count) pasti")
                        .font(.caption).foregroundStyle(ClientClay.secondaryInk)
                }
                .accessibilityElement(children: .combine)
            }
        }
        .clayCard(padding: 14)
    }

    private func planHeader(_ plan: ClientPersonalNutritionPlan) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "leaf.fill").font(.title2).foregroundStyle(ClientClay.sage)
            VStack(alignment: .leading, spacing: 3) {
                ClientBadge(text: "PERSONALE · MODIFICABILE", tint: ClientClay.sage, symbol: "person.fill")
                Text(plan.title).font(.headline).foregroundStyle(ClientClay.ink)
            }
            Spacer()
            Menu {
                Button("Modifica", systemImage: "pencil") { modal = .editor(plan) }
                Button("Crea un nuovo piano", systemImage: "plus") { modal = .creation }
                Button("Duplica", systemImage: "plus.square.on.square") {
                    var copy = plan; copy.id = UUID(); copy.title += " · Copia"; copy.status = .draft; copy.updatedAt = Date(); session.savePersonalNutritionPlan(copy)
                }
                Button("Archivia", systemImage: "archivebox") { var updated = plan; updated.status = .archived; updated.updatedAt = Date(); session.savePersonalNutritionPlan(updated) }
                Button("Elimina", systemImage: "trash", role: .destructive) { session.deletePersonalNutritionPlan(plan.id) }
            } label: { Image(systemName: "ellipsis.circle").frame(width: 44, height: 44) }
        }
        .clayCard()
    }

    private func daySelector(_ plan: ClientPersonalNutritionPlan) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 9) {
                ForEach(plan.days) { day in
                    Button { selectedWeekday = day.weekday; ClientHaptics.selection() } label: {
                        VStack(spacing: 3) {
                            Text(String(day.name.prefix(3)).uppercased()).font(.caption2.weight(.bold))
                            Text("\(day.meals.count)").font(.headline.monospacedDigit())
                        }
                        .foregroundStyle(ClientClay.ink)
                        .padding(.horizontal, 14).padding(.vertical, 10)
                        .frame(minWidth: 66, minHeight: 58)
                        .background(selectedWeekday == day.weekday ? ClientClay.surfaceElevated : ClientClay.surface, in: RoundedRectangle(cornerRadius: 16))
                        .overlay { RoundedRectangle(cornerRadius: 16).stroke(day.weekday == ClientDateLogic.weekday(for: Date()) ? ClientClay.sage : selectedWeekday == day.weekday ? ClientClay.accent : ClientClay.border, lineWidth: selectedWeekday == day.weekday ? 3 : 1) }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(day.name), \(day.meals.count) pasti")
                    .accessibilityAddTraits(selectedWeekday == day.weekday ? [.isSelected] : [])
                }
            }
        }
    }

    private func personalMealCard(_ meal: ClientPersonalMeal, plan: ClientPersonalNutritionPlan) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack { Text(meal.name).font(.headline).foregroundStyle(ClientClay.ink); Spacer(); Text("\(Int(meal.calories.rounded())) kcal").font(.subheadline.weight(.bold)).foregroundStyle(ClientClay.sage) }
            Text("P \(Int(meal.protein.rounded())) g · C \(Int(meal.carbs.rounded())) g · G \(Int(meal.fat.rounded())) g")
                .font(.caption.weight(.semibold)).foregroundStyle(ClientClay.secondaryInk)
            ForEach(meal.foods) { food in
                HStack { Text(food.name).foregroundStyle(ClientClay.ink); Spacer(); Text("\(food.quantityDescription) · \(Int(food.calories.rounded())) kcal").font(.caption).foregroundStyle(ClientClay.secondaryInk) }
            }
            if meal.foods.isEmpty { Text("Nessun alimento").font(.caption).foregroundStyle(ClientClay.secondaryInk) }
        }
        .padding(.vertical, 12)
        .overlay(alignment: .bottom) { Divider() }
    }

    static func newPlan() -> ClientPersonalNutritionPlan {
        let now = Date(); let names = ["Lunedì", "Martedì", "Mercoledì", "Giovedì", "Venerdì", "Sabato", "Domenica"]
        return ClientPersonalNutritionPlan(
            id: UUID(), title: "La mia alimentazione", status: .active,
            days: names.enumerated().map { index, name in ClientPersonalNutritionDay(id: UUID(), weekday: index + 1, name: name, meals: []) },
            createdAt: now, updatedAt: now
        )
    }
}

private enum ClientNutritionCreationModal: Identifiable {
    case creation, manual, guided
    case editor(ClientPersonalNutritionPlan)
    var id: String {
        switch self {
        case .creation: "creation"
        case .manual: "manual"
        case .guided: "guided"
        case .editor(let plan): "editor-\(plan.id.uuidString)"
        }
    }
}

private struct ClientPersonalNutritionPlanEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draft: ClientPersonalNutritionPlan
    let onSave: (ClientPersonalNutritionPlan) -> Void
    init(plan: ClientPersonalNutritionPlan, onSave: @escaping (ClientPersonalNutritionPlan) -> Void) { _draft = State(initialValue: plan); self.onSave = onSave }

    var body: some View {
        NavigationStack {
            Form {
                Section("Piano") {
                    TextField("Nome", text: $draft.title)
                    Picker("Stato", selection: $draft.status) { Text("Bozza").tag(ClientPersonalPlanStatus.draft); Text("Attivo").tag(ClientPersonalPlanStatus.active); Text("Archiviato").tag(ClientPersonalPlanStatus.archived) }
                }
                Section("Giorni") {
                    ForEach($draft.days) { $day in
                        NavigationLink { ClientPersonalNutritionDayEditor(day: $day) } label: {
                            HStack { Text(day.name); Spacer(); Text("\(day.meals.count) pasti").foregroundStyle(.secondary) }
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden).background(ClientClay.canvas)
            .navigationTitle("Piano personale").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Annulla") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Salva") { draft.updatedAt = Date(); onSave(draft); dismiss() }.disabled(draft.title.count < 2) }
            }
        }
    }
}

private struct ClientPersonalNutritionDayEditor: View {
    @Binding var day: ClientPersonalNutritionDay
    var body: some View {
        Form {
            Section("Pasti") {
                ForEach($day.meals) { $meal in
                    NavigationLink { ClientPersonalMealEditor(meal: $meal) } label: {
                        VStack(alignment: .leading) { Text(meal.name); Text("\(meal.foods.count) alimenti · \(Int(meal.calories.rounded())) kcal").font(.caption).foregroundStyle(.secondary) }
                    }
                }
                .onDelete { day.meals.remove(atOffsets: $0) }
                .onMove { day.meals.move(fromOffsets: $0, toOffset: $1) }
                Button("Aggiungi pasto", systemImage: "plus") { day.meals.append(ClientPersonalMeal(id: UUID(), name: "Nuovo pasto", foods: [])) }
                if !day.meals.isEmpty {
                    Button("Duplica ultimo pasto", systemImage: "plus.square.on.square") { var copy = day.meals.last!; copy.id = UUID(); copy.name += " · Copia"; day.meals.append(copy) }
                }
            }
        }
        .scrollContentBackground(.hidden).background(ClientClay.canvas).navigationTitle(day.name).toolbar { EditButton() }
    }
}

private struct ClientPersonalMealEditor: View {
    @Binding var meal: ClientPersonalMeal
    @EnvironmentObject private var session: ClientSessionStore
    @State private var showFoodPicker = false
    @State private var showTemplatePicker = false

    var body: some View {
        Form {
            Section("Pasto") {
                TextField("Nome", text: $meal.name)
                Text("Totale \(Int(meal.calories.rounded())) kcal")
                Text("Proteine \(Int(meal.protein.rounded())) g · Carboidrati \(Int(meal.carbs.rounded())) g · Grassi \(Int(meal.fat.rounded())) g")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("Alimenti") {
                ForEach($meal.foods) { $food in
                    VStack(alignment: .leading) {
                        Text(food.name).font(.headline)
                        if let pieceWeight = food.gramsPerPiece, pieceWeight > 0 {
                            Stepper("\(food.quantityDescription)", value: Binding(
                                get: { max(1, Int((food.quantityGrams / pieceWeight).rounded())) },
                                set: { food.quantityGrams = Double($0) * pieceWeight }
                            ), in: 1...20)
                        } else {
                            HStack { TextField("Grammi", value: $food.quantityGrams, format: .number).keyboardType(.decimalPad); Text("g · \(Int(food.calories.rounded())) kcal").foregroundStyle(.secondary) }
                        }
                    }
                }
                .onDelete { meal.foods.remove(atOffsets: $0) }
                Button("Aggiungi alimento", systemImage: "plus.circle.fill") { showFoodPicker = true }
            }
            Section {
                if !session.personalContent.mealTemplates.isEmpty {
                    Button("Usa pasto abituale", systemImage: "bookmark") { showTemplatePicker = true }
                }
                Button("Salva come pasto abituale", systemImage: "bookmark.fill") {
                    session.savePersonalMealTemplate(ClientPersonalMealTemplate(id: UUID(), name: meal.name, meal: meal, updatedAt: Date()))
                }
            }
        }
        .scrollContentBackground(.hidden).background(ClientClay.canvas).navigationTitle(meal.name)
        .sheet(isPresented: $showFoodPicker) { ClientFoodPickerSheet { food in meal.foods.append(food); showFoodPicker = false } }
        .sheet(isPresented: $showTemplatePicker) {
            NavigationStack {
                List(session.personalContent.mealTemplates) { template in
                    Button {
                        var imported = template.meal
                        imported.id = meal.id
                        meal = imported
                        showTemplatePicker = false
                    } label: {
                        VStack(alignment: .leading) {
                            Text(template.name)
                            Text("\(template.meal.foods.count) alimenti · \(Int(template.meal.calories.rounded())) kcal")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                .navigationTitle("Pasti abituali")
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Chiudi") { showTemplatePicker = false } } }
            }
        }
    }
}

struct ClientFoodPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var session: ClientSessionStore
    @State private var query = ""
    @State private var catalog: [ClientFoodCatalogItem] = []
    @State private var loading = true
    @State private var selected: ClientFoodCatalogItem?
    @State private var grams = 100.0
    var allowedFoodIDs: Set<UUID>? = nil
    var coachPortions: Bool = false
    var onChooseCandidate: ((UUID) -> Void)? = nil
    let onSelect: (ClientPersonalFood) -> Void
    private var results: [ClientFoodCatalogItem] {
        catalog.filter { food in
            (allowedFoodIDs?.contains(food.id) ?? true) && (query.isEmpty || food.name.localizedStandardContains(query))
        }
    }

    var body: some View {
        NavigationStack {
            List {
                if loading { ProgressView("Caricamento catalogo…") }
                else if catalog.isEmpty {
                    Text("Catalogo temporaneamente non disponibile.")
                    Button("Riprova") { Task { await load(force: true) } }
                } else if results.isEmpty { Text("Nessun alimento trovato.").foregroundStyle(.secondary) }
                ForEach(results) { food in
                    Button {
                        selected = food
                        if coachPortions, let bounds = food.nutritionEvidence?.portion {
                            grams = food.gramsPerPiece.map { bounds.minimumGrams / $0 } ?? bounds.minimumGrams
                        } else { grams = food.gramsPerPiece == nil ? 100 : 1 }
                    } label: {
                        HStack { VStack(alignment: .leading) { Text(food.name); Text("\(Int(food.caloriesPer100g.rounded())) kcal / 100 g").font(.caption).foregroundStyle(.secondary) }; Spacer(); Image(systemName: selected?.id == food.id ? "checkmark.circle.fill" : "circle") }
                    }
                }
                if let selected {
                    Section("Quantità") {
                        if let onChooseCandidate {
                            Text("La quantità verrà calcolata dal programma prima di confermare la sostituzione.")
                            Button("Calcola quantità e impatto") { onChooseCandidate(selected.id) }.frame(minHeight: 44)
                        } else {
                        if coachPortions, let bounds = selected.nutritionEvidence?.portion {
                            let divisor = selected.gramsPerPiece ?? 1
                            Stepper("\((grams * divisor).formatted()) g", value: $grams,
                                in: (bounds.minimumGrams / divisor)...(bounds.maximumGrams / divisor), step: bounds.stepGrams / divisor)
                        } else if selected.gramsPerPiece != nil {
                            Stepper("\(Int(grams)) pezzi", value: $grams, in: 1...20, step: 1)
                        } else {
                            TextField("Grammi", value: $grams, format: .number).keyboardType(.decimalPad)
                        }
                        Text("\(Int((selected.caloriesPer100g * grams * (selected.gramsPerPiece ?? 1) / 100).rounded())) kcal").font(.headline)
                        Button("Aggiungi a \(selected.name)") {
                            onSelect(ClientNutritionCatalog.food(selected, quantity: grams))
                        }
                        .buttonStyle(ClayPrimaryButtonStyle())
                        .disabled(!grams.isFinite || grams <= 0)
                        }
                    }
                }
            }
            .searchable(text: $query, prompt: "Cerca nel catalogo alimenti")
            .task { await load(force: false) }
            .navigationTitle("Database alimenti").toolbar { ToolbarItem(placement: .cancellationAction) { Button("Chiudi") { dismiss() } } }
        }
    }

    private func load(force: Bool) async {
        loading = true
        catalog = await session.personalFoodCatalog(forceReload: force)
        loading = false
    }
}
