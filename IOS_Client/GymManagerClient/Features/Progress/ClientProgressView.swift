import Charts
import SwiftUI

struct ClientProgressView: View {
    let entries: [ClientProgressEntry]
    let identity: ClientIdentity
    let source: ClientDataSource

    @EnvironmentObject private var session: ClientSessionStore
    @EnvironmentObject private var healthKit: HealthKitStepService

    private struct MeasurementPoint: Identifiable {
        let id: String
        let date: Date
        let value: Double
        let kind: String
    }

    private struct ActivityPoint: Identifiable {
        let date: Date
        let count: Int
        var id: Date { date }
    }

    private var weights: [ClientProgressEntry] {
        entries.filter { $0.weightKg != nil }.sorted { $0.recordedAt < $1.recordedAt }
    }

    private var latestWaist: Double? {
        entries.sorted { $0.recordedAt > $1.recordedAt }.compactMap(\.waistCm).first
    }

    private var latestHips: Double? {
        entries.sorted { $0.recordedAt > $1.recordedAt }.compactMap(\.hipsCm).first
    }

    private var completedWorkouts: Int {
        session.activity.workouts.filter(\.isCompleted).count
    }

    private var totalRunningDistance: Double {
        session.activity.runningResults.compactMap(\.distanceKm).reduce(0, +)
    }

    private var todaySteps: Int? {
        if let demoSteps { return demoSteps }
        if case .ready(let sample) = healthKit.state { return sample.count }
        return nil
    }

    private var measurements: [MeasurementPoint] {
        entries.flatMap { entry in
            var result: [MeasurementPoint] = []
            if let waist = entry.waistCm {
                result.append(MeasurementPoint(id: "vita-\(entry.id)", date: entry.recordedAt, value: waist, kind: "Vita"))
            }
            if let hips = entry.hipsCm {
                result.append(MeasurementPoint(id: "fianchi-\(entry.id)", date: entry.recordedAt, value: hips, kind: "Fianchi"))
            }
            return result
        }
        .sorted { $0.date < $1.date }
    }

    private var weeklyActivity: [ActivityPoint] {
        let calendar = Calendar.autoupdatingCurrent
        let today = calendar.startOfDay(for: Date())
        return (0..<7).reversed().compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            let count = session.activity.workouts.filter { execution in
                guard let completedAt = execution.completedAt else { return false }
                return calendar.isDate(completedAt, inSameDayAs: day)
            }.count
            return ActivityPoint(date: day, count: count)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                ClientPageTitle("Progressi", eyebrow: "La tua evoluzione", subtitle: "Trend e risultati reali, leggibili in un colpo d’occhio.")
                progressHero
                kpiGrid
                weeklyWorkoutChart

                if !weights.isEmpty { weightSection }
                if !measurements.isEmpty { measurementsSection }
                if !session.activity.runningResults.isEmpty { runningSection }

                if entries.isEmpty, completedWorkouts == 0, session.activity.runningResults.isEmpty {
                    ClientEmptyState(
                        symbol: "chart.line.uptrend.xyaxis",
                        title: "Il percorso inizia qui",
                        message: "Peso, misure e attività completate costruiranno nel tempo una vista chiara dei tuoi progressi."
                    )
                }
            }
            .padding(20)
        }
        .clientPage()
        .navigationTitle("Progressi")
        .navigationBarTitleDisplayMode(.inline)
        .task { await healthKit.refreshIfPreviouslyRequested() }
    }

    private var progressHero: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("PANORAMICA").font(.caption.weight(.bold)).tracking(1.2).foregroundStyle(.white.opacity(0.66))
                    Text(heroTitle).font(.system(.title2, design: .rounded, weight: .bold)).foregroundStyle(.white)
                    Text(heroDetail).font(.subheadline).foregroundStyle(.white.opacity(0.72))
                }
                Spacer()
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.title2.weight(.semibold)).foregroundStyle(ClientClay.accentSoft)
                    .frame(width: 50, height: 50)
                    .background(.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            HStack(spacing: 8) {
                compactHeroMetric(value: "\(completedWorkouts)", label: "workout")
                compactHeroMetric(value: session.activity.runningResults.isEmpty ? "—" : "\(session.activity.runningResults.count)", label: "corse")
                compactHeroMetric(value: entries.isEmpty ? "—" : "\(entries.count)", label: "rilevazioni")
            }
        }
        .premiumCard()
    }

    private var heroTitle: String {
        guard let first = weights.first?.weightKg, let last = weights.last?.weightKg, weights.count > 1 else {
            return completedWorkouts > 0 ? "La costanza sta prendendo forma" : "Costruiamo il tuo trend"
        }
        let delta = last - first
        if abs(delta) < 0.05 { return "Peso stabile nel periodo" }
        return "\(delta > 0 ? "+" : "")\(delta.formatted(.number.precision(.fractionLength(1)))) kg nel periodo"
    }

    private var heroDetail: String {
        guard let firstDate = weights.first?.recordedAt, let lastDate = weights.last?.recordedAt, weights.count > 1 else {
            return "Ogni rilevazione rende l’andamento più significativo."
        }
        return "Dal \(firstDate.formatted(date: .abbreviated, time: .omitted)) al \(lastDate.formatted(date: .abbreviated, time: .omitted))"
    }

    private func compactHeroMetric(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(.headline.monospacedDigit()).foregroundStyle(.white)
            Text(label).font(.caption2).foregroundStyle(.white.opacity(0.62))
        }
        .padding(.horizontal, 11).padding(.vertical, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.09), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
    }

    private var kpiGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            ClientMetricTile(
                title: "Peso attuale",
                value: weights.last?.weightKg.map { "\($0.formatted()) kg" } ?? "—",
                detail: weights.last?.recordedAt.formatted(date: .abbreviated, time: .omitted) ?? "Nessuna rilevazione",
                symbol: "scalemass.fill",
                tint: ClientClay.accent
            )
            ClientMetricTile(
                title: "Passi oggi",
                value: todaySteps?.formatted() ?? "—",
                detail: todaySteps == nil ? "Apple Salute non collegata" : "Totale giornaliero",
                symbol: "figure.walk",
                tint: ClientClay.gold
            )
            ClientMetricTile(
                title: "Allenamenti",
                value: completedWorkouts.formatted(),
                detail: "Completati su questo iPhone",
                symbol: "checkmark.seal.fill",
                tint: ClientClay.sage
            )
            ClientMetricTile(
                title: "Distanza corsa",
                value: totalRunningDistance > 0 ? "\(totalRunningDistance.formatted(.number.precision(.fractionLength(1)))) km" : "—",
                detail: session.activity.runningResults.isEmpty ? "Nessuna corsa salvata" : "Totale registrato",
                symbol: "figure.run",
                tint: ClientClay.accent
            )
        }
    }

    private var weeklyWorkoutChart: some View {
        VStack(alignment: .leading, spacing: 14) {
            ClientSectionHeader(title: "Ultimi 7 giorni", detail: "Workout completati", symbol: "calendar.badge.checkmark")
            Chart(weeklyActivity) { point in
                BarMark(x: .value("Giorno", point.date, unit: .day), y: .value("Allenamenti", point.count))
                    .foregroundStyle(LinearGradient(colors: [ClientClay.accent, ClientClay.accent.opacity(0.55)], startPoint: .top, endPoint: .bottom))
                    .cornerRadius(6)
            }
            .chartYScale(domain: 0...max(1, weeklyActivity.map(\.count).max() ?? 1))
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) { _ in
                    AxisValueLabel(format: .dateTime.weekday(.narrow))
                    AxisGridLine().foregroundStyle(.clear)
                }
            }
            .chartYAxis(.hidden)
            .frame(height: 130)
            .accessibilityLabel("Allenamenti completati negli ultimi sette giorni")
        }
        .clayCard()
    }

    private var weightSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            ClientSectionHeader(title: "Andamento peso", detail: "kg", symbol: "scalemass.fill")
            if let latest = weights.last, let value = latest.weightKg {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(value.formatted()).font(.system(size: 38, weight: .bold, design: .rounded))
                    Text("kg").font(.headline).foregroundStyle(ClientClay.secondaryInk)
                    Spacer()
                    if let deltaText = weightDeltaText {
                        ClientBadge(text: deltaText, tint: ClientClay.accent, symbol: "arrow.left.and.right")
                    }
                }
            }
            if weights.count > 1 {
                Chart(weights) { entry in
                    if let value = entry.weightKg {
                        AreaMark(x: .value("Data", entry.recordedAt), y: .value("Peso", value))
                            .foregroundStyle(LinearGradient(colors: [ClientClay.accent.opacity(0.3), ClientClay.accent.opacity(0.02)], startPoint: .top, endPoint: .bottom))
                        LineMark(x: .value("Data", entry.recordedAt), y: .value("Peso", value))
                            .foregroundStyle(ClientClay.accent).lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                        PointMark(x: .value("Data", entry.recordedAt), y: .value("Peso", value))
                            .foregroundStyle(ClientClay.accent).symbolSize(48)
                    }
                }
                .chartXAxis { AxisMarks(values: .automatic(desiredCount: 4)) { _ in AxisValueLabel(format: .dateTime.day().month(.abbreviated)); AxisGridLine().foregroundStyle(.clear) } }
                .frame(height: 210)
                .accessibilityLabel("Grafico andamento del peso")
            }
        }
        .clayCard()
    }

    private var weightDeltaText: String? {
        guard let first = weights.first?.weightKg, let last = weights.last?.weightKg, weights.count > 1 else { return nil }
        let delta = last - first
        return "\(delta > 0 ? "+" : "")\(delta.formatted(.number.precision(.fractionLength(1)))) kg"
    }

    private var measurementsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            ClientSectionHeader(title: "Misure corporee", detail: "cm", symbol: "ruler.fill")
            HStack(spacing: 10) {
                measurementSummary(title: "Vita", value: latestWaist)
                measurementSummary(title: "Fianchi", value: latestHips)
            }
            if Set(measurements.map(\.date)).count > 1 {
                Chart(measurements) { point in
                    LineMark(x: .value("Data", point.date), y: .value("Centimetri", point.value))
                        .foregroundStyle(by: .value("Misura", point.kind))
                        .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                    PointMark(x: .value("Data", point.date), y: .value("Centimetri", point.value))
                        .foregroundStyle(by: .value("Misura", point.kind))
                }
                .chartForegroundStyleScale(["Vita": ClientClay.accent, "Fianchi": ClientClay.sage])
                .chartXAxis { AxisMarks(values: .automatic(desiredCount: 4)) { _ in AxisValueLabel(format: .dateTime.day().month(.abbreviated)); AxisGridLine().foregroundStyle(.clear) } }
                .frame(height: 200)
                .accessibilityLabel("Grafico andamento delle misure corporee")
            }
        }
        .clayCard()
    }

    private func measurementSummary(title: String, value: Double?) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.caption).foregroundStyle(ClientClay.secondaryInk)
            Text(value.map { "\($0.formatted()) cm" } ?? "—").font(.headline).foregroundStyle(ClientClay.ink)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ClientClay.surfaceDeep.opacity(0.62), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var runningSection: some View {
        let recent = Array(session.activity.runningResults.sorted { $0.completedAt > $1.completedAt }.prefix(3))
        return VStack(alignment: .leading, spacing: 14) {
            ClientSectionHeader(title: "Running", detail: "Ultime attività", symbol: "figure.run")
            ForEach(Array(recent.enumerated()), id: \.element.id) { index, result in
                HStack(spacing: 13) {
                    Image(systemName: "figure.run.circle.fill").font(.title2).foregroundStyle(ClientClay.accent)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(result.completedAt.formatted(date: .abbreviated, time: .omitted)).font(.subheadline.weight(.semibold))
                        Text(result.distanceKm.map { "\($0.formatted(.number.precision(.fractionLength(2)))) km" } ?? "Distanza non registrata")
                            .font(.caption).foregroundStyle(ClientClay.secondaryInk)
                    }
                    Spacer()
                    if let pace = result.averagePaceMinutesPerKm {
                        Text(paceText(pace)).font(.subheadline.monospacedDigit().weight(.bold)).foregroundStyle(ClientClay.ink)
                    }
                }
                if index < recent.count - 1 { Divider().opacity(0.35) }
            }
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
