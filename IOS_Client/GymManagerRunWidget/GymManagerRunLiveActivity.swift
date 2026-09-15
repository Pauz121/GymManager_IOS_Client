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
                .activityBackgroundTint(background)
                .activitySystemActionForegroundColor(accent)
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
                    .font(.caption).foregroundStyle(.white)
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
                if context.state.isPaused {
                    Label("In pausa", systemImage: "pause.fill")
                        .font(.caption.weight(.semibold)).foregroundStyle(.white)
                        .padding(.horizontal, 9).padding(.vertical, 5)
                        .background(accent.opacity(0.28), in: Capsule())
                }
            }
            HStack(spacing: 12) {
                metric("Km", value: distance(context.state), symbol: "location.fill")
                timerMetric(context.state)
                metric(context.state.displayMode == "speed" ? "Media km/h" : "Media min/km", value: average(context.state), symbol: "speedometer")
            }
        }
        .padding(16)
        .foregroundStyle(.white)
    }

    private func metric(_ title: String, value: String, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Label(title, systemImage: symbol).font(.caption2.weight(.semibold)).foregroundStyle(.white.opacity(0.72))
            Text(value).font(.headline.monospacedDigit()).foregroundStyle(.white).minimumScaleFactor(0.65).lineLimit(1)
        }
        .padding(.horizontal, 9).padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 11, style: .continuous).stroke(accent.opacity(0.26)) }
    }

    private func timerMetric(_ state: ClientRunActivityAttributes.ContentState) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Label("Tempo", systemImage: "timer").font(.caption2.weight(.semibold)).foregroundStyle(.white.opacity(0.72))
            elapsedView(state).font(.headline.monospacedDigit()).foregroundStyle(.white).minimumScaleFactor(0.65).lineLimit(1)
        }
        .padding(.horizontal, 9).padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 11, style: .continuous).stroke(accent.opacity(0.26)) }
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

    private var background: Color { Color(red: 0.035, green: 0.035, blue: 0.043) }
    private var accent: Color { Color(red: 1.000, green: 0.255, blue: 0.180) }
}
