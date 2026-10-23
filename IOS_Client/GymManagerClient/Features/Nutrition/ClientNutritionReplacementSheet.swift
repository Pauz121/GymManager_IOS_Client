import SwiftUI

struct ClientNutritionReplacementSheet: View {
    let plan: ClientPersonalNutritionPlan
    let target: ClientNutritionSmartReplacement.Target
    let catalog: [ClientFoodCatalogItem]
    let expectedOwnerID: UUID?
    let onApply: (ClientPersonalNutritionPlan) -> Void
    @EnvironmentObject private var session: ClientSessionStore
    @Environment(\.dismiss) private var dismiss
    @State private var alternatives: [ClientNutritionSmartReplacement.Proposal] = []
    @State private var selected: ClientNutritionSmartReplacement.Proposal?
    @State private var loading = false
    @State private var allowRebalance = false
    @State private var consent = false
    @State private var search = false
    @State private var message: String?
    @State private var requestID = UUID()

    var body: some View {
        NavigationStack {
            List {
                if loading { ProgressView("Calcolo delle alternative e delle quantità…") }
                Section {
                    Text("Le quantità vengono ricalcolate con gli stessi controlli del piano. Nessuna percentuale di somiglianza e nessuna modifica nascosta.").font(.subheadline).foregroundStyle(.secondary)
                    Toggle("Valuta un piccolo ribilanciamento dello stesso pasto", isOn: $allowRebalance)
                        .disabled(loading)
                    Text("Se serve cambiare altri alimenti, vedrai ogni quantità prima di confermare.").font(.caption).foregroundStyle(.secondary)
                }
                Section("Alternative consigliate") {
                    ForEach(Array(alternatives.enumerated()), id: \.element.replacement.catalogFoodID) { _, proposal in
                        Button { selected = proposal; consent = false; message = nil } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(proposal.replacement.name).font(.headline).foregroundStyle(.primary)
                                Text("\(proposal.replacement.quantityDescription) · \(summary(proposal.difference.after))").foregroundStyle(.secondary)
                                Text(differences(proposal.difference)).font(.subheadline).foregroundStyle(.secondary)
                                if proposal.requiresRebalanceConsent { Label("Richiede conferma delle altre quantità", systemImage: "info.circle").font(.caption) }
                            }.frame(minHeight: 44)
                        }
                    }
                    if !loading && alternatives.isEmpty { Text("Nessuna alternativa compatibile con questo piano e catalogo. L'alimento originale non è stato modificato.") }
                    Button("Cerca nel catalogo", systemImage: "magnifyingglass") { search = true }.disabled(loading)
                }
                if let selected { preview(selected) }
                if let message { Section("Da verificare") { Label(message, systemImage: "exclamationmark.circle") } }
            }
            .navigationTitle("Sostituisci alimento").navigationBarTitleDisplayMode(.inline).tint(ClientClay.sage)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Annulla") { dismiss() } } }
            .task(id: allowRebalance) { await load() }
            .sheet(isPresented: $search) { searchSheet }
        }
    }
    private func preview(_ proposal: ClientNutritionSmartReplacement.Proposal) -> some View {
        Section("Prima di confermare") {
            Text("Prima: \(proposal.original.name) · \(proposal.original.quantityDescription)").font(.headline)
            Text(summary(proposal.difference.before)).foregroundStyle(.secondary)
            Text("Dopo: \(proposal.replacement.name) · \(proposal.replacement.quantityDescription)").font(.headline)
            Text(summary(proposal.difference.after)).foregroundStyle(.secondary)
            Text("Differenza alimento: \(differences(proposal.difference))")
            if proposal.requiresRebalanceConsent {
                ForEach(proposal.additionalChanges, id: \.foodID) { change in Text(change.explanation) }
                if let beforeMeal = plan.days.first(where: { $0.id == target.dayID })?.meals.first(where: { $0.id == target.mealID }),
                   let afterMeal = proposal.plan.days.first(where: { $0.id == target.dayID })?.meals.first(where: { $0.id == target.mealID }) {
                    Text("Pasto prima: \(summary(.meal(beforeMeal)))")
                    Text("Pasto dopo: \(summary(.meal(afterMeal)))")
                }
                Toggle("Confermo anche tutte le altre quantità elencate", isOn: $consent)
            }
            Button(proposal.requiresRebalanceConsent ? "Conferma modifiche" : "Sostituisci") { apply(proposal) }
                .buttonStyle(ClayPrimaryButtonStyle()).frame(minHeight: 44)
                .disabled(loading || (proposal.requiresRebalanceConsent && !consent))
            Text("Applichi solo alla bozza. Il piano verrà salvato quando scegli Salva piano.").font(.caption).foregroundStyle(.secondary)
        }
    }
    @ViewBuilder private var searchSheet: some View {
            let anchored = ClientPlanEditing.beginNutrition(plan)
            let spec = anchored.editProvenance?.nutritionLayout?.meal(dayID: target.dayID, mealID: target.mealID)
            let role = spec?.foodRoles.first(where: { $0.foodID == target.foodID })?.role
            let admitted = role.map { ClientNutritionCoachEditing.availableFoods(plan: plan, layout: anchored.editProvenance?.nutritionLayout,
                dayID: target.dayID, mealID: target.mealID, role: $0, catalog: catalog) } ?? []
            ClientFoodPickerSheet(allowedFoodIDs: Set(admitted.map(\.id)), onChooseCandidate: { id in
                search = false
                Task { await propose(id) }
            }) { _ in }
    }
    private func load() async {
        let request = UUID(); requestID = request
        loading = true; selected = nil; consent = false; message = nil; alternatives = []
        defer { if requestID == request { loading = false } }
        do {
            let proposals = try await session.prepareNutritionAlternatives(plan: plan, target: target, catalog: catalog,
                allowRebalance: allowRebalance, expectedOwnerID: expectedOwnerID)
            guard requestID == request, !Task.isCancelled else { return }
            alternatives = proposals
        } catch { if requestID == request && !Task.isCancelled { message = error.localizedDescription } }
    }
    private func propose(_ id: UUID) async {
        guard !loading else { return }; loading = true; consent = false; defer { loading = false }
        do {
            selected = try await session.prepareNutritionReplacement(plan: plan, target: target, candidateID: id, catalog: catalog,
                allowRebalance: allowRebalance, expectedOwnerID: expectedOwnerID)
            message = nil
        } catch { selected = nil; message = error.localizedDescription }
    }
    private func apply(_ proposal: ClientNutritionSmartReplacement.Proposal) {
        do {
            _ = try session.nutritionCoachOwner(expectedOwnerID: expectedOwnerID)
            guard let expectedOwnerID else { throw ClientNutritionGenerationEligibility.deniedUnauthenticated }
            let updated = try session.applySmartNutritionReplacement(proposal, to: plan, catalog: catalog, acceptRebalance: consent, expectedOwnerID: expectedOwnerID)
            onApply(updated)
        } catch { message = error.localizedDescription }
    }
    private func summary(_ value: ClientNutritionTotals) -> String {
        "\(value.calories.formatted(.number.precision(.fractionLength(0)))) kcal · P \(value.protein.formatted(.number.precision(.fractionLength(0)))) g · C \(value.carbs.formatted(.number.precision(.fractionLength(0)))) g · G \(value.fat.formatted(.number.precision(.fractionLength(0)))) g"
    }
    private func differences(_ value: ClientNutritionReplacementDifference) -> String {
        [ClientNutritionCoachFeedback.signed(value.calories, unit: "kcal"), "P " + ClientNutritionCoachFeedback.signed(value.protein, unit: "g"),
         "C " + ClientNutritionCoachFeedback.signed(value.carbs, unit: "g"), "G " + ClientNutritionCoachFeedback.signed(value.fat, unit: "g")].joined(separator: " · ")
    }
}
