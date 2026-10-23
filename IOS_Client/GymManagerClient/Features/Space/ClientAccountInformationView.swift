import SwiftUI

enum ClientAccountInformationTopic: Equatable {
    case privacy, support, deletion
    var title: String { switch self { case .privacy: "Privacy"; case .support: "Supporto"; case .deletion: "Elimina account" } }
}

struct ClientAccountInformationView: View {
    let topic: ClientAccountInformationTopic
    @State private var showDeletionInformation = false
    var body: some View {
        Form {
            if topic == .deletion {
                Section("Eliminazione account non disponibile") {
                    Text("La cancellazione definitiva richiede un percorso server verificato, non ancora disponibile nell’app Client. Uscire dall’account non elimina account o dati.")
                    Button("Informazioni sulla cancellazione", role: .destructive) { showDeletionInformation = true }
                        .frame(minHeight: 44)
                }
            } else {
                Section(topic.title) {
                    Text("Bozza — sito ancora privo di dominio ufficiale definitivo")
                        .font(.headline)
                    Text(topic == .privacy ? "La pagina /privacy del sito GymManager è una bozza e non è ancora una Privacy Policy definitiva pubblicata su un dominio HTTPS ufficiale." : "La pagina /support del sito GymManager è una bozza. Per accesso, account, sincronizzazione o problemi tecnici puoi contattare l’assistenza.")
                    if topic == .privacy { LabeledContent("Referente", value: "Paolino Bottiglieri") }
                }
            }
            Section(topic == .privacy ? "Contatto privacy" : "Contatto assistenza") {
                Link("Paolinob2@libero.it", destination: URL(string: "mailto:Paolinob2@libero.it")!)
                    .frame(minHeight: 44).accessibilityHint("Apre la tua app email")
                Text("Non inviare password, codici di accesso o dati sanitari via email.")
                    .font(.footnote).foregroundStyle(ClientClay.secondaryInk)
            }
        }
        .scrollContentBackground(.hidden).clientPage()
        .navigationTitle(topic.title).navigationBarTitleDisplayMode(.inline)
        .alert("Nessun dato è stato eliminato", isPresented: $showDeletionInformation) {
            Button("Ho capito", role: .cancel) { }
        } message: {
            Text("Il percorso di eliminazione server è ancora da implementare e verificare. Puoi contattare l’assistenza per informazioni: questa schermata non esegue una cancellazione.")
        }
    }
}
