#if DEBUG
import SwiftUI

/// Synthetic specimen only; these are not real catalog records or app screenshots.
private struct ClientExerciseExperiencePreview: View {
    private var exercise: ClientExercise {
        var item = ClientExercise(id: UUID(), name: "Esercizio demo — nome lungo per verificare la lettura",
                                  sets: "3", repetitions: "8–10", restSeconds: 120, loadKg: nil,
                                  notes: "Nota sintetica di anteprima", videoURL: nil)
        item.primaryMuscles = [.chest]
        item.secondaryMuscles = [.triceps, .shoulders]
        return item
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ClientSpacing.section) {
                Text("Anteprima con dati sintetici").font(.caption)
                Text(exercise.name).font(.title2.weight(.bold))
                ClientExerciseVisualCard(exercise: exercise)
                ClientExercisePrescriptionView(exercise: exercise)
            }.padding(ClientSpacing.page)
        }
        .foregroundStyle(ClientClay.color(.textPrimary))
        .background(ClientClay.color(.backgroundPrimary))
    }
}

#Preview("Exercise · Small · Dark", traits: .fixedLayout(width: 320, height: 568)) {
    ClientExerciseExperiencePreview().preferredColorScheme(.dark)
}
#Preview("Exercise · Standard · Light specimen", traits: .fixedLayout(width: 375, height: 812)) {
    ClientExerciseExperiencePreview().preferredColorScheme(.light)
}
#Preview("Exercise · ProMax · AX3", traits: .fixedLayout(width: 430, height: 932)) {
    ClientExerciseExperiencePreview().preferredColorScheme(.dark).dynamicTypeSize(.accessibility3)
}
#endif
