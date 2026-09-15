import SwiftUI

struct ClientCircularProgress: View {
    let value: Double
    let total: Double
    let title: String
    let valueText: String
    let detail: String
    var tint = ClientClay.accent
    var size: CGFloat = 116
    var textColor = ClientClay.ink
    var detailColor = ClientClay.secondaryInk

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var progress: Double {
        guard total > 0 else { return 0 }
        return min(max(value / total, 0), 1)
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(ClientClay.surfaceElevated, style: StrokeStyle(lineWidth: 11, lineCap: .round))
            Circle()
                .trim(from: 0, to: progress)
                .stroke(tint, style: StrokeStyle(lineWidth: 11, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .shadow(color: tint.opacity(progress > 0 ? 0.28 : 0), radius: 6)
                .animation(reduceMotion ? nil : .easeOut(duration: 0.45), value: progress)
            VStack(spacing: 1) {
                Text(valueText)
                    .font(.system(.title3, design: .rounded, weight: .bold).monospacedDigit())
                    .foregroundStyle(textColor)
                    .minimumScaleFactor(0.65)
                    .lineLimit(1)
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(detailColor)
                    .lineLimit(1)
            }
            .padding(14)
        }
        .frame(width: size, height: size)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue("\(valueText), \(detail)")
    }
}

struct ClientCaloriePie: View {
    let value: Double
    let total: Double
    let valueText: String
    let detail: String
    var size: CGFloat = 108

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var progress: Double {
        guard total > 0 else { return 0 }
        return min(max(value / total, 0), 1)
    }

    var body: some View {
        ZStack {
            Circle().fill(ClientClay.surfaceElevated)
            ClientPieSlice(progress: progress)
                .fill(ClientClay.sage)
                .animation(reduceMotion ? nil : .easeOut(duration: 0.45), value: progress)
            Circle().stroke(ClientClay.border, lineWidth: 1)
            VStack(spacing: 1) {
                Text(valueText).font(.headline.monospacedDigit()).lineLimit(1).minimumScaleFactor(0.7)
                Text(detail).font(.caption2).foregroundStyle(ClientClay.secondaryInk).lineLimit(1)
            }
            .padding(8)
            .frame(width: size * 0.68, height: size * 0.68)
            .foregroundStyle(ClientClay.ink)
            .background(ClientClay.surface, in: Circle())
        }
        .frame(width: size, height: size)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Calorie completate")
        .accessibilityValue("\(valueText), \(detail)")
    }
}

private struct ClientPieSlice: Shape {
    var progress: Double

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        guard progress > 0 else { return Path() }
        let center = CGPoint(x: rect.midX, y: rect.midY)
        var path = Path()
        path.move(to: center)
        path.addArc(
            center: center,
            radius: min(rect.width, rect.height) / 2,
            startAngle: .degrees(-90),
            endAngle: .degrees(-90 + min(progress, 1) * 360),
            clockwise: false
        )
        path.closeSubpath()
        return path
    }
}
