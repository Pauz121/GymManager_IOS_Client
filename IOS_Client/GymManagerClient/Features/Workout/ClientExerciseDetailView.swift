import Charts
import SwiftUI

struct ClientExerciseDetailSheet: View {
    let plan: ClientWorkoutPlan
    let workout: ClientWorkoutSession
    let exercise: ClientExercise

    @EnvironmentObject private var session: ClientSessionStore
    @Environment(\.dismiss) private var dismiss

    private struct HistoryItem: Identifiable {
        let id: UUID
        let date: Date
        let completedSets: Int
        let totalSets: Int
        let load: Double?
        let note: String
    }

    private var history: [HistoryItem] {
        session.activity.workouts.compactMap { execution in
            guard let log = execution.exercises.first(where: { $0.exerciseID == exercise.id }) else { return nil }
            let completedSets = log.sets.filter(\.isCompleted)
            return HistoryItem(
                id: log.id,
                date: execution.completedAt ?? execution.startedAt,
                completedSets: completedSets.count,
                totalSets: log.sets.count,
                load: completedSets.compactMap(\.actualLoadKg).filter { $0 > 0 }.max(),
                note: log.note
            )
        }
        .sorted { $0.date > $1.date }
    }

    private var loadHistory: [ClientExerciseLoadPoint] {
        ClientActivityInsights.exerciseLoadHistory(exerciseID: exercise.id, state: session.activity)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: ClientSpacing.section) {
                    VStack(alignment: .leading, spacing: ClientSpacing.micro) {
                        Text(exercise.name).font(.title2.weight(.bold)).foregroundStyle(ClientClay.color(.textPrimary))
                        Text("\(workout.name) · \(plan.title) · Settimana \(plan.currentWeek)")
                            .font(.caption).foregroundStyle(ClientClay.color(.textSecondary))
                    }
                    ClientExerciseVisualCard(exercise: exercise, isResting: session.activity.restTimer?.exerciseID == exercise.id)
                    VStack(alignment: .leading, spacing: ClientSpacing.related) {
                        Text("Cosa fare oggi").font(.headline)
                        ClientExercisePrescriptionView(exercise: exercise)
                    }
                    VStack(alignment: .leading, spacing: ClientSpacing.related) {
                        Text("Storico personale").font(.headline)
                        if history.isEmpty && loadHistory.isEmpty {
                            Label("Ancora nessuna esecuzione. Serie, carichi e note compariranno qui.", systemImage: "clock")
                                .font(.subheadline).foregroundStyle(ClientClay.color(.textSecondary))
                        } else {
                            if let latest = loadHistory.last?.loadKg, let best = loadHistory.map(\.loadKg).max() {
                                ViewThatFits(in: .horizontal) {
                                    HStack(spacing: ClientSpacing.section) { loadMetrics(latest: latest, best: best) }
                                        .fixedSize(horizontal: true, vertical: false)
                                    VStack(alignment: .leading, spacing: ClientSpacing.related) { loadMetrics(latest: latest, best: best) }
                                }
                            }
                            loadProgressCard
                            ForEach(history.prefix(3)) { item in historyRow(item) }
                        }
                    }
                    if let notes = exercise.notes, !notes.isEmpty {
                        VStack(alignment: .leading, spacing: ClientSpacing.related) {
                            Text("Note operative").font(.headline)
                            Text(notes).font(.body).foregroundStyle(ClientClay.color(.textSecondary))
                        }
                    }
                }
                .foregroundStyle(ClientClay.color(.textPrimary))
                .padding(ClientSpacing.page)
                .anchorPreference(key: ClientWorkoutAvoidanceKey.self, value: .bounds) { [$0] }
            }
            .clientPage()
            .navigationTitle("Dettaglio esercizio")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Fine") { dismiss() } } }
        }
        .clientFloatingRestTimer()
    }

    @ViewBuilder private func loadMetrics(latest: Double, best: Double) -> some View {
        Text("Ultima sessione · massimo \(latest.formatted()) kg").font(.subheadline.monospacedDigit())
        Text("Migliore · \(best.formatted()) kg").font(.subheadline.monospacedDigit())
    }

    @ViewBuilder private var loadProgressCard: some View {
        if loadHistory.count > 1 {
            VStack(alignment: .leading, spacing: ClientSpacing.related) {
                Label("Carico massimo per sessione", systemImage: "chart.line.uptrend.xyaxis")
                    .font(.subheadline).foregroundStyle(ClientClay.color(.textSecondary))
                Chart(loadHistory) { item in
                        AreaMark(x: .value("Data", item.date), y: .value("Carico kg", item.loadKg))
                            .interpolationMethod(.catmullRom)
                            .foregroundStyle(LinearGradient(colors: [ClientClay.color(.workoutAccent).opacity(0.28), ClientClay.color(.workoutAccent).opacity(0.02)], startPoint: .top, endPoint: .bottom))
                        LineMark(x: .value("Data", item.date), y: .value("Carico kg", item.loadKg))
                            .interpolationMethod(.catmullRom)
                            .foregroundStyle(ClientClay.color(.workoutAccent))
                            .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                        PointMark(x: .value("Data", item.date), y: .value("Carico kg", item.loadKg))
                            .foregroundStyle(ClientClay.color(.brandAccentSoft))
                    }
                    .frame(height: 170)
                    .chartYAxisLabel("kg")
                    .chartPlotStyle { $0.background(ClientClay.color(.surfaceSecondary).opacity(0.55)).clipShape(RoundedRectangle(cornerRadius: 12)) }
                    .accessibilityLabel("Grafico del carico migliore registrato per sessione")
            }
        }
    }

    private var loadDelta: Double? {
        guard loadHistory.count > 1, let first = loadHistory.first?.loadKg, let last = loadHistory.last?.loadKg else { return nil }
        return last - first
    }

    private func historyRow(_ item: HistoryItem) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Label(item.date.formatted(date: .abbreviated, time: .omitted), systemImage: "calendar")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("\(item.completedSets)/\(item.totalSets) serie")
                    .font(.caption.weight(.bold)).foregroundStyle(item.completedSets == item.totalSets ? ClientClay.color(.success) : ClientClay.color(.warning))
            }
            if let load = item.load {
                Label("Carico massimo: \(load.formatted()) kg", systemImage: "scalemass")
                    .font(.caption).foregroundStyle(ClientClay.color(.textSecondary))
            }
            if !item.note.isEmpty {
                Label(item.note, systemImage: "note.text")
                    .font(.caption).foregroundStyle(ClientClay.color(.textSecondary))
            }
        }
        .padding(.vertical, ClientSpacing.related)
    }
}
