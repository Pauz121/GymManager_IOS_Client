import ActivityKit
import Foundation
import SwiftUI
import WidgetKit

@main
struct GymManagerRunWidgetBundle: WidgetBundle {
    var body: some Widget {
        GymManagerRunLiveActivity()
    }
}

struct GymManagerRunLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ClientRunActivityAttributes.self) { context in
            lockScreen(context)
                .activityBackgroundTint(Color(red: 0.973, green: 0.965, blue: 0.941))
                .activitySystemActionForegroundColor(Color(red: 0.757, green: 0.231, blue: 0.161))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) { metric("Distanza", value: distance(context.state), symbol: "location.fill") }
                DynamicIslandExpandedRegion(.trailing) { timerMetric(context.state) }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Label(context.attributes.planTitle, systemImage: "figure.run")
                        Spacer()
                        Text(average(context.state)).monospacedDigit().fontWeight(.semibold)
                    }
                    .font(.caption)
                }
            } compactLeading: {
                Image(systemName: "figure.run").foregroundStyle(accent)
            } compactTrailing: {
                elapsedView(context.state).font(.caption2.monospacedDigit())
            } minimal: {
                Image(systemName: "figure.run").foregroundStyle(accent)
            }
            .keylineTint(accent)
        }
    }

    private func lockScreen(_ context: ActivityViewContext<ClientRunActivityAttributes>) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(context.attributes.planTitle, systemImage: "figure.run")
                    .font(.headline).foregroundStyle(accent)
                Spacer()
                if context.state.isPaused { Label("In pausa", systemImage: "pause.fill").font(.caption.weight(.semibold)) }
            }
            HStack(spacing: 12) {
                metric("Km", value: distance(context.state), symbol: "location.fill")
                timerMetric(context.state)
                metric(context.state.displayMode == "speed" ? "Media km/h" : "Media min/km", value: average(context.state), symbol: "speedometer")
            }
        }
        .padding(16)
    }

    private func metric(_ title: String, value: String, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Label(title, systemImage: symbol).font(.caption2).foregroundStyle(.secondary)
            Text(value).font(.headline.monospacedDigit()).minimumScaleFactor(0.65).lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func timerMetric(_ state: ClientRunActivityAttributes.ContentState) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Label("Tempo", systemImage: "timer").font(.caption2).foregroundStyle(.secondary)
            elapsedView(state).font(.headline.monospacedDigit()).minimumScaleFactor(0.65).lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func distance(_ state: ClientRunActivityAttributes.ContentState) -> String {
        "\((state.distanceMeters / 1_000).formatted(.number.precision(.fractionLength(2)))) km"
    }

    @ViewBuilder private func elapsedView(_ state: ClientRunActivityAttributes.ContentState) -> some View {
        if let anchor = state.timerAnchor {
            Text(timerInterval: anchor...Date.distantFuture, countsDown: false, showsHours: true)
        } else {
            Text(formatDuration(state.elapsedSeconds))
        }
    }

    private func average(_ state: ClientRunActivityAttributes.ContentState) -> String {
        if state.displayMode == "speed" {
            return state.averageSpeedKmh.map { "\($0.formatted(.number.precision(.fractionLength(1))))" } ?? "--"
        }
        guard let seconds = state.averagePaceSecondsPerKm else { return "--'--\"" }
        return String(format: "%d'%02d\"", seconds / 60, seconds % 60)
    }

    private func formatDuration(_ seconds: Int) -> String {
        String(format: "%02d:%02d:%02d", seconds / 3_600, seconds / 60 % 60, seconds % 60)
    }

    private var accent: Color { Color(red: 0.757, green: 0.231, blue: 0.161) }
}
