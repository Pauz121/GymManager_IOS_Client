import Charts
import SwiftUI

struct ClientProgressView: View {
    let entries: [ClientProgressEntry]
    let identity: ClientIdentity
    let source: ClientDataSource
    @EnvironmentObject private var session: ClientSessionStore
    @EnvironmentObject private var healthKit: HealthKitStepService
    private var weights: [ClientProgressEntry] { entries.filter { $0.weightKg != nil }.sorted { $0.recordedAt < $1.recordedAt } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                ClientPageTitle("Progressi", eyebrow: "Il tuo percorso", subtitle: "Uno sguardo chiaro alle rilevazioni condivise dal professionista.")
                activitySummary
                stepsSummary
                if let latest = weights.last, let weight = latest.weightKg {
                    VStack(alignment: .leading, spacing: 8) { Text("Ultimo peso").font(.subheadline).foregroundStyle(ClientClay.secondaryInk); Text("\(weight.formatted()) kg").font(.system(size: 36, weight: .bold, design: .rounded)); Text(latest.recordedAt.formatted(date: .abbreviated, time: .omitted)).font(.caption).foregroundStyle(ClientClay.secondaryInk) }.clayCard()
                    if weights.count > 1 {
                        Chart(weights) { entry in if let value = entry.weightKg { LineMark(x: .value("Data", entry.recordedAt), y: .value("Peso", value)).foregroundStyle(ClientClay.accent); PointMark(x: .value("Data", entry.recordedAt), y: .value("Peso", value)).foregroundStyle(ClientClay.accent) } }
                            .frame(height: 190).chartYAxisLabel("kg").clayCard()
                    }
                } else {
                    ClientEmptyState(symbol: "chart.xyaxis.line", title: "Il percorso inizia qui", message: "Le rilevazioni condivise dal professionista compariranno in questa sezione.")
                }
                if !session.activity.runningResults.isEmpty { runningSummary }
                ClientEmptyState(symbol: "camera", title: "Foto progressi", message: "Archivio fotografico protetto disponibile nella Fase 2.")
            }.padding(20)
        }.clientPage().navigationTitle("Progressi").navigationBarTitleDisplayMode(.inline)
    }

    private var activitySummary: some View {
        let completed = session.activity.workouts.filter(\.isCompleted).count
        return HStack(spacing: 14) {
            Image(systemName: "checkmark.seal.fill").font(.title).foregroundStyle(ClientClay.sage)
            VStack(alignment: .leading, spacing: 4) {
                Text("Allenamenti completati").font(.subheadline).foregroundStyle(ClientClay.secondaryInk)
                Text("\(completed)").font(.system(.title, design: .rounded, weight: .bold))
            }
        }
        .clayCard()
    }

    @ViewBuilder private var stepsSummary: some View {
        if let demo = demoSteps {
            metricCard(title: "Passi di oggi", value: demo.formatted(), detail: "Dato sintetico della modalità Demo", symbol: "figure.walk")
        } else {
            switch healthKit.state {
            case .ready(let sample):
                metricCard(title: "Passi di oggi", value: sample.count.formatted(), detail: "Apple Salute", symbol: "figure.walk")
            case .notRequested:
                ClientEmptyState(symbol: "heart.text.square", title: "Passi non collegati", message: "Puoi collegare Apple Salute dalla Home quando vuoi.")
            case .loading:
                ProgressView("Lettura passi…").clayCard()
            case .unavailable, .noData, .failed:
                ClientEmptyState(symbol: "figure.walk", title: "Passi non disponibili", message: "Nessun valore viene stimato o inventato.")
            }
        }
    }

    private var runningSummary: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Running", systemImage: "figure.run").font(.headline).foregroundStyle(ClientClay.accent)
            ForEach(session.activity.runningResults.sorted { $0.completedAt > $1.completedAt }.prefix(3)) { result in
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(result.completedAt.formatted(date: .abbreviated, time: .omitted)).font(.subheadline.weight(.semibold))
                        Text(result.distanceKm.map { "\($0.formatted()) km" } ?? "Distanza non registrata")
                            .font(.caption).foregroundStyle(ClientClay.secondaryInk)
                    }
                    Spacer()
                    if let pace = result.averagePaceMinutesPerKm {
                        Text(paceText(pace)).font(.subheadline.monospacedDigit().weight(.semibold))
                    }
                }
            }
        }
        .clayCard()
    }

    private func metricCard(title: String, value: String, detail: String, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: symbol).font(.headline).foregroundStyle(ClientClay.accent)
            Text(value).font(.system(size: 34, weight: .bold, design: .rounded))
            Text(detail).font(.caption).foregroundStyle(ClientClay.secondaryInk)
        }
        .clayCard()
    }

    private func paceText(_ minutesPerKm: Double) -> String {
        let totalSeconds = max(0, Int((minutesPerKm * 60).rounded()))
        return String(format: "%d:%02d /km", totalSeconds / 60, totalSeconds % 60)
    }

    private var demoSteps: Int? {
        #if DEBUG
        guard source == .demo else { return nil }
        return ClientDemoData.stepCount(for: identity)
        #else
        return nil
        #endif
    }
}
