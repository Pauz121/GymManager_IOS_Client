import AVKit
import SwiftUI

struct ClientExerciseVisualCard: View {
    let exercise: ClientExercise
    var isResting = false
    var showsAnatomy = true
    private enum Mode: String, CaseIterable { case movement = "Movimento", muscles = "Muscoli" }
    @State private var mode: Mode = .movement
    private var muscles: ClientExerciseMusclePresentation { .init(exercise: exercise) }

    var body: some View {
        VStack(alignment: .leading, spacing: ClientSpacing.control) {
            if showsAnatomy {
                ClientCompactSelector(values: Mode.allCases, selection: $mode,
                                      title: { $0.rawValue }, accessibilityTitle: "Guida esercizio")
            }
            if mode == .movement || !showsAnatomy {
                if let url = ClientExerciseMediaPipeline.approvedURL(for: exercise.animationKey) {
                    ClientApprovedExerciseVideo(url: url, isResting: isResting)
                } else {
                    ClientAnatomyMap(primary: muscles.primary, secondary: muscles.secondary, compact: true)
                    Text("Guida anatomica statica, non una dimostrazione del movimento.")
                        .font(.caption).foregroundStyle(ClientClay.color(.textSecondary))
                }
                if let technique = exercise.technique, !technique.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(technique).font(.body).foregroundStyle(ClientClay.color(.textPrimary))
                } else {
                    Text("Indicazioni tecniche non presenti nel catalogo. Consulta una dimostrazione affidabile prima di eseguire il movimento.")
                        .font(.subheadline).foregroundStyle(ClientClay.color(.textSecondary))
                }
                if let videoURL = exercise.videoURL, videoURL.scheme?.lowercased() == "https" {
                    Link(destination: videoURL) {
                        Label("Apri il video dell’esercizio", systemImage: "play.rectangle")
                            .frame(minHeight: ClientControlSize.minimumTarget)
                    }.font(.subheadline.weight(.semibold)).tint(ClientClay.color(.brandAccent))
                }
            } else {
                ClientAnatomyMap(primary: muscles.primary, secondary: muscles.secondary)
                roleRow("Principali", names: muscles.primary.map(\.displayName), tint: .workoutAccent)
                roleRow("Secondari", names: muscles.secondary.map(\.displayName), tint: .warning)
                roleRow("Accessori", names: [], tint: .textSecondary)
                if !muscles.unclassified.isEmpty {
                    roleRow("Ruolo non definito", names: muscles.unclassified, tint: .textSecondary)
                }
                Text("Gruppi del catalogo condiviso. Accessori non classificati; nessuna percentuale di attivazione stimata.")
                    .font(.caption).foregroundStyle(ClientClay.color(.textSecondary))
            }
            if let level = exercise.difficultyLevel {
                Label("Livello tecnico: \(level.displayName)", systemImage: "graduationcap")
                    .font(.caption).foregroundStyle(ClientClay.color(.textSecondary))
            }
        }
        .padding(ClientSpacing.control)
        .background(ClientClay.color(.surfaceSecondary), in: RoundedRectangle(cornerRadius: ClientRadius.control))
        .accessibilityElement(children: .contain)
        .onChange(of: exercise.id) { _, _ in mode = .movement }
    }

    private func roleRow(_ title: String, names: [String], tint: ClientColorRole) -> some View {
        VStack(alignment: .leading, spacing: ClientSpacing.micro) {
            Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(ClientClay.color(tint))
            Text(names.isEmpty ? "Non classificati nel catalogo" : names.joined(separator: " · "))
                .font(.subheadline).foregroundStyle(ClientClay.color(.textPrimary))
        }.accessibilityElement(children: .combine)
    }
}

private struct ClientApprovedExerciseVideo: View {
    let url: URL
    let isResting: Bool
    @State private var player: AVPlayer?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        VideoPlayer(player: player)
            .frame(height: 220)
            .clipShape(RoundedRectangle(cornerRadius: ClientRadius.compact))
            .accessibilityLabel("Video tecnico dell’esercizio, controlli di riproduzione")
            .task(id: url) { player?.pause(); player = AVPlayer(url: url) } // User starts playback; no auto-loop.
            .onChange(of: isResting) { _, resting in if resting { player?.pause() } }
            .onChange(of: reduceMotion) { _, reduced in if reduced { player?.pause() } }
            .onDisappear { player?.pause() }
    }
}
