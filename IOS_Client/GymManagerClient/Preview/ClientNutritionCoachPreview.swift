#if DEBUG
import SwiftUI

/// Synthetic estimate specimen; no session, food catalogue or network operation in previews.
private struct ClientNutritionTargetSpecimen: View {
    var body: some View {
        let profile = ClientNutritionCoachProfile(age: 30, biologicalSex: .female, weightKg: 65, heightCm: 170,
            activity: .init(dailyActivity: .mixed, exerciseDaysPerWeek: 3),
            health: .init(healthyAdultAcknowledged: true, pregnantOrBreastfeeding: false, eatingDisorderRisk: false, clinicalNutritionRequired: false),
            dietaryPattern: .omnivore, allergies: [], intolerances: [], excludedFoodIDs: [])
        Form {
            Section { Text("Anteprima con dati sintetici · non un piano reale") }
            if let energy = try? ClientNutritionCoachEnergy.calculate(profile: profile, phase: .maintenance) { ClientNutritionTargetSummary(energy: energy) }
        }
    }
}
#Preview("Nutrition target · Small · Dark", traits: .fixedLayout(width: 320, height: 568)) {
    ClientNutritionTargetSpecimen().preferredColorScheme(.dark)
}
#Preview("Nutrition target · Standard · Light", traits: .fixedLayout(width: 375, height: 812)) {
    ClientNutritionTargetSpecimen().preferredColorScheme(.light)
}
#Preview("Nutrition target · Accessibility", traits: .fixedLayout(width: 430, height: 932)) {
    ClientNutritionTargetSpecimen().preferredColorScheme(.dark).dynamicTypeSize(.accessibility3)
}
#endif
