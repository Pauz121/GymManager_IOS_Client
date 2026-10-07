import SwiftUI

struct ClientExerciseVisualCard: View {
    let exercise: ClientExercise
    var isResting = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isPaused = false

    private var descriptor: ClientExerciseVisualDescriptor {
        ClientExerciseVisualResolver().resolve(exercise)
    }

    private var effectivePause: Bool { isPaused || isResting || reduceMotion || !descriptor.isAnimated }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(descriptor.isAnimated ? "MOVIMENTO" : "GUIDA MUSCOLARE")
                        .font(.caption2.weight(.bold)).tracking(1.15).foregroundStyle(ClientClay.accent)
                    Text(descriptor.viewAngle.displayName)
                        .font(.caption).foregroundStyle(ClientClay.secondaryInk)
                }
                Spacer()
                if descriptor.isAnimated {
                    Button {
                        isPaused.toggle()
                        ClientHaptics.selection()
                    } label: {
                        Label(isPaused ? "Riprendi" : "Pausa", systemImage: isPaused ? "play.fill" : "pause.fill")
                            .font(.caption.weight(.bold)).frame(minHeight: 44)
                    }
                    .buttonStyle(.bordered).tint(ClientClay.accent)
                    .disabled(isResting || reduceMotion)
                }
            }

            HStack(spacing: 10) {
                ClientExerciseMotionView(motion: descriptor.motion, paused: effectivePause)
                    .frame(maxWidth: .infinity)
                ClientMuscleMiniMap(
                    primary: descriptor.primaryMuscles,
                    secondary: descriptor.secondaryMuscles,
                    rearFacing: descriptor.viewAngle == .rear
                )
                .frame(width: 86)
            }
            .frame(height: 180)
            .padding(10)
            .background(ClientClay.inset, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay { RoundedRectangle(cornerRadius: 18).stroke(ClientClay.border) }

            if isResting && descriptor.isAnimated {
                Label("Animazione in pausa durante il recupero", systemImage: "timer")
                    .font(.caption).foregroundStyle(ClientClay.secondaryInk)
            }

            muscleChips

            if let technique = descriptor.technique, !technique.isEmpty {
                VStack(alignment: .leading, spacing: 5) {
                    Text("TECNICA").font(.caption2.weight(.bold)).tracking(1).foregroundStyle(ClientClay.secondaryInk)
                    Text(technique).font(.subheadline).foregroundStyle(ClientClay.ink).lineLimit(5)
                }
            }
        }
        .clayCard()
        .overlay { RoundedRectangle(cornerRadius: ClientClay.radius).stroke(ClientClay.accent.opacity(0.22)) }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityDescription)
        .onChange(of: exercise.id) { _, _ in isPaused = false }
    }

    @ViewBuilder private var muscleChips: some View {
        if descriptor.primaryMuscles.isEmpty && descriptor.secondaryMuscles.isEmpty {
            Text("La tecnica resta disponibile anche senza una mappa muscolare specifica.")
                .font(.caption).foregroundStyle(ClientClay.secondaryInk)
        } else {
            VStack(alignment: .leading, spacing: 8) {
                if !descriptor.primaryMuscles.isEmpty {
                    HStack(alignment: .top, spacing: 8) {
                        Text("Principali").font(.caption.weight(.bold)).foregroundStyle(ClientClay.accent)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(descriptor.primaryMuscles, id: \.self) { muscle in
                                    muscleChip(muscle.displayName, tint: ClientClay.accent)
                                }
                            }
                        }
                    }
                }
                if !descriptor.secondaryMuscles.isEmpty {
                    HStack(alignment: .top, spacing: 8) {
                        Text("Secondari").font(.caption.weight(.bold)).foregroundStyle(ClientClay.warning)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(descriptor.secondaryMuscles, id: \.self) { muscle in
                                    muscleChip(muscle.displayName, tint: ClientClay.warning)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private func muscleChip(_ title: String, tint: Color) -> some View {
        Text(title).font(.caption2.weight(.bold)).foregroundStyle(tint)
            .padding(.horizontal, 9).frame(minHeight: 28)
            .background(tint.opacity(0.12), in: Capsule())
            .overlay { Capsule().stroke(tint.opacity(0.35)) }
    }

    private var accessibilityDescription: String {
        let primary = descriptor.primaryMuscles.map(\.displayName).joined(separator: ", ")
        let secondary = descriptor.secondaryMuscles.map(\.displayName).joined(separator: ", ")
        return [
            exercise.name,
            primary.isEmpty ? nil : "Muscoli principali: \(primary)",
            secondary.isEmpty ? nil : "Muscoli secondari: \(secondary)",
            descriptor.technique
        ].compactMap { $0 }.joined(separator: ". ")
    }
}

private struct ClientExerciseMotionView: View {
    let motion: ClientNativeExerciseMotion
    let paused: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: paused)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            let phase = paused ? 0.35 : (sin(time * 2.4) + 1) / 2
            Canvas { context, size in
                drawBackdrop(context: &context, size: size)
                drawMotion(context: &context, size: size, phase: phase)
            }
        }
        .accessibilityHidden(true)
    }

    private func drawBackdrop(context: inout GraphicsContext, size: CGSize) {
        var baseline = Path()
        baseline.move(to: point(0.06, 0.90, size))
        baseline.addLine(to: point(0.94, 0.90, size))
        context.stroke(baseline, with: .color(ClientClay.border.opacity(0.9)), style: StrokeStyle(lineWidth: 1, dash: [4, 5]))
    }

    private func drawMotion(context: inout GraphicsContext, size: CGSize, phase: Double) {
        switch motion {
        case .benchPress: drawBenchPress(context: &context, size: size, phase: phase)
        case .squat: drawSquat(context: &context, size: size, phase: phase)
        case .romanianDeadlift: drawDeadlift(context: &context, size: size, phase: phase)
        case .latPulldown: drawPulldown(context: &context, size: size, phase: phase)
        case .seatedRow: drawRow(context: &context, size: size, phase: phase)
        case .shoulderPress: drawShoulderPress(context: &context, size: size, phase: phase)
        case .bicepsCurl: drawCurl(context: &context, size: size, phase: phase)
        case .tricepsPushdown: drawPushdown(context: &context, size: size, phase: phase)
        case .legPress: drawLegPress(context: &context, size: size, phase: phase)
        case .legCurl: drawLegCurl(context: &context, size: size, phase: phase)
        case .staticPose: drawStanding(context: &context, size: size)
        }
    }

    private func drawBenchPress(context: inout GraphicsContext, size: CGSize, phase: Double) {
        equipment(context: &context, from: (0.08, 0.70), to: (0.82, 0.70), size: size)
        equipment(context: &context, from: (0.20, 0.70), to: (0.20, 0.88), size: size)
        segment(context: &context, from: (0.20, 0.61), to: (0.62, 0.66), size: size)
        head(context: &context, at: (0.14, 0.57), size: size)
        segment(context: &context, from: (0.60, 0.66), to: (0.76, 0.78), size: size)
        segment(context: &context, from: (0.76, 0.78), to: (0.90, 0.84), size: size)
        let barY = 0.28 + 0.22 * phase
        let elbowY = 0.48 + 0.13 * phase
        segment(context: &context, from: (0.35, 0.62), to: (0.43, elbowY), size: size, tint: ClientClay.accent)
        segment(context: &context, from: (0.43, elbowY), to: (0.50, barY), size: size, tint: ClientClay.accent)
        segment(context: &context, from: (0.48, 0.61), to: (0.59, elbowY), size: size, tint: ClientClay.accent)
        segment(context: &context, from: (0.59, elbowY), to: (0.63, barY), size: size, tint: ClientClay.accent)
        equipment(context: &context, from: (0.37, barY), to: (0.76, barY), size: size, width: 4)
    }

    private func drawSquat(context: inout GraphicsContext, size: CGSize, phase: Double) {
        let drop = 0.18 * phase
        head(context: &context, at: (0.50, 0.17 + drop), size: size)
        segment(context: &context, from: (0.50, 0.25 + drop), to: (0.50, 0.52 + drop), size: size, tint: ClientClay.accent)
        segment(context: &context, from: (0.50, 0.34 + drop), to: (0.37, 0.42 + drop), size: size)
        segment(context: &context, from: (0.50, 0.34 + drop), to: (0.63, 0.42 + drop), size: size)
        segment(context: &context, from: (0.50, 0.52 + drop), to: (0.36, 0.68 + drop * 0.35), size: size, tint: ClientClay.accent)
        segment(context: &context, from: (0.36, 0.68 + drop * 0.35), to: (0.31, 0.88), size: size, tint: ClientClay.accent)
        segment(context: &context, from: (0.50, 0.52 + drop), to: (0.64, 0.68 + drop * 0.35), size: size, tint: ClientClay.accent)
        segment(context: &context, from: (0.64, 0.68 + drop * 0.35), to: (0.69, 0.88), size: size, tint: ClientClay.accent)
        equipment(context: &context, from: (0.30, 0.30 + drop), to: (0.70, 0.30 + drop), size: size, width: 4)
    }

    private func drawDeadlift(context: inout GraphicsContext, size: CGSize, phase: Double) {
        let lean = 0.20 * phase
        head(context: &context, at: (0.50 + lean, 0.18 + 0.16 * phase), size: size)
        segment(context: &context, from: (0.50 + lean * 0.8, 0.27 + 0.15 * phase), to: (0.48, 0.56), size: size, tint: ClientClay.accent)
        segment(context: &context, from: (0.48, 0.56), to: (0.39, 0.72), size: size, tint: ClientClay.warning)
        segment(context: &context, from: (0.39, 0.72), to: (0.36, 0.88), size: size)
        segment(context: &context, from: (0.48, 0.56), to: (0.57, 0.72), size: size, tint: ClientClay.warning)
        segment(context: &context, from: (0.57, 0.72), to: (0.61, 0.88), size: size)
        let handY = 0.40 + 0.28 * phase
        segment(context: &context, from: (0.55 + lean * 0.5, 0.34 + 0.12 * phase), to: (0.62, handY), size: size)
        equipment(context: &context, from: (0.30, handY), to: (0.78, handY), size: size, width: 4)
    }

    private func drawPulldown(context: inout GraphicsContext, size: CGSize, phase: Double) {
        equipment(context: &context, from: (0.22, 0.12), to: (0.78, 0.12), size: size, width: 4)
        head(context: &context, at: (0.50, 0.35), size: size)
        segment(context: &context, from: (0.50, 0.43), to: (0.50, 0.70), size: size, tint: ClientClay.accent)
        segment(context: &context, from: (0.50, 0.70), to: (0.38, 0.87), size: size)
        segment(context: &context, from: (0.50, 0.70), to: (0.62, 0.87), size: size)
        let handY = 0.16 + 0.22 * phase
        segment(context: &context, from: (0.46, 0.46), to: (0.31, 0.34 + 0.12 * phase), size: size, tint: ClientClay.accent)
        segment(context: &context, from: (0.31, 0.34 + 0.12 * phase), to: (0.27, handY), size: size)
        segment(context: &context, from: (0.54, 0.46), to: (0.69, 0.34 + 0.12 * phase), size: size, tint: ClientClay.accent)
        segment(context: &context, from: (0.69, 0.34 + 0.12 * phase), to: (0.73, handY), size: size)
        equipment(context: &context, from: (0.25, handY), to: (0.75, handY), size: size, width: 4)
    }

    private func drawRow(context: inout GraphicsContext, size: CGSize, phase: Double) {
        head(context: &context, at: (0.38, 0.36), size: size)
        segment(context: &context, from: (0.42, 0.43), to: (0.50, 0.67), size: size, tint: ClientClay.accent)
        segment(context: &context, from: (0.50, 0.67), to: (0.68, 0.72), size: size)
        segment(context: &context, from: (0.68, 0.72), to: (0.82, 0.86), size: size)
        let handX = 0.68 - 0.20 * phase
        segment(context: &context, from: (0.44, 0.47), to: (0.55, 0.52), size: size, tint: ClientClay.accent)
        segment(context: &context, from: (0.55, 0.52), to: (handX, 0.55), size: size, tint: ClientClay.warning)
        equipment(context: &context, from: (handX, 0.55), to: (0.90, 0.55), size: size, width: 2)
    }

    private func drawShoulderPress(context: inout GraphicsContext, size: CGSize, phase: Double) {
        drawStandingBase(context: &context, size: size)
        let handY = 0.14 + 0.25 * phase
        segment(context: &context, from: (0.46, 0.38), to: (0.34, 0.32 + 0.12 * phase), size: size, tint: ClientClay.accent)
        segment(context: &context, from: (0.34, 0.32 + 0.12 * phase), to: (0.34, handY), size: size, tint: ClientClay.warning)
        segment(context: &context, from: (0.54, 0.38), to: (0.66, 0.32 + 0.12 * phase), size: size, tint: ClientClay.accent)
        segment(context: &context, from: (0.66, 0.32 + 0.12 * phase), to: (0.66, handY), size: size, tint: ClientClay.warning)
        equipment(context: &context, from: (0.25, handY), to: (0.75, handY), size: size, width: 4)
    }

    private func drawCurl(context: inout GraphicsContext, size: CGSize, phase: Double) {
        drawStandingBase(context: &context, size: size)
        let handY = 0.65 - 0.25 * phase
        segment(context: &context, from: (0.44, 0.38), to: (0.40, 0.56), size: size, tint: ClientClay.accent)
        segment(context: &context, from: (0.40, 0.56), to: (0.36, handY), size: size, tint: ClientClay.accent)
        segment(context: &context, from: (0.56, 0.38), to: (0.60, 0.56), size: size, tint: ClientClay.accent)
        segment(context: &context, from: (0.60, 0.56), to: (0.64, handY), size: size, tint: ClientClay.accent)
        equipment(context: &context, from: (0.32, handY), to: (0.68, handY), size: size, width: 3)
    }

    private func drawPushdown(context: inout GraphicsContext, size: CGSize, phase: Double) {
        drawStandingBase(context: &context, size: size)
        let handY = 0.48 + 0.22 * phase
        segment(context: &context, from: (0.44, 0.38), to: (0.40, 0.51), size: size, tint: ClientClay.accent)
        segment(context: &context, from: (0.40, 0.51), to: (0.38, handY), size: size, tint: ClientClay.accent)
        segment(context: &context, from: (0.56, 0.38), to: (0.60, 0.51), size: size, tint: ClientClay.accent)
        segment(context: &context, from: (0.60, 0.51), to: (0.62, handY), size: size, tint: ClientClay.accent)
        equipment(context: &context, from: (0.50, 0.08), to: (0.50, 0.34), size: size, width: 2)
    }

    private func drawLegPress(context: inout GraphicsContext, size: CGSize, phase: Double) {
        equipment(context: &context, from: (0.18, 0.75), to: (0.36, 0.42), size: size, width: 7)
        head(context: &context, at: (0.29, 0.35), size: size)
        segment(context: &context, from: (0.34, 0.42), to: (0.47, 0.62), size: size)
        let kneeX = 0.58 + 0.16 * phase
        let footX = 0.68 + 0.18 * phase
        segment(context: &context, from: (0.47, 0.62), to: (kneeX, 0.55), size: size, tint: ClientClay.accent)
        segment(context: &context, from: (kneeX, 0.55), to: (footX, 0.36), size: size, tint: ClientClay.accent)
        equipment(context: &context, from: (footX, 0.20), to: (footX, 0.52), size: size, width: 7)
    }

    private func drawLegCurl(context: inout GraphicsContext, size: CGSize, phase: Double) {
        equipment(context: &context, from: (0.12, 0.64), to: (0.86, 0.64), size: size, width: 7)
        head(context: &context, at: (0.20, 0.48), size: size)
        segment(context: &context, from: (0.27, 0.53), to: (0.60, 0.58), size: size)
        segment(context: &context, from: (0.60, 0.58), to: (0.75, 0.60), size: size, tint: ClientClay.accent)
        let footY = 0.58 - 0.30 * phase
        segment(context: &context, from: (0.75, 0.60), to: (0.82, footY), size: size, tint: ClientClay.accent)
    }

    private func drawStanding(context: inout GraphicsContext, size: CGSize) {
        drawStandingBase(context: &context, size: size)
        segment(context: &context, from: (0.45, 0.38), to: (0.34, 0.68), size: size)
        segment(context: &context, from: (0.55, 0.38), to: (0.66, 0.68), size: size)
    }

    private func drawStandingBase(context: inout GraphicsContext, size: CGSize) {
        head(context: &context, at: (0.50, 0.20), size: size)
        segment(context: &context, from: (0.50, 0.28), to: (0.50, 0.58), size: size)
        segment(context: &context, from: (0.50, 0.58), to: (0.40, 0.86), size: size)
        segment(context: &context, from: (0.50, 0.58), to: (0.60, 0.86), size: size)
    }

    private func head(context: inout GraphicsContext, at position: (Double, Double), size: CGSize) {
        let center = point(position.0, position.1, size)
        let radius = min(size.width, size.height) * 0.055
        context.fill(Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)), with: .color(ClientClay.ink.opacity(0.84)))
    }

    private func segment(
        context: inout GraphicsContext,
        from: (Double, Double),
        to: (Double, Double),
        size: CGSize,
        tint: Color = ClientClay.ink.opacity(0.78),
        width: Double = 8
    ) {
        var path = Path()
        path.move(to: point(from.0, from.1, size))
        path.addLine(to: point(to.0, to.1, size))
        context.stroke(path, with: .color(tint), style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round))
    }

    private func equipment(
        context: inout GraphicsContext,
        from: (Double, Double),
        to: (Double, Double),
        size: CGSize,
        width: Double = 3
    ) {
        segment(context: &context, from: from, to: to, size: size, tint: ClientClay.secondaryInk.opacity(0.78), width: width)
    }

    private func point(_ x: Double, _ y: Double, _ size: CGSize) -> CGPoint {
        CGPoint(x: size.width * x, y: size.height * y)
    }
}

private struct ClientMuscleMiniMap: View {
    let primary: [ClientMuscleRegion]
    let secondary: [ClientMuscleRegion]
    let rearFacing: Bool

    var body: some View {
        Canvas { context, size in
            drawBody(context: &context, size: size)
            for muscle in secondary { highlight(muscle, context: &context, size: size, color: ClientClay.warning.opacity(0.72)) }
            for muscle in primary { highlight(muscle, context: &context, size: size, color: ClientClay.accent.opacity(0.92)) }
        }
        .accessibilityHidden(true)
    }

    private func drawBody(context: inout GraphicsContext, size: CGSize) {
        let neutral = ClientClay.secondaryInk.opacity(0.46)
        context.fill(Path(ellipseIn: rect(0.37, 0.03, 0.26, 0.13, size)), with: .color(neutral))
        context.fill(Path(roundedRect: rect(0.34, 0.17, 0.32, 0.38, size), cornerRadius: 12), with: .color(neutral))
        context.fill(Path(roundedRect: rect(0.16, 0.20, 0.15, 0.46, size), cornerRadius: 10), with: .color(neutral))
        context.fill(Path(roundedRect: rect(0.69, 0.20, 0.15, 0.46, size), cornerRadius: 10), with: .color(neutral))
        context.fill(Path(roundedRect: rect(0.35, 0.55, 0.13, 0.42, size), cornerRadius: 10), with: .color(neutral))
        context.fill(Path(roundedRect: rect(0.52, 0.55, 0.13, 0.42, size), cornerRadius: 10), with: .color(neutral))
    }

    private func highlight(_ muscle: ClientMuscleRegion, context: inout GraphicsContext, size: CGSize, color: Color) {
        let regions: [CGRect]
        switch muscle {
        case .chest: regions = [rect(0.38, 0.22, 0.24, 0.12, size)]
        case .shoulders: regions = [rect(0.25, 0.18, 0.16, 0.13, size), rect(0.59, 0.18, 0.16, 0.13, size)]
        case .upperBack: regions = [rect(0.37, 0.22, 0.26, 0.14, size)]
        case .lats: regions = [rect(0.34, 0.29, 0.12, 0.18, size), rect(0.54, 0.29, 0.12, 0.18, size)]
        case .quadriceps: regions = [rect(0.35, 0.57, 0.13, 0.22, size), rect(0.52, 0.57, 0.13, 0.22, size)]
        case .hamstrings: regions = [rect(0.35, 0.58, 0.13, 0.23, size), rect(0.52, 0.58, 0.13, 0.23, size)]
        case .biceps: regions = [rect(0.18, 0.28, 0.13, 0.16, size), rect(0.69, 0.28, 0.13, 0.16, size)]
        case .triceps: regions = [rect(0.18, 0.29, 0.13, 0.18, size), rect(0.69, 0.29, 0.13, 0.18, size)]
        case .glutes: regions = [rect(0.36, 0.48, 0.28, 0.13, size)]
        case .core: regions = [rect(0.40, 0.34, 0.20, 0.18, size)]
        case .calves: regions = [rect(0.35, 0.78, 0.13, 0.17, size), rect(0.52, 0.78, 0.13, 0.17, size)]
        }
        for region in regions {
            context.fill(Path(roundedRect: region, cornerRadius: 8), with: .color(color))
        }
    }

    private func rect(_ x: Double, _ y: Double, _ width: Double, _ height: Double, _ size: CGSize) -> CGRect {
        CGRect(x: size.width * x, y: size.height * y, width: size.width * width, height: size.height * height)
    }
}
