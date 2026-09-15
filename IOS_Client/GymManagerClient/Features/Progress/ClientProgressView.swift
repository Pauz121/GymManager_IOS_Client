import Charts
import SwiftUI

enum ClientProgressWeek {
    static func mondayToSunday(containing date: Date, calendar: Calendar = .autoupdatingCurrent) -> [Date] {
        var weekCalendar = calendar
        weekCalendar.firstWeekday = 2
        weekCalendar.minimumDaysInFirstWeek = 4
        guard let monday = weekCalendar.dateInterval(of: .weekOfYear, for: date)?.start else { return [] }
        return (0..<7).compactMap { weekCalendar.date(byAdding: .day, value: $0, to: monday) }
    }
}

struct ClientProgressView: View {
    let entries: [ClientProgressEntry]
    let identity: ClientIdentity
    let source: ClientDataSource

    @EnvironmentObject private var session: ClientSessionStore
    @EnvironmentObject private var healthKit: HealthKitStepService
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

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
        return ClientProgressWeek.mondayToSunday(containing: Date(), calendar: calendar).map { day in
            let gymCount = session.activity.workouts.filter { execution in
                guard let completedAt = execution.completedAt else { return false }
                return calendar.isDate(completedAt, inSameDayAs: day)
            }.count
            let runningCount = session.activity.runningResults.filter {
                calendar.isDate($0.completedAt, inSameDayAs: day)
            }.count
            return ActivityPoint(date: day, count: gymCount + runningCount)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                ClientPageTitle("Progressi", eyebrow: "La tua evoluzione", subtitle: "Trend e risultati reali, leggibili in un colpo d’occhio.")
                progressHero
                ClientSectionHeader(title: "Oggi", detail: "Attività quotidiana", symbol: "sun.max.fill")
                todayStepsCard
                ClientSectionHeader(title: "Riepilogo", detail: "Dati registrati", symbol: "square.grid.2x2.fill")
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
            .padding(.horizontal, ClientClay.pagePadding).padding(.vertical, 18)
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
                    Text(weights.isEmpty ? "PANORAMICA ATTIVITÀ" : "TENDENZA PESO")
                        .font(.caption.weight(.bold)).tracking(1.2).foregroundStyle(.white.opacity(0.66))
                    if let latest = weights.last, let value = latest.weightKg {
                        HStack(alignment: .firstTextBaseline, spacing: 7) {
                            Text(value.formatted(.number.precision(.fractionLength(1))))
                                .font(.system(size: 46, weight: .heavy, design: .rounded)).monospacedDigit().foregroundStyle(.white)
                            Text("kg").font(.headline).foregroundStyle(.white.opacity(0.62))
                        }
                        Text("Aggiornato il \(latest.recordedAt.formatted(date: .abbreviated, time: .omitted))")
                            .font(.subheadline).foregroundStyle(.white.opacity(0.68))
                    } else {
                        Text(completedWorkouts + session.activity.runningResults.count, format: .number)
                            .font(.system(size: 46, weight: .heavy, design: .rounded)).monospacedDigit().foregroundStyle(.white)
                        Text("sessioni registrate · aggiungi una rilevazione per costruire il trend")
                            .font(.subheadline).foregroundStyle(.white.opacity(0.68))
                    }
                }
                Spacer()
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.title2.weight(.semibold)).foregroundStyle(ClientClay.accentSoft)
                    .frame(width: 50, height: 50)
                    .background(.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            if let delta = recentWeightDelta {
                ClientDirectionalBadge(
                    text: "\(delta > 0 ? "+" : "")\(delta.formatted(.number.precision(.fractionLength(1)))) kg vs precedente",
                    direction: abs(delta) < 0.05 ? nil : delta.sign
                )
            } else if weights.count == 1 {
                ClientBadge(text: "Prima rilevazione", tint: ClientClay.inkSoft, symbol: "flag.fill")
            }
            HStack(spacing: 8) {
                compactHeroMetric(value: "\(completedWorkouts)", label: "workout")
                compactHeroMetric(value: session.activity.runningResults.isEmpty ? "—" : "\(session.activity.runningResults.count)", label: "corse")
                compactHeroMetric(value: entries.isEmpty ? "—" : "\(entries.count)", label: "rilevazioni")
            }
        }
        .premiumCard()
    }

    private var recentWeightDelta: Double? {
        guard weights.count > 1,
              let latest = weights.last?.weightKg,
              let previous = weights.dropLast().last?.weightKg else { return nil }
        return latest - previous
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
        LazyVGrid(columns: dynamicTypeSize.isAccessibilitySize ? [GridItem(.flexible())] : [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            ClientMetricTile(
                title: "Allenamenti",
                value: completedWorkouts.formatted(),
                detail: "Totale completati su questo iPhone",
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
            ClientMetricTile(
                title: "Corse salvate",
                value: session.activity.runningResults.count.formatted(),
                detail: "Sessioni running registrate",
                symbol: "figure.run.circle.fill",
                tint: ClientClay.gold
            )
            ClientMetricTile(
                title: "Rilevazioni",
                value: entries.count.formatted(),
                detail: "Peso e misure nel tempo",
                symbol: "ruler.fill",
                tint: ClientClay.accentSoft
            )
        }
    }

    private var todayStepsCard: some View {
        HStack(spacing: 18) {
            ClientCircularProgress(
                value: Double(todaySteps ?? 0), total: 10_000, title: "Passi oggi",
                valueText: todaySteps?.formatted() ?? "—", detail: "di 10.000",
                tint: todaySteps.map { $0 >= 10_000 ? ClientClay.sage : ClientClay.gold } ?? ClientClay.tertiaryInk,
                size: 96
            )
            VStack(alignment: .leading, spacing: 6) {
                Text("PASSI ODIERNI").font(.caption.weight(.bold)).tracking(1).foregroundStyle(ClientClay.gold)
                Text(todaySteps == nil ? "Dato non disponibile" : "Movimento di oggi")
                    .font(.title3.weight(.bold)).foregroundStyle(ClientClay.ink)
                Text(todaySteps == nil ? "Collega Apple Salute dalla Home." : source == .demo ? "Dati demo · nessun dato reale" : "Sincronizzati con Apple Salute")
                    .font(.caption).foregroundStyle(ClientClay.secondaryInk)
            }
        }
        .clayCard()
    }

    private var weeklyWorkoutChart: some View {
        VStack(alignment: .leading, spacing: 14) {
            ClientSectionHeader(title: "Settimana corrente", detail: "Lunedì – Domenica", symbol: "calendar.badge.checkmark")
            Chart(weeklyActivity) { point in
                BarMark(x: .value("Giorno", point.date, unit: .day), y: .value("Allenamenti", point.count))
                    .foregroundStyle(LinearGradient(colors: [ClientClay.accent, ClientClay.accent.opacity(0.55)], startPoint: .top, endPoint: .bottom))
                    .cornerRadius(6)
            }
            .chartYScale(domain: 0...max(1, weeklyActivity.map(\.count).max() ?? 1))
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) { _ in
                    AxisValueLabel(format: .dateTime.weekday(.narrow))
                        .foregroundStyle(ClientClay.secondaryInk)
                    AxisGridLine().foregroundStyle(.clear)
                }
            }
            .chartYAxis(.hidden)
            .chartPlotStyle { plotArea in plotArea.background(ClientClay.inset.opacity(0.55), in: RoundedRectangle(cornerRadius: 12)) }
            .frame(height: 130)
            .accessibilityLabel("Attività completate nella settimana da lunedì a domenica")
        }
        .clayCard()
    }

    private var weightSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            ClientSectionHeader(title: "Andamento peso", detail: "kg", symbol: "scalemass.fill")
            if let latest = weights.last, let value = latest.weightKg {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(value.formatted()).font(.system(size: 38, weight: .heavy, design: .rounded)).monospacedDigit()
                    Text("kg").font(.headline).foregroundStyle(ClientClay.secondaryInk)
                    Spacer()
                    if let delta = recentWeightDelta {
                        ClientDirectionalBadge(text: weightDeltaText ?? "", direction: abs(delta) < 0.05 ? nil : delta.sign)
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
                            .interpolationMethod(.catmullRom)
                        PointMark(x: .value("Data", entry.recordedAt), y: .value("Peso", value))
                            .foregroundStyle(ClientClay.accent).symbolSize(48)
                    }
                }
                .chartXAxis { AxisMarks(values: .automatic(desiredCount: 4)) { _ in AxisValueLabel(format: .dateTime.day().month(.abbreviated)).foregroundStyle(ClientClay.secondaryInk); AxisGridLine().foregroundStyle(.clear) } }
                .chartYAxis { AxisMarks(position: .trailing) { _ in AxisGridLine().foregroundStyle(ClientClay.border); AxisValueLabel().foregroundStyle(ClientClay.secondaryInk) } }
                .chartPlotStyle { plotArea in plotArea.background(ClientClay.inset.opacity(0.55), in: RoundedRectangle(cornerRadius: 12)) }
                .frame(height: 210)
                .accessibilityLabel("Grafico andamento del peso")
            }
        }
        .clayCard()
    }

    private var weightDeltaText: String? {
        guard let delta = recentWeightDelta else { return nil }
        return "\(delta > 0 ? "+" : "")\(delta.formatted(.number.precision(.fractionLength(1)))) kg vs precedente"
    }

    private var measurementsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            ClientSectionHeader(title: "Misure corporee", detail: "cm", symbol: "ruler.fill")
            ViewThatFits {
                HStack(spacing: 10) {
                    measurementSummary(title: "Vita", value: latestWaist)
                    measurementSummary(title: "Fianchi", value: latestHips)
                }
                VStack(spacing: 10) {
                    measurementSummary(title: "Vita", value: latestWaist)
                    measurementSummary(title: "Fianchi", value: latestHips)
                }
            }
            if Set(measurements.map(\.date)).count > 1 {
                Chart(measurements) { point in
                    LineMark(x: .value("Data", point.date), y: .value("Centimetri", point.value))
                        .foregroundStyle(by: .value("Misura", point.kind))
                        .lineStyle(point.kind == "Vita" ? StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round) : StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round, dash: [5, 3]))
                    PointMark(x: .value("Data", point.date), y: .value("Centimetri", point.value))
                        .foregroundStyle(by: .value("Misura", point.kind))
                }
                .chartForegroundStyleScale(["Vita": ClientClay.accent, "Fianchi": ClientClay.sage])
                .chartXAxis { AxisMarks(values: .automatic(desiredCount: 4)) { _ in AxisValueLabel(format: .dateTime.day().month(.abbreviated)).foregroundStyle(ClientClay.secondaryInk); AxisGridLine().foregroundStyle(.clear) } }
                .chartYAxis { AxisMarks(position: .trailing) { _ in AxisGridLine().foregroundStyle(ClientClay.border); AxisValueLabel().foregroundStyle(ClientClay.secondaryInk) } }
                .chartPlotStyle { plotArea in plotArea.background(ClientClay.inset.opacity(0.55), in: RoundedRectangle(cornerRadius: 12)) }
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
        .background(ClientClay.inset, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(ClientClay.border) }
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
