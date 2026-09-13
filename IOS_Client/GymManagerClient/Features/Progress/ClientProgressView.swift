import Charts
import SwiftUI

struct ClientProgressView: View {
    let entries: [ClientProgressEntry]
    private var weights: [ClientProgressEntry] { entries.filter { $0.weightKg != nil }.sorted { $0.recordedAt < $1.recordedAt } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                ClientPageTitle("Progressi", eyebrow: "Il tuo percorso", subtitle: "Uno sguardo chiaro alle rilevazioni condivise dal professionista.")
                if let latest = weights.last, let weight = latest.weightKg {
                    VStack(alignment: .leading, spacing: 8) { Text("Ultimo peso").font(.subheadline).foregroundStyle(ClientClay.secondaryInk); Text("\(weight.formatted()) kg").font(.system(size: 36, weight: .bold, design: .rounded)); Text(latest.recordedAt.formatted(date: .abbreviated, time: .omitted)).font(.caption).foregroundStyle(ClientClay.secondaryInk) }.clayCard()
                    if weights.count > 1 {
                        Chart(weights) { entry in if let value = entry.weightKg { LineMark(x: .value("Data", entry.recordedAt), y: .value("Peso", value)).foregroundStyle(ClientClay.accent); PointMark(x: .value("Data", entry.recordedAt), y: .value("Peso", value)).foregroundStyle(ClientClay.accent) } }
                            .frame(height: 190).chartYAxisLabel("kg").clayCard()
                    }
                } else {
                    ClientEmptyState(symbol: "chart.xyaxis.line", title: "Il percorso inizia qui", message: "Le rilevazioni condivise dal professionista compariranno in questa sezione.")
                }
                ClientEmptyState(symbol: "camera", title: "Foto progressi", message: "Archivio fotografico protetto disponibile nella Fase 2.")
                ClientEmptyState(symbol: "heart.text.square", title: "Passi e HealthKit", message: "Integrazione futura. L’app non richiede ancora alcun permesso Salute.")
            }.padding(20)
        }.clientPage().navigationTitle("Progressi").navigationBarTitleDisplayMode(.inline)
    }
}
