import ActivityKit
import SwiftUI
import WidgetKit

struct ClientRestLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ClientRestActivityAttributes.self) { context in
            HStack(spacing: 16) {
                Image(systemName: "timer").font(.title2).foregroundStyle(.cyan)
                VStack(alignment: .leading, spacing: 4) {
                    Text(context.attributes.title).font(.headline)
                    if let name = context.state.exerciseName { Text(name).font(.subheadline) }
                    if let number = context.state.nextSetNumber { Text("Prossima: serie \(number)").font(.caption) }
                }
                Spacer()
                countdown(context).font(.title2.monospacedDigit())
            }
            .foregroundStyle(.white).padding(16)
            .activityBackgroundTint(.black)
            .activitySystemActionForegroundColor(.cyan)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) { Label("Recupero", systemImage: "timer").foregroundStyle(.cyan) }
                DynamicIslandExpandedRegion(.trailing) { countdown(context).monospacedDigit() }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(context.state.exerciseName ?? "Prossima serie").font(.caption)
                }
            } compactLeading: {
                Image(systemName: "timer").foregroundStyle(.cyan)
            } compactTrailing: {
                countdown(context).font(.caption2.monospacedDigit())
            } minimal: {
                Image(systemName: "timer").foregroundStyle(.cyan)
            }.keylineTint(.cyan)
        }
    }

    @ViewBuilder private func countdown(_ context: ActivityViewContext<ClientRestActivityAttributes>) -> some View {
        if context.state.finished || context.isStale {
            Text("Pronto")
        } else if let paused = context.state.pausedSeconds {
            Text("\(paused)s · Pausa")
        } else if let end = context.state.endsAt, end > Date() {
            Text(timerInterval: Date()...end, countsDown: true, showsHours: false)
        } else {
            Text("Pronto")
        }
    }
}
