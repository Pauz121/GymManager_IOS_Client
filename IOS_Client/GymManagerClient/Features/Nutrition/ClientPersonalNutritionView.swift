import SwiftUI

struct ClientPersonalNutritionLibraryView: View {
    @EnvironmentObject private var session: ClientSessionStore
    @State private var editorPlan: ClientPersonalNutritionPlan?
    @State private var selectedWeekday = ClientDateLogic.weekday(for: Date())

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ClientSectionHeader(title: "Piano personale", detail: "Creato da te", symbol: "person.crop.circle.badge.checkmark")
            if let plan = session.personalContent.activeNutrition {
                planHeader(plan)
                daySelector(plan)
                if let day = plan.days.first(where: { $0.weekday == selectedWeekday }) ?? plan.days.first {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(day.name).font(.title2.weight(.bold)).foregroundStyle(ClientClay.ink)
                        Text("\(Int(day.meals.reduce(0) { $0 + $1.calories }.rounded())) kcal · \(day.meals.count) pasti")
                            .font(.caption).foregroundStyle(ClientClay.secondaryInk)
                    }
                    ForEach(day.meals) { meal in personalMealCard(meal, plan: plan) }
                }
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    Label("Nessun piano personale", systemImage: "leaf.circle").font(.headline).foregroundStyle(ClientClay.ink)
                    Text("Crea i tuoi giorni, pasti e alimenti usando il database nutrizionale reale.").font(.subheadline).foregroundStyle(ClientClay.secondaryInk)
                    Button { editorPlan = Self.newPlan() } label: { Label("Crea piano", systemImage: "plus.circle.fill").frame(maxWidth: .infinity) }
                        .buttonStyle(ClayPrimaryButtonStyle())
                }
                .clayCard()
            }
        }
        .sheet(item: $editorPlan) { plan in
            ClientPersonalNutritionPlanEditor(plan: plan) { updated in session.savePersonalNutritionPlan(updated); editorPlan = nil }
        }
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
                Button("Modifica", systemImage: "pencil") { editorPlan = plan }
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
                        .foregroundStyle(selectedWeekday == day.weekday ? .white : ClientClay.ink)
                        .frame(width: 66, minHeight: 58)
                        .background(selectedWeekday == day.weekday ? ClientClay.brandGradient : LinearGradient(colors: [ClientClay.surfaceElevated, ClientClay.surface], startPoint: .top, endPoint: .bottom), in: RoundedRectangle(cornerRadius: 16))
                        .overlay { RoundedRectangle(cornerRadius: 16).stroke(day.weekday == ClientDateLogic.weekday(for: Date()) ? ClientClay.sage : ClientClay.border, lineWidth: 2) }
                    }
                    .buttonStyle(.plain)
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
                HStack { Text(food.name).foregroundStyle(ClientClay.ink); Spacer(); Text("\(food.quantityGrams.formatted()) g · \(Int(food.calories.rounded())) kcal").font(.caption).foregroundStyle(ClientClay.secondaryInk) }
            }
            if meal.foods.isEmpty { Text("Nessun alimento").font(.caption).foregroundStyle(ClientClay.secondaryInk) }
        }
        .clayCard(padding: 14)
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
                        HStack { TextField("Grammi", value: $food.quantityGrams, format: .number).keyboardType(.decimalPad); Text("g · \(Int(food.calories.rounded())) kcal").foregroundStyle(.secondary) }
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

private struct ClientFoodPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var session: ClientSessionStore
    @State private var query = ""
    @State private var results: [ClientFoodCatalogItem] = []
    @State private var selected: ClientFoodCatalogItem?
    @State private var grams = 100.0
    let onSelect: (ClientPersonalFood) -> Void

    var body: some View {
        NavigationStack {
            List {
                ForEach(results) { food in
                    Button { selected = food; grams = 100 } label: {
                        HStack { VStack(alignment: .leading) { Text(food.name); Text("\(Int(food.caloriesPer100g.rounded())) kcal / 100 g").font(.caption).foregroundStyle(.secondary) }; Spacer(); Image(systemName: selected?.id == food.id ? "checkmark.circle.fill" : "circle") }
                    }
                }
                if let selected {
                    Section("Quantità") {
                        TextField("Grammi", value: $grams, format: .number).keyboardType(.decimalPad)
                        Text("\(Int((selected.caloriesPer100g * grams / 100).rounded())) kcal").font(.headline)
                        Button("Aggiungi a \(selected.name)") {
                            onSelect(ClientPersonalFood(id: UUID(), catalogFoodID: selected.id, name: selected.name, quantityGrams: grams, caloriesPer100g: selected.caloriesPer100g, proteinPer100g: selected.proteinPer100g, carbsPer100g: selected.carbsPer100g, fatPer100g: selected.fatPer100g))
                        }
                        .buttonStyle(ClayPrimaryButtonStyle())
                    }
                }
            }
            .searchable(text: $query, prompt: "Cerca alimenti CREA, USDA, OFF")
            .task(id: query) { try? await Task.sleep(for: .milliseconds(350)); guard !Task.isCancelled else { return }; results = await session.searchPersonalFoods(query) }
            .navigationTitle("Database alimenti").toolbar { ToolbarItem(placement: .cancellationAction) { Button("Chiudi") { dismiss() } } }
        }
    }
}
