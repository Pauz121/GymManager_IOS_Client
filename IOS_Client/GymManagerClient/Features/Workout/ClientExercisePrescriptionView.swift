import SwiftUI

struct ClientExercisePrescriptionView: View {
    let exercise: ClientExercise
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    var body: some View {
        LazyVGrid(columns: dynamicTypeSize.isAccessibilitySize ? [GridItem(.flexible())] : [GridItem(.adaptive(minimum: 90), alignment: .leading)], alignment: .leading, spacing: ClientSpacing.control) {
            metric("Serie", exercise.sets ?? "—")
            metric("Rep", exercise.repetitions ?? "—")
            metric("Recupero", exercise.restSeconds.map { "\($0)s" } ?? "—")
            metric("Carico prescritto", exercise.loadKg.map { "\($0.formatted()) kg" } ?? "Da registrare")
        }
        .padding(.vertical, ClientSpacing.related)
        // ClientExercise has no structured RIR/RPE field. Preserve any real
        // target in operational notes; never parse or invent one here.
    }
    private func metric(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: ClientSpacing.micro) {
            Text(value).font(.headline.monospacedDigit()).foregroundStyle(ClientClay.color(.textPrimary))
            Text(title).font(.caption).foregroundStyle(ClientClay.color(.textSecondary))
        }.frame(maxWidth: .infinity, alignment: .leading).accessibilityElement(children: .combine)
    }
}
