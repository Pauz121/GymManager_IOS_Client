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

    @State private var period: ClientProgressPeriod = .month
    @State private var selectedWeightDate: Date?

    private struct MeasurementPoint: Identifiable {
        let id: String
        let date: Date
        let value: Double
        let kind: String
    }

    private enum ActivityKind: String {
        case gym = "Palestra"
        case running = "Corsa"
    }

    private struct ActivityPoint: Identifiable {
        let date: Date
        let count: Int
        let kind: ActivityKind
        var id: String { "\(date.timeIntervalSince1970)-\(kind.rawValue)" }
    }

    private struct ActivityHeatmapPoint: Identifiable {
        let date: Date
        let week: Int
        let weekday: Int
        let gymCount: Int
        let runningCount: Int
        var total: Int { gymCount + runningCount }
        var id: Date { date }
    }

    private var weights: [ClientProgressEntry] {
        ClientProgressPresentation.weights(entries, period: period)
    }

    private var latestWaist: Double? {
        periodEntries.sorted { $0.recordedAt > $1.recordedAt }.compactMap(\.waistCm).first
    }

    private var latestHips: Double? {
        entries.sorted { $0.recordedAt > $1.recordedAt }.compactMap(\.hipsCm).first
    }

    private var completedWorkouts: Int {
        session.activity.workouts.filter { $0.completedAt.map { period.contains($0) } == true }.count
    }

    private var totalRunningDistance: Double {
        periodRuns.compactMap(\.distanceKm).filter { $0.isFinite && $0 >= 0 }.reduce(0, +)
    }

    private var todaySteps: Int? {
        if let demoSteps { return demoSteps }
        if case .ready(let sample) = healthKit.state { return sample.count }
        return nil
    }

    private var measurements: [MeasurementPoint] {
        periodEntries.flatMap { entry in
            var result: [MeasurementPoint] = []
            if let waist = entry.waistCm, waist.isFinite, waist > 0 {
                result.append(MeasurementPoint(id: "vita-\(entry.id)", date: entry.recordedAt, value: waist, kind: "Vita"))
            }
            if let hips = entry.hipsCm, hips.isFinite, hips > 0 {
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
            return [
                ActivityPoint(date: day, count: gymCount, kind: .gym),
                ActivityPoint(date: day, count: runningCount, kind: .running),
            ]
        }
        .flatMap { $0 }
    }

    private var activityHeatmap: [ActivityHeatmapPoint] {
        let calendar = Calendar.autoupdatingCurrent
        guard let currentMonday = ClientProgressWeek.mondayToSunday(containing: Date(), calendar: calendar).first,
              let start = calendar.date(byAdding: .weekOfYear, value: -15, to: currentMonday) else { return [] }
        return (0..<(16 * 7)).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: offset, to: start) else { return nil }
            let gymCount = session.activity.workouts.filter { execution in
                guard let completedAt = execution.completedAt else { return false }
                return calendar.isDate(completedAt, inSameDayAs: day)
            }.count
            let runningCount = session.activity.runningResults.filter {
                calendar.isDate($0.completedAt, inSameDayAs: day)
            }.count
            return ActivityHeatmapPoint(date: day, week: offset / 7, weekday: offset % 7, gymCount: gymCount, runningCount: runningCount)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                ClientPageTitle("Progressi", eyebrow: "La tua evoluzione", subtitle: "Trend e risultati reali, leggibili in un colpo d’occhio.")
                if session.contentState(for: .progress).isPending {
                    ProgressView("Caricamento progressi").frame(maxWidth: .infinity, alignment: .leading)
                }
                if let message = session.contentState(for: .progress).failure {
                    ClientContentFailureCard(title: "Progressi", message: message, isRefreshing: session.isRefreshing) {
                        Task { await session.refresh() }
                    }
                }
                Picker("Periodo dei progressi", selection: $period) {
                    ForEach(ClientProgressPeriod.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .onChange(of: period) { _, _ in selectedWeightDate = nil }
                if !weights.isEmpty { weightSection }
                else if !session.contentState(for: .progress).isPending, session.contentState(for: .progress).failure == nil {
                    Label("Nessun peso registrato nel periodo scelto.", systemImage: "scalemass").font(.subheadline).foregroundStyle(ClientClay.secondaryInk)
                }
                if !measurements.isEmpty { measurementsSection }
                Text("Composizione corporea e foto progresso non sono disponibili in questa versione Client.")
                    .font(.footnote).foregroundStyle(ClientClay.secondaryInk)
                ClientSectionHeader(title: "Allenamento", detail: period.title, symbol: "dumbbell")
                Text("\(completedWorkouts) sessioni in palestra · \(periodRuns.count) corse")
                    .font(.headline).foregroundStyle(ClientClay.ink)
                Text("Attività registrate su questo iPhone. La settimana corrente e la costanza restano visibili sotto.")
                    .font(.footnote).foregroundStyle(ClientClay.secondaryInk)
                weeklyWorkoutChart
                activityHeatmapChart
                if !periodRuns.isEmpty { runningSection }
                todayStepsCard

            }
            .padding(.horizontal, ClientClay.pagePadding).padding(.vertical, 18)
        }
        .clientPage()
        .navigationTitle("Progressi")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await session.refresh() }
        .task { await healthKit.refreshIfPreviouslyRequested() }
    }

    private var periodEntries: [ClientProgressEntry] {
        entries.filter { period.contains($0.recordedAt) }
    }
    private var periodRuns: [ClientRunningResult] {
        session.activity.runningResults.filter { period.contains($0.completedAt) }
    }
    private var recentWeightDelta: Double? { ClientProgressPresentation.delta(weights) }

    private var weightChartDomain: ClosedRange<Double> {
        let values = weights.compactMap(\.weightKg)
        guard let minimum = values.min(), let maximum = values.max() else { return 0...1 }
        let padding = max(0.8, (maximum - minimum) * 0.18)
        return max(0, minimum - padding)...(maximum + padding)
    }

    private var todayStepsCard: some View {
        LabeledContent {
            Text(todaySteps?.formatted() ?? "Non disponibili").monospacedDigit()
        } label: {
            Label("Passi di oggi", systemImage: "figure.walk")
        }
        .font(.subheadline)
        .foregroundStyle(ClientClay.ink)
        .padding(.vertical, 8)
        .accessibilityHint(source == .demo ? "Dati dimostrativi" : "Dato letto da Apple Salute; collega Salute dalla Home se non disponibile")
    }

    private var weeklyWorkoutChart: some View {
        VStack(alignment: .leading, spacing: 14) {
            ClientSectionHeader(title: "Settimana corrente", detail: "Lunedì – Domenica · Palestra vs corsa", symbol: "chart.bar.xaxis")
            HStack(spacing: 14) {
                activityLegend("Palestra", tint: ClientClay.accent)
                activityLegend("Corsa", tint: ClientClay.runAccent)
            }
            Chart(weeklyActivity) { point in
                BarMark(x: .value("Giorno", point.date, unit: .day), y: .value("Allenamenti", point.count))
                    .foregroundStyle(by: .value("Tipo", point.kind.rawValue))
                    .position(by: .value("Tipo", point.kind.rawValue))
                    .cornerRadius(6)
            }
            .chartForegroundStyleScale([
                ActivityKind.gym.rawValue: ClientClay.accent,
                ActivityKind.running.rawValue: ClientClay.runAccent,
            ])
            .chartLegend(.hidden)
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
            .frame(height: 145)
            .accessibilityLabel("Confronto tra allenamenti in palestra e corse nella settimana da lunedì a domenica")
        }
        .clayCard()
    }

    private var activityHeatmapChart: some View {
        VStack(alignment: .leading, spacing: 14) {
            ClientSectionHeader(title: "Costanza", detail: "Ultime 16 settimane", symbol: "square.grid.3x3.fill")
            Chart(activityHeatmap) { point in
                RectangleMark(
                    x: .value("Settimana", point.week),
                    y: .value("Giorno", point.weekday),
                    width: .ratio(0.82),
                    height: .ratio(0.82)
                )
                .foregroundStyle(heatmapColor(for: point))
                .cornerRadius(3)
            }
            .chartXAxis(.hidden)
            .chartYAxis {
                AxisMarks(values: [0, 2, 4, 6]) { value in
                    AxisValueLabel {
                        if let weekday = value.as(Int.self) {
                            Text(["L", "M", "M", "G", "V", "S", "D"][weekday])
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(ClientClay.secondaryInk)
                        }
                    }
                    AxisGridLine().foregroundStyle(.clear)
                }
            }
            .chartPlotStyle { plotArea in
                plotArea.background(ClientClay.inset.opacity(0.34), in: RoundedRectangle(cornerRadius: 12))
            }
            .frame(height: 132)
            .accessibilityLabel("Mappa delle attività completate nelle ultime sedici settimane")
            HStack(spacing: 12) {
                activityLegend("Riposo", tint: ClientClay.border)
                activityLegend("Palestra", tint: ClientClay.accent)
                activityLegend("Corsa", tint: ClientClay.runAccent)
                activityLegend("Entrambi", tint: ClientClay.sage)
            }
            .font(.caption2)
        }
        .clayCard()
    }

    private func activityLegend(_ title: String, tint: Color) -> some View {
        HStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 3).fill(tint).frame(width: 10, height: 10)
            Text(title).font(.caption2.weight(.semibold)).foregroundStyle(ClientClay.secondaryInk)
        }
    }

    private func heatmapColor(for point: ActivityHeatmapPoint) -> Color {
        if point.gymCount > 0, point.runningCount > 0 { return ClientClay.sage }
        if point.gymCount > 0 { return ClientClay.accent.opacity(min(1, 0.55 + Double(point.gymCount - 1) * 0.18)) }
        if point.runningCount > 0 { return ClientClay.runAccent.opacity(min(1, 0.55 + Double(point.runningCount - 1) * 0.18)) }
        return ClientClay.border.opacity(0.72)
    }

    private var weightSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            ClientSectionHeader(title: "Andamento peso", detail: "kg", symbol: "scalemass.fill")
            if let latest = weights.last, let value = latest.weightKg {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(value.formatted(.number.precision(.fractionLength(1)))).font(.system(.largeTitle, design: .rounded, weight: .bold)).monospacedDigit()
                    Text("kg").font(.headline).foregroundStyle(ClientClay.secondaryInk)
                    Spacer()
                }
                if let delta = recentWeightDelta {
                    ClientDirectionalBadge(text: weightDeltaText ?? "", direction: abs(delta) < 0.05 ? nil : delta.sign)
                }
            }
            if let previous = weights.dropLast().last, let value = previous.weightKg {
                Text("Precedente: \(value.formatted(.number.precision(.fractionLength(1)))) kg · \(previous.recordedAt.formatted(date: .abbreviated, time: .omitted))")
                    .font(.subheadline).foregroundStyle(ClientClay.secondaryInk)
            }
            if let first = weights.first, let last = weights.last {
                Text("\(first.recordedAt.formatted(date: .abbreviated, time: .omitted)) – \(last.recordedAt.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption).foregroundStyle(ClientClay.secondaryInk)
            }
            if let date = selectedWeightDate, let entry = ClientProgressPresentation.nearest(to: date, in: weights), let value = entry.weightKg {
                Text("\(entry.recordedAt.formatted(date: .abbreviated, time: .omitted)): \(value.formatted()) kg")
                    .font(.subheadline.monospacedDigit()).foregroundStyle(ClientClay.ink)
            }
            if weights.count > 1 {
                Chart(weights) { entry in
                    if let value = entry.weightKg {
                        AreaMark(x: .value("Data", entry.recordedAt), y: .value("Peso", value))
                            .foregroundStyle(LinearGradient(colors: [ClientClay.accent.opacity(0.3), ClientClay.accent.opacity(0.02)], startPoint: .top, endPoint: .bottom))
                        LineMark(x: .value("Data", entry.recordedAt), y: .value("Peso", value))
                            .foregroundStyle(ClientClay.accent).lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                            .interpolationMethod(.linear)
                        PointMark(x: .value("Data", entry.recordedAt), y: .value("Peso", value))
                            .foregroundStyle(ClientClay.accent).symbolSize(48)
                    }
                }
                .clientMeasurementChart()
                .chartXSelection(value: $selectedWeightDate)
                .chartYScale(domain: weightChartDomain)
                .chartPlotStyle { plotArea in plotArea.background(ClientClay.inset.opacity(0.55), in: RoundedRectangle(cornerRadius: 12)) }
                .frame(height: 210)
                .accessibilityLabel("Grafico andamento del peso")
                .accessibilityValue(weights.map { "\($0.recordedAt.formatted(date: .abbreviated, time: .omitted)): \($0.weightKg?.formatted() ?? "—") kg" }.joined(separator: "; "))
            } else {
                Text("Aggiungi una seconda rilevazione per vedere il trend.").font(.footnote).foregroundStyle(ClientClay.secondaryInk)
            }
        }
        .padding(.vertical, 8)
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
            if Dictionary(grouping: measurements, by: \.kind).values.contains(where: { Set($0.map(\.date)).count > 1 }) {
                Chart(measurements) { point in
                    LineMark(x: .value("Data", point.date), y: .value("Centimetri", point.value))
                        .foregroundStyle(by: .value("Misura", point.kind))
                        .lineStyle(point.kind == "Vita" ? StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round) : StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round, dash: [5, 3]))
                    PointMark(x: .value("Data", point.date), y: .value("Centimetri", point.value))
                        .foregroundStyle(by: .value("Misura", point.kind))
                }
                .chartForegroundStyleScale(["Vita": ClientClay.accent, "Fianchi": ClientClay.sage])
                .clientMeasurementChart()
                .chartPlotStyle { plotArea in plotArea.background(ClientClay.inset.opacity(0.55), in: RoundedRectangle(cornerRadius: 12)) }
                .frame(height: 200)
                .accessibilityLabel("Grafico andamento delle misure corporee")
            }
        }
        .padding(.vertical, 8)
    }

    private func measurementSummary(title: String, value: Double?) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.caption).foregroundStyle(ClientClay.secondaryInk)
            Text(value.map { "\($0.formatted()) cm" } ?? "—").font(.headline).foregroundStyle(ClientClay.ink)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var runningSection: some View {
        let recent = Array(periodRuns.sorted { $0.completedAt > $1.completedAt }.prefix(3))
        return VStack(alignment: .leading, spacing: 14) {
            ClientSectionHeader(title: "Running", detail: "\(totalRunningDistance.formatted(.number.precision(.fractionLength(1)))) km nel periodo", symbol: "figure.run")
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
