import SwiftUI

/// Static vector anatomy. Subdivisions are illustrative, never invented exercise metadata.
struct ClientAnatomyMap: View {
    let primary: [ClientMuscleRegion]
    let secondary: [ClientMuscleRegion]
    var compact = false
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: ClientSpacing.control))
            : AnyLayout(HStackLayout(spacing: ClientSpacing.control))
        layout {
            projection(rear: false)
            projection(rear: true)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Mappa anteriore e posteriore. Principali: \(primary.map(\.displayName).joined(separator: ", ")). Secondari: \(secondary.map(\.displayName).joined(separator: ", ")). Nessuna percentuale di attivazione stimata.")
    }

    private func projection(rear: Bool) -> some View {
        VStack(spacing: 8) {
            Text(rear ? "Posteriore" : "Anteriore").font(.caption.weight(.semibold)).foregroundStyle(ClientClay.color(.textSecondary))
            Canvas { context, size in
                let head = CGRect(x: size.width * 0.41, y: size.height * 0.01, width: size.width * 0.18, height: size.height * 0.12)
                context.fill(Path(ellipseIn: head), with: .color(ClientClay.color(.textSecondary).opacity(0.25)))
                for part in Self.parts(rear: rear) {
                    for mirrored in (part.paired ? [false, true] : [false]) {
                        var path = Path()
                        let points = part.points.map { point in
                            CGPoint(x: size.width * (mirrored ? 1 - point.0 : point.0), y: size.height * point.1)
                        }
                        guard let start = points.first else { continue }
                        path.move(to: start)
                        for point in points.dropFirst() { path.addLine(to: point) }
                        path.closeSubpath()
                        context.fill(path, with: .color(color(for: part.group)))
                        context.stroke(path, with: .color(ClientClay.color(.backgroundPrimary)), style: StrokeStyle(lineWidth: 1.5, dash: part.group.map { secondary.contains($0) && !primary.contains($0) } == true ? [3, 2] : []))
                    }
                }
            }
            .frame(height: compact ? 148 : 208)
        }.frame(maxWidth: .infinity)
    }

    private func color(for group: ClientMuscleRegion?) -> Color {
        guard let group else { return ClientClay.color(.textSecondary).opacity(0.22) }
        if primary.contains(group) { return ClientClay.color(.workoutAccent) }
        if secondary.contains(group) { return ClientClay.color(.warning) }
        return ClientClay.color(.textSecondary).opacity(0.3)
    }

    private struct Part {
        let group: ClientMuscleRegion?
        let paired: Bool
        let points: [(Double, Double)]
    }

    private static func parts(rear: Bool) -> [Part] {
        // Left-side contours are mirrored, separating muscle bellies rather than rectangular blobs.
        var parts: [Part] = [
            Part(group: nil, paired: true, points: [(0.43,0.13),(0.48,0.13),(0.49,0.17),(0.41,0.18)]),
            Part(group: .shoulders, paired: true, points: [(0.32,0.17),(0.39,0.18),(0.38,0.25),(0.31,0.27),(0.26,0.23)]),
            // Lateral deltoid contour is distinct, but catalog only resolves the entire shoulders group.
            Part(group: .shoulders, paired: true, points: [(0.26,0.23),(0.30,0.27),(0.29,0.31),(0.23,0.29)]),
            Part(group: rear ? .triceps : .biceps, paired: true, points: [(0.29,0.28),(0.34,0.27),(0.32,0.36),(0.27,0.41),(0.23,0.39)]),
            Part(group: nil, paired: true, points: [(0.23,0.40),(0.27,0.42),(0.23,0.51),(0.19,0.57),(0.15,0.55),(0.17,0.47)]),
            Part(group: nil, paired: true, points: [(0.15,0.55),(0.19,0.57),(0.18,0.61),(0.14,0.62),(0.12,0.59)]),
            Part(group: rear ? .hamstrings : .quadriceps, paired: true, points: [(0.35,0.57),(0.48,0.59),(0.47,0.69),(0.44,0.78),(0.38,0.79),(0.33,0.67)]),
            // Distinct inner thigh head; no separate muscle coefficient is asserted.
            Part(group: rear ? .hamstrings : .quadriceps, paired: true, points: [(0.48,0.59),(0.49,0.71),(0.47,0.78),(0.44,0.78)]),
            Part(group: nil, paired: true, points: [(0.38,0.79),(0.44,0.79),(0.44,0.82),(0.38,0.82)]),
            Part(group: rear ? .calves : nil, paired: true, points: [(0.37,0.82),(0.44,0.82),(0.45,0.86),(0.42,0.93),(0.38,0.96),(0.35,0.89)]),
            Part(group: nil, paired: true, points: [(0.38,0.95),(0.42,0.94),(0.44,0.98),(0.34,0.99),(0.33,0.98)])
        ]
        if rear {
            parts += [
                // Trapezius/central back, posterior deltoids above, lateral lat contours below.
                Part(group: .upperBack, paired: true, points: [(0.48,0.14),(0.40,0.18),(0.38,0.23),(0.44,0.28),(0.49,0.30)]),
                Part(group: .upperBack, paired: true, points: [(0.44,0.28),(0.49,0.30),(0.49,0.37),(0.45,0.36),(0.40,0.30)]),
                Part(group: .lats, paired: true, points: [(0.37,0.25),(0.44,0.29),(0.45,0.36),(0.42,0.44),(0.37,0.42),(0.32,0.29)]),
                Part(group: nil, paired: true, points: [(0.45,0.36),(0.49,0.37),(0.49,0.48),(0.42,0.47)]),
                Part(group: .glutes, paired: true, points: [(0.39,0.47),(0.49,0.48),(0.49,0.58),(0.45,0.61),(0.35,0.57),(0.34,0.52)])
            ]
        } else {
            parts += [
                // Clavicular/sternal pectoral contours share catalog chest metadata.
                Part(group: .chest, paired: true, points: [(0.40,0.18),(0.49,0.18),(0.49,0.22),(0.39,0.24),(0.36,0.22)]),
                Part(group: .chest, paired: true, points: [(0.39,0.24),(0.49,0.23),(0.49,0.30),(0.43,0.32),(0.36,0.29),(0.34,0.25)]),
                Part(group: .core, paired: true, points: [(0.40,0.33),(0.43,0.32),(0.43,0.46),(0.39,0.49),(0.36,0.43)]),
                Part(group: .core, paired: true, points: [(0.44,0.32),(0.49,0.31),(0.49,0.36),(0.44,0.36)]),
                Part(group: .core, paired: true, points: [(0.44,0.37),(0.49,0.37),(0.49,0.41),(0.44,0.41)]),
                Part(group: .core, paired: true, points: [(0.44,0.42),(0.49,0.42),(0.49,0.47),(0.44,0.47)]),
                Part(group: nil, paired: true, points: [(0.39,0.49),(0.49,0.48),(0.49,0.58),(0.35,0.57),(0.35,0.52)])
            ]
        }
        return parts
    }
}
