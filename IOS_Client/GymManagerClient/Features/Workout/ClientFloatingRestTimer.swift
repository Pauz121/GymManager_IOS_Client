import Combine
import SwiftUI

struct ClientWorkoutAvoidanceKey: PreferenceKey {
    static var defaultValue: [Anchor<CGRect>] { [] }
    static func reduce(value: inout [Anchor<CGRect>], nextValue: () -> [Anchor<CGRect>]) { value += nextValue() }
}

private struct ClientTimerNeedsAccessoryKey: PreferenceKey {
    static let defaultValue = false
    static func reduce(value: inout Bool, nextValue: () -> Bool) { value = value || nextValue() }
}

struct ClientFloatingRestTimerModifier: ViewModifier {
    @EnvironmentObject private var session: ClientSessionStore
    @EnvironmentObject private var presentation: ClientRestTimerPresentation
    @State private var hostID = UUID()
    @State private var useAccessory = false
    @State private var expanded = false
    func body(content: Content) -> some View {
        content
            .overlayPreferenceValue(ClientWorkoutAvoidanceKey.self) { anchors in
                ClientFloatingRestTimerHost(avoiding: anchors, suppressBubble: useAccessory, hostID: hostID)
            }
            .onPreferenceChange(ClientTimerNeedsAccessoryKey.self) { needed in if needed { useAccessory = true } }
            .onChange(of: session.activity.restTimer == nil) { _, absent in if absent { useAccessory = false } }
            .onChange(of: presentation.hosts.last) { _, owner in if owner != hostID { expanded = false } }
            .safeAreaInset(edge: .top) {
                if useAccessory, presentation.hosts.last == hostID, let timer = session.activity.restTimer {
                    Button { expanded = true } label: {
                        TimelineView(.periodic(from: .now, by: 1)) { context in
                            Text("Recupero: \(timer.remainingSeconds(at: context.date))s · controlli")
                        }
                    }
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(ClientClay.color(.surfaceElevated))
                        .popover(isPresented: $expanded) {
                            ClientRestTimerControls(onClose: { expanded = false }).presentationCompactAdaptation(.popover)
                        }
                }
            }
    }
}

extension View {
    func clientFloatingRestTimer() -> some View { modifier(ClientFloatingRestTimerModifier()) }
}

@MainActor
final class ClientRestTimerPresentation: ObservableObject {
    @Published var normalizedPosition = CGPoint(x: 1, y: 0.2)
    @Published private(set) var hosts: [UUID] = []
    func enter(_ id: UUID) { hosts.removeAll { $0 == id }; hosts.append(id) }
    func leave(_ id: UUID) { hosts.removeAll { $0 == id } }
}

/// Multiple presentation contexts share one UI position; only the top host draws.
/// The timer itself is NEVER copied here.
struct ClientFloatingRestTimerHost: View {
    var avoiding: [Anchor<CGRect>] = []
    var suppressBubble = false
    let hostID: UUID
    @EnvironmentObject private var session: ClientSessionStore
    @EnvironmentObject private var presentation: ClientRestTimerPresentation
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var expanded = false
    @State private var dragOrigin: CGPoint?
    private let diameter: CGFloat = 84

    var body: some View {
        GeometryReader { proxy in
            let bounds = CGRect(x: proxy.safeAreaInsets.leading, y: proxy.safeAreaInsets.top,
                                width: max(0, proxy.size.width - proxy.safeAreaInsets.leading - proxy.safeAreaInsets.trailing),
                                height: max(0, proxy.size.height - proxy.safeAreaInsets.top - proxy.safeAreaInsets.bottom))
            let preferred = CGPoint(x: bounds.minX + bounds.width * presentation.normalizedPosition.x,
                                    y: bounds.minY + bounds.height * presentation.normalizedPosition.y)
            let center = ClientFloatingTimerPlacement.center(preferred: preferred, bounds: bounds, diameter: diameter,
                                                             avoiding: avoiding.map { proxy[$0] })
            if presentation.hosts.last == hostID {
                if let timer = session.activity.restTimer, let center, !suppressBubble {
                    bubble(timer)
                        .position(center)
                        .highPriorityGesture(DragGesture(minimumDistance: 10)
                            .onChanged { value in
                                let origin = dragOrigin ?? center
                                dragOrigin = origin
                                let next = CGPoint(x: origin.x + value.translation.width, y: origin.y + value.translation.height)
                                presentation.normalizedPosition = CGPoint(
                                    x: min(1, max(0, (next.x - bounds.minX) / max(1, bounds.width))),
                                    y: min(1, max(0, (next.y - bounds.minY) / max(1, bounds.height))))
                            }
                            .onEnded { _ in dragOrigin = nil })
                } else if session.activity.restTimer != nil && center == nil {
                    Color.clear.allowsHitTesting(false)
                        .preference(key: ClientTimerNeedsAccessoryKey.self, value: true)
                }
                if let ready = session.restReadyExerciseID {
                    Label("Pronto per la prossima serie", systemImage: "checkmark.circle.fill")
                        .font(.subheadline.weight(.semibold)).foregroundStyle(ClientClay.color(.success))
                        .padding(ClientSpacing.control)
                        .background(ClientClay.color(.surfaceElevated), in: Capsule())
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                        .allowsHitTesting(false)
                        .task(id: ready) {
                            do { try await Task.sleep(for: .seconds(4)) } catch { return }
                            if session.restReadyExerciseID == ready { session.dismissRestReady() }
                        }
                }
            }
        }
        .onAppear { presentation.enter(hostID) }
        .onDisappear { presentation.leave(hostID); dragOrigin = nil }
        .onChange(of: presentation.hosts.last) { _, owner in
            if owner != hostID { expanded = false; dragOrigin = nil }
        }
    }

    private func bubble(_ timer: ClientRestTimerState) -> some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            Button { expanded.toggle() } label: {
                ZStack {
                    Circle().fill(ClientClay.color(.surfaceElevated))
                    Circle().stroke(ClientClay.color(.borderStrong), lineWidth: 2)
                    if let fraction = timer.remainingFraction(at: context.date) {
                        Circle().trim(from: 0, to: fraction)
                            .stroke(ClientClay.color(.runningAccent), style: StrokeStyle(lineWidth: 4, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                    }
                    VStack(spacing: 3) {
                        Image(systemName: timer.phase == .paused ? "pause.fill" : "timer").font(.caption)
                        Text(format(timer.remainingSeconds(at: context.date))).font(.headline.monospacedDigit())
                    }.foregroundStyle(ClientClay.color(.textPrimary))
                }
                .frame(width: diameter, height: diameter)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Recupero")
            .accessibilityValue("\(timer.remainingSeconds(at: context.date)) secondi\(timer.phase == .paused ? ", in pausa" : "")")
            .accessibilityHint("Apre pausa, regolazione e posizione del timer")
        }
        .popover(isPresented: $expanded) {
            ClientRestTimerControls(onClose: { expanded = false }).presentationCompactAdaptation(.popover)
        }
    }

    private func format(_ seconds: Int) -> String { String(format: "%02d:%02d", seconds / 60, seconds % 60) }
}

private struct ClientRestTimerControls: View {
    let onClose: () -> Void
    @EnvironmentObject private var session: ClientSessionStore
    @EnvironmentObject private var presentation: ClientRestTimerPresentation
    var body: some View {
        VStack(alignment: .leading, spacing: ClientSpacing.related) {
            Text("Recupero").font(.headline)
            if let timer = session.activity.restTimer {
                Text(timer.nextSetNumber.map { "Prossima: serie \($0)" } ?? "Poi passa al prossimo esercizio")
                    .font(.subheadline)
                HStack {
                    Button("−15 s") { session.adjustRestTimer(by: -15) }
                    Button("+15 s") { session.adjustRestTimer(by: 15) }
                }.buttonStyle(.bordered).controlSize(.large)
                Button(timer.phase == .paused ? "Riprendi" : "Pausa") {
                    if timer.phase == .paused { session.resumeRestTimer() } else { session.pauseRestTimer() }
                }
                Button("Salta recupero") { session.skipRestTimer(); onClose() }
            }
            HStack {
                Button("A sinistra") { presentation.normalizedPosition.x = 0; onClose() }
                Button("A destra") { presentation.normalizedPosition.x = 1; onClose() }
            }
            Button("Chiudi controlli") { onClose() }
        }
        .buttonStyle(.bordered).controlSize(.large)
        .padding(ClientSpacing.page)
    }
}
