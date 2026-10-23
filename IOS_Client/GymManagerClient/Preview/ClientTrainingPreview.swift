#if DEBUG
import SwiftUI

/// Native preview specimens with explicit synthetic content; no fake screenshots.
private struct ClientTrainingPreview: View {
    @State private var section = "Attività"
    @State private var period = ClientActivityPeriod.month
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ClientSpacing.section) {
                ClientCompactSelector(values: ["Attività", "Palestra", "Corsa", "Riepilogo"],
                                      selection: $section, title: { $0 }, accessibilityTitle: "Allenamento")
                ClientGymPlanHeader(plan: ClientWorkoutPlan(
                    id: UUID(), title: "Piano demo — forza e controllo del movimento",
                    startsOn: nil, endsOn: nil, currentWeek: 4,
                    sessions: [], todaySessionID: nil, publishedAt: Date()
                ))
                Label("Oggi riposo · consulta le sessioni del piano", systemImage: "moon.zzz")
                    .font(.subheadline).foregroundStyle(ClientClay.color(.textSecondary))
                Text("Riepilogo · Questo mese").font(.headline)
                ClientActivityRecapHeader(activeDays: 12, duration: "8h 24m")
                ClientCompactSelector(values: ClientActivityPeriod.allCases, selection: $period,
                                      title: { $0.title }, accessibilityTitle: "Periodo")
            }.padding(ClientSpacing.page)
        }
        .background(ClientClay.color(.backgroundPrimary))
        .foregroundStyle(ClientClay.color(.textPrimary))
    }
}

#Preview("Training · Small · Dark", traits: .fixedLayout(width: 320, height: 568)) {
    ClientTrainingPreview().preferredColorScheme(.dark)
}
#Preview("Training · Standard · Light", traits: .fixedLayout(width: 375, height: 812)) {
    ClientTrainingPreview().preferredColorScheme(.light)
}
#Preview("Training · ProMax · AX3", traits: .fixedLayout(width: 430, height: 932)) {
    ClientTrainingPreview().preferredColorScheme(.dark).dynamicTypeSize(.accessibility3)
}
#endif
