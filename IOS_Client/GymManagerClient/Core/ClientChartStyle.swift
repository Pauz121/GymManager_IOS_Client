import Charts
import SwiftUI

// Shared native chart chrome. Domain colors stay with each real series.
struct ClientMeasurementChartModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                    AxisValueLabel(format: .dateTime.day().month(.abbreviated)).foregroundStyle(ClientClay.secondaryInk)
                    AxisGridLine().foregroundStyle(.clear)
                }
            }
            .chartYAxis {
                AxisMarks(position: .trailing) { _ in
                    AxisGridLine().foregroundStyle(ClientClay.border)
                    AxisValueLabel().foregroundStyle(ClientClay.secondaryInk)
                }
            }
    }
}

extension View {
    func clientMeasurementChart() -> some View { modifier(ClientMeasurementChartModifier()) }
}
