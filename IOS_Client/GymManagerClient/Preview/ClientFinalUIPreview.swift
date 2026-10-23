#if DEBUG
import SwiftUI

// Theme/account specimens only; native app navigation and real data remain in
// MAC_ACCEPTANCE_BACKLOG. These previews are DEFINED, NOT RUN on Windows.
private struct ClientFinalThemeSpecimen: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ClientSpacing.group) {
                ClientPageTitle("Il tuo spazio", eyebrow: "Aspetto", subtitle: "Specimen di sistema, non dati Cliente")
                VStack(alignment: .leading) {
                    Text("Contenuto principale").font(.headline).foregroundStyle(ClientClay.ink)
                    Text("Informazioni secondarie leggibili").foregroundStyle(ClientClay.secondaryInk)
                }.clayCard()
                Text("Superficie premium").premiumCard()
                Button("Azione principale") {}.buttonStyle(ClayPrimaryButtonStyle())
                Button("Azione secondaria") {}.buttonStyle(ClaySecondaryButtonStyle())
                ClientBadge(text: "Stato verificato", tint: ClientClay.sage, symbol: "checkmark")
            }.padding(ClientSpacing.page)
        }.clientPage()
    }
}
#Preview("Final Light · 320") {
    ClientFinalThemeSpecimen().preferredColorScheme(.light).frame(width: 320)
}
#Preview("Final Dark · 375") {
    ClientFinalThemeSpecimen().preferredColorScheme(.dark).frame(width: 375)
}
#Preview("Final System · 430 · AX") {
    ClientFinalThemeSpecimen().dynamicTypeSize(.accessibility3).frame(width: 430)
}
#endif
