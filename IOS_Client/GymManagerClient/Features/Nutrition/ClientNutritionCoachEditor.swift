import SwiftUI

/// Sections embedded in the EXISTING Nutrition wizard, not another plan/editor format.
struct ClientNutritionCoachEditorSections: View {
    @Binding var draft: ClientPersonalNutritionPlan
    @Binding var layout: ClientNutritionEditingLayout?
    @Binding var dayIndex: Int
    let catalog: [ClientFoodCatalogItem]
    let expectedOwnerID: UUID?
    let issues: Set<ClientNutritionPlanIssue>
    let replacementPlan: ClientPersonalNutritionPlan?
    let onAcceptedReplacement: (ClientPersonalNutritionPlan) -> Void
    @EnvironmentObject private var session: ClientSessionStore
    @State private var addMealID: UUID?
    @State private var addRole: ClientNutritionFoodRole = .protein
    @State private var showAddPicker = false
    @State private var replacement: ReplacementTarget?
    @State private var message: String?
    @State private var copyDestination: Int?
    @State private var showCopy = false
    private struct ReplacementTarget: Identifiable { let id: UUID; let target: ClientNutritionSmartReplacement.Target }
    private var day: ClientPersonalNutritionDay { draft.days[dayIndex] }
    private var totals: ClientNutritionTotals { day.meals.reduce(.init()) { $0 + .meal($1) } }

    var body: some View {
        Section("Il tuo piano") {
            TextField("Nome piano", text: $draft.title)
            Picker("Stato dopo il salvataggio", selection: $draft.status) {
                Text("Attivo · sostituisce il piano attivo").tag(ClientPersonalPlanStatus.active)
                Text("Bozza · non sostituisce il piano attivo").tag(ClientPersonalPlanStatus.draft)
            }
            Text("Le modifiche sono una bozza fino alla conferma del salvataggio.").font(.subheadline).foregroundStyle(.secondary)
        }
        Section {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(draft.days.indices, id: \.self) { index in
                        Button { dayIndex = index; ClientHaptics.selection() } label: {
                            Text(draft.days[index].name).padding(.horizontal, 12).frame(minHeight: 44)
                        }.buttonStyle(.bordered).tint(dayIndex == index ? ClientClay.sage : .secondary)
                            .accessibilityAddTraits(dayIndex == index ? [.isSelected] : [])
                    }
                }
            }
            TextField("Nome giornata", text: $draft.days[dayIndex].name)
            dailySummary
        }
        ForEach(Array(day.meals.enumerated()), id: \.element.id) { index, meal in
            Section {
                TextField("Nome pasto", text: $draft.days[dayIndex].meals[index].name).font(.headline)
                Text(nutrients(.meal(meal))).font(.subheadline).monospacedDigit().foregroundStyle(.secondary)
                ForEach(Array(meal.foods.enumerated()), id: \.element.id) { foodIndex, food in
                    foodRow(food, meal: index, index: foodIndex)
                }
                Button("Aggiungi alimento compatibile", systemImage: "plus.circle") { addMealID = meal.id }.frame(minHeight: 44)
                DisclosureGroup("Ordine e organizzazione") {
                    Button("Sposta pasto su", systemImage: "arrow.up") { draft.days[dayIndex].meals.swapAt(index, index - 1) }.disabled(index == 0)
                    Button("Sposta pasto giù", systemImage: "arrow.down") { draft.days[dayIndex].meals.swapAt(index, index + 1) }.disabled(index == day.meals.count - 1)
                    Button("Copia pasto", systemImage: "doc.on.doc") { edit { try ClientNutritionCoachEditing.copyMeal(day: dayIndex, meal: index, plan: &$0, layout: &$1) } }
                    Button("Elimina pasto", role: .destructive) {
                        edit { plan, layout in
                            let id = plan.days[dayIndex].meals.remove(at: index).id
                            for d in layout.days.indices { layout.days[d].meals.removeAll { $0.mealID == id } }
                        }
                    }
                }
            } header: { Text(meal.name) }
        }
        Section("Distribuzione dei pasti") {
            Text("Modifica le quote di energia e proteine; ciascuna colonna deve totalizzare 100%. Nessuna quantità viene cambiata automaticamente.").font(.subheadline).foregroundStyle(.secondary)
            ForEach(day.meals) { meal in
                VStack(alignment: .leading, spacing: 8) {
                    Text(meal.name).font(.headline)
                    Picker("Tipo di pasto", selection: occasion(mealID: meal.id)) {
                        Text("Colazione").tag(ClientNutritionMealOccasion.breakfast)
                        Text("Pasto principale").tag(ClientNutritionMealOccasion.main)
                        Text("Spuntino").tag(ClientNutritionMealOccasion.snack)
                    }
                    LabeledContent("Energia %") { TextField("Quota energia in percentuale", value: share(mealID: meal.id, protein: false), format: .number).keyboardType(.decimalPad).multilineTextAlignment(.trailing) }
                    LabeledContent("Proteine %") { TextField("Quota proteine in percentuale", value: share(mealID: meal.id, protein: true), format: .number).keyboardType(.decimalPad).multilineTextAlignment(.trailing) }
                }
            }
            Button("Aggiungi pasto vuoto", systemImage: "plus") {
                edit { plan, layout in
                    guard let d = layout.days.firstIndex(where: { $0.dayID == day.id }) else { throw ClientSmartPlanEditError.missingTarget }
                    let meal = ClientPersonalMeal(id: UUID(), name: "Nuovo pasto", foods: [])
                    plan.days[dayIndex].meals.append(meal)
                    layout.days[d].meals.append(.init(mealID: meal.id, occasion: .main, energyShare: 0, proteinShare: 0, foodRoles: []))
                }
            }.disabled(day.meals.count >= 6)
            Text("Un pasto vuoto o una copia possono rendere la bozza da correggere. Completa alimenti e distribuzione prima di salvare.").font(.caption).foregroundStyle(.secondary)
            if draft.days.count > 1 {
                Menu("Copia questo giorno…") {
                    ForEach(draft.days.indices.filter { $0 != dayIndex }, id: \.self) { destination in
                        Button("In \(draft.days[destination].name)") { copyDestination = destination; showCopy = true }
                    }
                }.frame(minHeight: 44)
            }
        }
        Section("Verifica della bozza") {
            Label(issues.isEmpty ? "Piano bilanciato secondo i controlli del programma" : "Da correggere · non salvabile", systemImage: issues.isEmpty ? "checkmark.circle" : "exclamationmark.circle")
            ForEach(ClientNutritionCoachFeedback.issues(issues), id: \.self) { Text($0).font(.subheadline) }
            if let message { Text(message).font(.subheadline) }
        }
        Section {
            DisclosureGroup("Perché questo piano?") {
                Text("Una base \(draft.creationAnswers?.coachProfile?.dietaryPattern.title.lowercased() ?? "personalizzata"), organizzata in \(day.meals.count) pasti con porzioni del catalogo verificato. Il target segue l'obiettivo scelto e la stima di attività. Le esclusioni restano obbligatorie; puoi modificare la proposta e ricontrollarla.")
            }
        }
        .confirmationDialog("Sostituire i pasti del giorno selezionato?", isPresented: $showCopy, titleVisibility: .visible) {
            Button("Copia e sostituisci", role: .destructive) {
                if let copyDestination { edit { try ClientNutritionCoachEditing.copyDay(from: dayIndex, to: copyDestination, plan: &$0, layout: &$1) } }
            }; Button("Annulla", role: .cancel) { copyDestination = nil }
        }
        .sheet(isPresented: Binding(get: { addMealID != nil }, set: { if !$0 { addMealID = nil } })) { addSheet }
        .sheet(item: $replacement) { item in
            if let replacementPlan {
                ClientNutritionReplacementSheet(plan: replacementPlan, target: item.target, catalog: catalog, expectedOwnerID: expectedOwnerID) { updated in
                    onAcceptedReplacement(updated); replacement = nil
                }
            } else { Text("Correggi la bozza prima di richiedere una sostituzione.") }
        }
    }

    private var dailySummary: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Piano della giornata").font(.headline)
            Text(nutrients(totals)).monospacedDigit()
            if let target = draft.target {
                Text("Target: \(nutrients(.init(calories: target.calories, protein: target.protein, carbs: target.carbs, fat: target.fat)))").font(.subheadline).foregroundStyle(.secondary)
            }
        }.accessibilityElement(children: .combine)
    }
    private func foodRow(_ food: ClientPersonalFood, meal: Int, index: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(food.name).font(.headline)
            Text(nutrients(.init(calories: food.calories, protein: food.protein, carbs: food.carbs, fat: food.fat))).font(.subheadline).foregroundStyle(.secondary)
            LabeledContent("Quantità in grammi") {
                TextField("Grammi di \(food.name)", value: $draft.days[dayIndex].meals[meal].foods[index].quantityGrams, format: .number).keyboardType(.decimalPad).multilineTextAlignment(.trailing)
            }
            if let piece = food.gramsPerPiece { Text("Un pezzo corrisponde a \(piece.formatted()) g. Usa solo pezzi interi.").font(.caption).foregroundStyle(.secondary) }
            if let bounds = food.nutritionEvidence?.portion {
                Text("Porzione verificata: \(bounds.minimumGrams.formatted())–\(bounds.maximumGrams.formatted()) g, passi di \(bounds.stepGrams.formatted()) g.").font(.caption).foregroundStyle(.secondary)
            }
            HStack(spacing: 12) {
                Button("Sostituisci", systemImage: "arrow.triangle.2.circlepath") {
                    replacement = .init(id: food.id, target: .init(dayID: day.id, mealID: day.meals[meal].id, foodID: food.id))
                }.disabled(!issues.isEmpty).frame(minHeight: 44)
                Spacer()
                Menu {
                    Button("Sposta su") { draft.days[dayIndex].meals[meal].foods.swapAt(index, index - 1) }.disabled(index == 0)
                    Button("Sposta giù") { draft.days[dayIndex].meals[meal].foods.swapAt(index, index + 1) }.disabled(index == day.meals[meal].foods.count - 1)
                    ForEach(day.meals.indices.filter { $0 != meal }, id: \.self) { destination in
                        Button("Sposta in \(day.meals[destination].name)") { edit { try ClientNutritionCoachEditing.move(foodID: food.id, day: dayIndex, from: meal, to: destination, plan: &$0, layout: &$1) } }
                    }
                    Button("Elimina alimento", role: .destructive) { edit { ClientNutritionCoachEditing.remove(foodID: food.id, day: dayIndex, meal: meal, plan: &$0, layout: &$1) } }
                } label: { Label("Azioni", systemImage: "ellipsis.circle").frame(minHeight: 44) }
            }
        }.padding(.vertical, 8)
    }
    @ViewBuilder private var addSheet: some View {
        if let mealID = addMealID, let meal = day.meals.firstIndex(where: { $0.id == mealID }) {
            NavigationStack {
                Form {
                    Section("Tipo di alimento da aggiungere") {
                        Picker("Ruolo nel pasto", selection: $addRole) { ForEach(ClientNutritionFoodRole.allCases, id: \.self) { Text($0.title).tag($0) } }
                        let allowed = ClientNutritionCoachEditing.availableFoods(plan: draft, layout: layout, dayID: day.id, mealID: mealID, role: addRole, catalog: catalog)
                        Button("Cerca nel catalogo compatibile") { showAddPicker = true }.disabled(allowed.isEmpty)
                        .sheet(isPresented: $showAddPicker) {
                            ClientFoodPickerSheet(allowedFoodIDs: Set(allowed.map(\.id)), coachPortions: true) { selected in
                                guard let row = allowed.first(where: { $0.id == selected.catalogFoodID }) else { return }
                                edit { try ClientNutritionCoachEditing.add(row, grams: selected.quantityGrams, role: addRole, day: dayIndex, meal: meal, plan: &$0, layout: &$1) }
                                if message == nil { showAddPicker = false; addMealID = nil }
                            }
                        }
                        if allowed.isEmpty { Text("Nessun alimento verificato compatibile con questo ruolo e pasto. Prova un altro ruolo, senza rimuovere vincoli di sicurezza.") }
                        if let message { Text(message) }
                    }
                }.navigationTitle("Aggiungi alimento")
                    .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Annulla") { addMealID = nil } } }
            }
        }
    }
    private func share(mealID: UUID, protein: Bool) -> Binding<Double> {
        Binding(get: { let spec = layout?.meal(dayID: day.id, mealID: mealID); return (protein ? spec?.proteinShare : spec?.energyShare).map { $0 * 100 } ?? 0 }, set: { value in
            guard var copy = layout, let d = copy.days.firstIndex(where: { $0.dayID == day.id }), let m = copy.days[d].meals.firstIndex(where: { $0.mealID == mealID }) else { return }
            if protein { copy.days[d].meals[m].proteinShare = value / 100 } else { copy.days[d].meals[m].energyShare = value / 100 }
            layout = copy
        })
    }
    private func occasion(mealID: UUID) -> Binding<ClientNutritionMealOccasion> {
        Binding(get: { layout?.meal(dayID: day.id, mealID: mealID)?.occasion ?? .main }, set: { value in
            guard var copy = layout, let d = copy.days.firstIndex(where: { $0.dayID == day.id }), let m = copy.days[d].meals.firstIndex(where: { $0.mealID == mealID }) else { return }
            copy.days[d].meals[m].occasion = value; layout = copy
        })
    }
    private func edit(_ operation: (inout ClientPersonalNutritionPlan, inout ClientNutritionEditingLayout) throws -> Void) {
        guard var copy = layout else { message = "Distribuzione del piano non disponibile."; return }
        var plan = draft
        do { try operation(&plan, &copy); draft = plan; layout = copy; message = nil }
        catch { message = error.localizedDescription }
    }
    private func nutrients(_ totals: ClientNutritionTotals) -> String {
        "\(totals.calories.formatted(.number.precision(.fractionLength(0)))) kcal · P \(totals.protein.formatted(.number.precision(.fractionLength(0)))) g · C \(totals.carbs.formatted(.number.precision(.fractionLength(0)))) g · G \(totals.fat.formatted(.number.precision(.fractionLength(0)))) g"
    }
}
