@preconcurrency import MapKit
import SwiftUI
import UIKit

private enum RunningMetricMode: String, CaseIterable {
    case pace = "min/km"
    case speed = "km/h"
}

struct ClientRunningView: View {
    let plan: ClientRunningPlan
    @EnvironmentObject private var session: ClientSessionStore
    @EnvironmentObject private var location: RunningLocationService
    @State private var showingRunner = false
    @State private var selectedResult: ClientRunningResult?

    private var activeRun: ClientRunningExecution? {
        guard session.activity.activeRun?.planID == plan.id else { return nil }
        return session.activity.activeRun
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 14) {
                ClientBadge(text: "Corsa assegnata", tint: ClientClay.accent, symbol: "figure.run")
                Text(plan.title).font(.system(.title2, design: .rounded, weight: .bold))
                Text(plan.detail).font(.body).foregroundStyle(ClientClay.secondaryInk)
                HStack(spacing: 18) {
                    if let minutes = plan.targetMinutes { metric("Durata", value: "\(minutes) min", symbol: "timer") }
                    if let distance = plan.targetDistanceKm { metric("Distanza", value: "\(distance.formatted()) km", symbol: "location") }
                }
                Label("Durante la corsa tieni GymManager aperto: il tracciamento in background non è attivo.", systemImage: "iphone")
                    .font(.caption).foregroundStyle(ClientClay.secondaryInk)
                Button {
                    if activeRun == nil {
                        session.beginRun(plan)
                        location.beginNewRun()
                    }
                    showingRunner = true
                } label: {
                    Label(activeRun == nil ? "Inizia corsa" : "Riprendi corsa", systemImage: "figure.run")
                }
                .buttonStyle(ClayPrimaryButtonStyle())
                .accessibilityHint("Apre il rilevamento GPS della corsa")
            }
            .clayCard()

            if !results.isEmpty {
                Text("Le tue corse").font(.title3.weight(.bold))
                ForEach(results.prefix(5)) { result in
                    Button { selectedResult = result } label: { historyRow(result) }
                        .buttonStyle(.plain)
                        .accessibilityHint("Apre percorso e dati finali")
                }
            }
        }
        .fullScreenCover(isPresented: $showingRunner) {
            ClientRunningExecutionView(plan: plan)
        }
        .fullScreenCover(item: $selectedResult) { result in
            ClientRunningCompletionView(result: result) { selectedResult = nil }
        }
    }

    private var results: [ClientRunningResult] {
        session.activity.runningResults
            .filter { $0.planID == plan.id }
            .sorted { $0.completedAt > $1.completedAt }
    }

    private func historyRow(_ result: ClientRunningResult) -> some View {
        HStack(spacing: 14) {
            Image(systemName: "map.fill").font(.title2).foregroundStyle(ClientClay.accent)
            VStack(alignment: .leading, spacing: 4) {
                Text(result.completedAt.formatted(date: .abbreviated, time: .shortened)).font(.headline).foregroundStyle(ClientClay.ink)
                Text(result.distanceKm.map { "\($0.formatted(.number.precision(.fractionLength(2)))) km" } ?? "Percorso GPS non disponibile")
                    .font(.subheadline).foregroundStyle(ClientClay.secondaryInk)
            }
            Spacer()
            Text(ClientRunningFormat.duration(result.durationSeconds)).font(.subheadline.monospacedDigit().weight(.semibold)).foregroundStyle(ClientClay.ink)
            Image(systemName: "chevron.right").font(.caption.weight(.bold)).foregroundStyle(ClientClay.secondaryInk)
        }
        .clayCard(padding: 15)
    }

    private func metric(_ title: String, value: String, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(title, systemImage: symbol).font(.caption).foregroundStyle(ClientClay.secondaryInk)
            Text(value).font(.headline)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct ClientRunningExecutionView: View {
    let plan: ClientRunningPlan
    @EnvironmentObject private var session: ClientSessionStore
    @EnvironmentObject private var location: RunningLocationService
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State private var camera: MapCameraPosition = .automatic
    @State private var metricMode: RunningMetricMode = .pace
    @State private var completedResult: ClientRunningResult?

    private var activeRun: ClientRunningExecution? {
        guard session.activity.activeRun?.planID == plan.id else { return nil }
        return session.activity.activeRun
    }

    var body: some View {
        Group {
            if let result = completedResult {
                ClientRunningCompletionView(result: result) { dismiss() }
            } else {
                activeView
            }
        }
        .onAppear {
            UIApplication.shared.isIdleTimerDisabled = true
            if let run = activeRun {
                if run.isPaused { location.pauseTracking() }
                else { location.resumeRun(route: run.route, maximumSpeedMetersPerSecond: run.maximumSpeedMetersPerSecond) }
            }
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active {
                session.updateRunRoute(location.route, maximumSpeedMetersPerSecond: location.maximumSpeedMetersPerSecond)
            }
        }
    }

    private var activeView: some View {
        ZStack(alignment: .top) {
            Map(position: $camera) {
                if location.route.count > 1 {
                    MapPolyline(coordinates: location.route.map(\.coordinate))
                        .stroke(ClientClay.accent, style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round))
                }
                if let current = location.route.last {
                    Annotation("Posizione corrente", coordinate: current.coordinate) {
                        ZStack {
                            Circle().fill(.white).frame(width: 26, height: 26).shadow(radius: 4)
                            Circle().fill(ClientClay.accent).frame(width: 14, height: 14)
                        }
                    }
                }
            }
            .mapStyle(.standard(elevation: .realistic))
            .mapControls { MapCompass(); MapScaleView() }
            .ignoresSafeArea()

            locationBanner
        }
        .safeAreaInset(edge: .bottom, spacing: 0) { controlDock }
        .onChange(of: location.route) { _, route in
            session.updateRunRoute(route, maximumSpeedMetersPerSecond: location.maximumSpeedMetersPerSecond, persist: route.count.isMultiple(of: 5))
            if let coordinate = route.last?.coordinate {
                withAnimation(.easeOut(duration: 0.35)) {
                    camera = .camera(MapCamera(centerCoordinate: coordinate, distance: 650, heading: 0, pitch: 25))
                }
            }
        }
        .interactiveDismissDisabled()
    }

    @ViewBuilder private var locationBanner: some View {
        switch location.state {
        case .requestingPermission:
            banner("Consenti la posizione per tracciare percorso e distanza.", symbol: "location.circle")
        case .reducedAccuracy:
            banner("Posizione precisa disattivata: percorso e ritmo possono essere meno accurati.", symbol: "location.slash")
        case .denied, .restricted:
            banner("Posizione non disponibile. La corsa salva il tempo, ma non inventa percorso o distanza.", symbol: "location.slash.fill")
        case .unavailable:
            banner("Servizi di localizzazione non disponibili.", symbol: "location.slash.fill")
        case .failed:
            banner("Segnale GPS temporaneamente non disponibile.", symbol: "exclamationmark.triangle.fill")
        case .idle, .tracking:
            EmptyView()
        }
    }

    private func banner(_ text: String, symbol: String) -> some View {
        Label(text, systemImage: symbol)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(ClientClay.ink)
            .padding(12)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
            .padding(.horizontal, 14)
            .padding(.top, 8)
    }

    private var controlDock: some View {
        VStack(spacing: 13) {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                HStack(spacing: 10) {
                    liveMetric(title: "Tempo", value: ClientRunningFormat.duration(activeRun?.elapsedSeconds(at: context.date) ?? 0), symbol: "timer")
                    liveMetric(title: "Distanza", value: "\(location.distanceKm.formatted(.number.precision(.fractionLength(2)))) km", symbol: "point.topleft.down.to.point.bottomright.curvepath")
                }
            }
            selectedLiveMetric
            Picker("Metrica in tempo reale", selection: $metricMode) {
                ForEach(RunningMetricMode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .onChange(of: metricMode) { _, _ in ClientHaptics.selection() }

            HStack(spacing: 10) {
                Button {
                    if activeRun?.isPaused == true {
                        session.toggleRunPause()
                        if let run = activeRun { location.resumeRun(route: run.route, maximumSpeedMetersPerSecond: run.maximumSpeedMetersPerSecond) }
                    } else {
                        session.toggleRunPause()
                        location.pauseTracking()
                    }
                } label: {
                    Label(activeRun?.isPaused == true ? "Riprendi" : "Pausa", systemImage: activeRun?.isPaused == true ? "play.fill" : "pause.fill")
                }
                .buttonStyle(ClaySecondaryButtonStyle())
                HoldToFinishButton(action: finishRun)
            }
        }
        .padding(16)
        .background(.ultraThinMaterial)
    }

    private var selectedLiveMetric: some View {
        let speed = location.currentSpeedMetersPerSecond
        let value: String
        switch metricMode {
        case .speed:
            value = speed.map { "\(($0 * 3.6).formatted(.number.precision(.fractionLength(1)))) km/h" } ?? "-- km/h"
        case .pace:
            value = ClientRunningFormat.pace(speedMetersPerSecond: speed)
        }
        return liveMetric(title: metricMode == .speed ? "Velocità" : "Ritmo", value: value, symbol: metricMode == .speed ? "speedometer" : "metronome")
    }

    private func liveMetric(title: String, value: String, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(title, systemImage: symbol).font(.caption).foregroundStyle(ClientClay.secondaryInk)
            Text(value).font(.system(.title2, design: .rounded, weight: .bold).monospacedDigit())
                .minimumScaleFactor(0.7).lineLimit(1).foregroundStyle(ClientClay.ink)
        }
        .padding(12).frame(maxWidth: .infinity, alignment: .leading)
        .background(ClientClay.surface, in: RoundedRectangle(cornerRadius: 15))
    }

    private func finishRun() {
        location.stopTracking()
        session.updateRunRoute(location.route, maximumSpeedMetersPerSecond: location.maximumSpeedMetersPerSecond)
        completedResult = session.finishRun(effort: nil, note: "")
        UIApplication.shared.isIdleTimerDisabled = false
    }
}

private struct HoldToFinishButton: View {
    let action: () -> Void
    @State private var isHolding = false

    var body: some View {
        Label("Tieni premuto", systemImage: "stop.fill")
            .font(.headline).foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(ClientClay.accent, in: RoundedRectangle(cornerRadius: 16))
            .overlay(alignment: .bottomLeading) {
                GeometryReader { proxy in
                    Capsule().fill(.white.opacity(0.8))
                        .frame(width: isHolding ? proxy.size.width : 0, height: 4)
                        .animation(isHolding ? .linear(duration: 1.25) : .easeOut(duration: 0.15), value: isHolding)
                }
                .frame(height: 4).clipShape(Capsule())
            }
            .contentShape(Rectangle())
            .onLongPressGesture(minimumDuration: 1.25, maximumDistance: 55) {
                ClientHaptics.workoutFinished()
                action()
            } onPressingChanged: { pressing in
                isHolding = pressing
            }
            .accessibilityLabel("Tieni premuto per terminare la corsa")
            .accessibilityHint("Richiede una pressione prolungata per evitare tocchi accidentali")
    }
}

private struct ClientRunningCompletionView: View {
    let result: ClientRunningResult
    let onDone: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var visiblePointCount = 1
    @State private var showingSummary = false
    @State private var camera: MapCameraPosition = .automatic

    private var visibleRoute: [ClientRoutePoint] {
        Array(result.route.prefix(max(0, visiblePointCount)))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    Map(position: $camera) {
                        if visibleRoute.count > 1 {
                            MapPolyline(coordinates: visibleRoute.map(\.coordinate))
                                .stroke(ClientClay.accent, style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round))
                        }
                        if let first = result.route.first {
                            Annotation("Partenza", coordinate: first.coordinate) { Circle().fill(ClientClay.sage).frame(width: 14, height: 14) }
                        }
                        if showingSummary, let last = result.route.last {
                            Annotation("Arrivo", coordinate: last.coordinate) { Image(systemName: "flag.checkered.circle.fill").font(.title).foregroundStyle(ClientClay.ink) }
                        } else if let tracer = visibleRoute.last {
                            Annotation("Percorso", coordinate: tracer.coordinate) { Circle().fill(ClientClay.accent).frame(width: 16, height: 16) }
                        }
                    }
                    .mapStyle(.standard(elevation: .realistic))
                    .frame(height: 330)
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                    .accessibilityLabel("Mappa del percorso completato")

                    if showingSummary {
                        summary
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    } else {
                        ProgressView("Ripercorriamo la tua corsa…")
                            .tint(ClientClay.accent).padding()
                    }
                }
                .padding(18)
            }
            .clientPage()
            .navigationTitle(showingSummary ? "Corsa completata" : "Il tuo percorso")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !showingSummary {
                    ToolbarItem(placement: .topBarTrailing) { Button("Salta") { showSummary() } }
                }
            }
            .task { await replay() }
        }
    }

    private var summary: some View {
        VStack(spacing: 15) {
            Label("Salvata su questo dispositivo", systemImage: "checkmark.circle.fill")
                .font(.subheadline.weight(.semibold)).foregroundStyle(ClientClay.sage)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                summaryMetric("Distanza", value: result.distanceKm.map { "\($0.formatted(.number.precision(.fractionLength(2)))) km" } ?? "Non disponibile")
                summaryMetric("Durata", value: ClientRunningFormat.duration(result.durationSeconds))
                summaryMetric("Ritmo medio", value: result.averagePaceMinutesPerKm.map(ClientRunningFormat.pace) ?? "Non disponibile")
                summaryMetric("Velocità media", value: result.averageSpeedKmh.map { "\($0.formatted(.number.precision(.fractionLength(1)))) km/h" } ?? "Non disponibile")
                summaryMetric("Velocità massima", value: result.maximumSpeedKmh.map { "\($0.formatted(.number.precision(.fractionLength(1)))) km/h" } ?? "Non disponibile")
            }
            Button("Fine", action: onDone).buttonStyle(ClayPrimaryButtonStyle())
        }
        .clayCard()
    }

    private func summaryMetric(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption).foregroundStyle(ClientClay.secondaryInk)
            Text(value).font(.headline.monospacedDigit()).minimumScaleFactor(0.7).lineLimit(2)
        }
        .padding(12).frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
        .background(ClientClay.surfaceDeep.opacity(0.7), in: RoundedRectangle(cornerRadius: 14))
    }

    private func replay() async {
        camera = ClientRunningMap.camera(for: result.route)
        guard !reduceMotion, result.route.count > 1 else {
            visiblePointCount = result.route.count
            showSummary()
            return
        }
        let frameCount = min(result.route.count, 100)
        for frame in 1...frameCount {
            guard !Task.isCancelled, !showingSummary else { return }
            visiblePointCount = max(1, Int((Double(frame) / Double(frameCount)) * Double(result.route.count)))
            try? await Task.sleep(nanoseconds: 25_000_000)
        }
        showSummary()
    }

    private func showSummary() {
        visiblePointCount = result.route.count
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.35)) { showingSummary = true }
    }
}

private enum ClientRunningMap {
    static func camera(for route: [ClientRoutePoint]) -> MapCameraPosition {
        guard let first = route.first else { return .automatic }
        let latitudes = route.map(\.latitude)
        let longitudes = route.map(\.longitude)
        let minLatitude = latitudes.min() ?? first.latitude
        let maxLatitude = latitudes.max() ?? first.latitude
        let minLongitude = longitudes.min() ?? first.longitude
        let maxLongitude = longitudes.max() ?? first.longitude
        let center = CLLocationCoordinate2D(latitude: (minLatitude + maxLatitude) / 2, longitude: (minLongitude + maxLongitude) / 2)
        let span = MKCoordinateSpan(
            latitudeDelta: max(0.006, (maxLatitude - minLatitude) * 1.35),
            longitudeDelta: max(0.006, (maxLongitude - minLongitude) * 1.35)
        )
        return .region(MKCoordinateRegion(center: center, span: span))
    }
}

private enum ClientRunningFormat {
    static func duration(_ seconds: TimeInterval) -> String {
        let value = max(0, Int(seconds))
        return String(format: "%02d:%02d:%02d", value / 3_600, value / 60 % 60, value % 60)
    }

    static func pace(speedMetersPerSecond: Double?) -> String {
        guard let speedMetersPerSecond, speedMetersPerSecond >= 0.8 else { return "--'--\" /km" }
        return pace(1_000 / speedMetersPerSecond / 60)
    }

    static func pace(_ minutesPerKm: Double) -> String {
        let totalSeconds = max(0, Int((minutesPerKm * 60).rounded()))
        return String(format: "%d'%02d\" /km", totalSeconds / 60, totalSeconds % 60)
    }
}

private extension ClientRoutePoint {
    var coordinate: CLLocationCoordinate2D { CLLocationCoordinate2D(latitude: latitude, longitude: longitude) }
}
