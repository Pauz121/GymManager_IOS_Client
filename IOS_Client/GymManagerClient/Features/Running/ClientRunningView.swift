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
    @State private var selectedTarget: ClientRunningTarget?

    private var activeRun: ClientRunningExecution? {
        guard session.activity.activeRun?.planID == plan.id else { return nil }
        return session.activity.activeRun
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 14) {
                Text("CORSA").font(.caption.weight(.bold)).tracking(1.1).foregroundStyle(.white.opacity(0.62))
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

                Divider().overlay(.white.opacity(0.14))
                Text(plan.title).font(.headline.weight(.bold)).foregroundStyle(.white)
                Text(plan.detail).font(.subheadline).foregroundStyle(.white.opacity(0.68))
                HStack(spacing: 18) {
                    if let minutes = plan.targetMinutes { metric("Durata", value: "\(minutes) min", symbol: "timer") }
                    if let distance = plan.targetDistanceKm { metric("Distanza", value: "\(distance.formatted()) km", symbol: "location") }
                }
                Label("Percorso e Live Activity restano visibili anche con schermo bloccato.", systemImage: "lock.iphone")
                    .font(.caption).foregroundStyle(.white.opacity(0.66))
            }
            .premiumCard(tint: ClientClay.accent)

            personalBestSection

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
        .sheet(item: $selectedTarget) { target in
            ClientPersonalBestDetailView(target: target, results: results)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }

    private var results: [ClientRunningResult] {
        session.activity.runningResults.sorted { $0.completedAt > $1.completedAt }
    }

    private var personalBestSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            ClientSectionHeader(title: "Personal Best", detail: "Top 3 per distanza", symbol: "trophy.fill")
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(ClientRunningTarget.allCases) { target in
                    let top = ClientRunningAchievements.leaderboard(results: results, target: target)
                    Button { selectedTarget = target } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(target.title).font(.caption.weight(.bold)).tracking(0.8)
                                Spacer()
                                Image(systemName: top.isEmpty ? "circle.dashed" : "trophy.fill")
                            }
                            .foregroundStyle(top.isEmpty ? ClientClay.secondaryInk : ClientClay.gold)
                            Text(top.first.map { ClientRunningFormat.effortDuration($0.effort.durationSeconds) } ?? "--:--")
                                .font(.system(.title2, design: .rounded, weight: .heavy).monospacedDigit())
                                .foregroundStyle(ClientClay.ink)
                            Text(top.first.map { $0.completedAt.formatted(date: .abbreviated, time: .omitted) } ?? "Nessun tempo")
                                .font(.caption2).foregroundStyle(ClientClay.secondaryInk).lineLimit(1)
                        }
                        .clayCard(padding: 13)
                    }
                    .buttonStyle(.plain)
                    .disabled(top.isEmpty)
                    .accessibilityHint(top.isEmpty ? "Completa questa distanza per registrare un tempo" : "Apre la Top 3")
                }
            }
        }
    }

    private func historyRow(_ result: ClientRunningResult) -> some View {
        HStack(spacing: 14) {
            Image(systemName: "map.fill").font(.title2).foregroundStyle(ClientClay.accent)
            VStack(alignment: .leading, spacing: 4) {
                Text(result.completedAt.formatted(date: .abbreviated, time: .shortened)).font(.headline).foregroundStyle(ClientClay.ink)
                Text(result.distanceKm.map { "\($0.formatted(.number.precision(.fractionLength(2)))) km" } ?? "Percorso GPS non disponibile")
                    .font(.subheadline).foregroundStyle(ClientClay.secondaryInk)
                if let pace = result.averagePaceMinutesPerKm, let speed = result.averageSpeedKmh {
                    Text("\(ClientRunningFormat.pace(pace)) · \(speed.formatted(.number.precision(.fractionLength(1)))) km/h")
                        .font(.caption.monospacedDigit()).foregroundStyle(ClientClay.inkSoft)
                }
                let records = ClientRunningAchievements.recordAchievements(results: results).filter { $0.sessionID == result.id }
                if !records.isEmpty {
                    Text(records.map { "PB \($0.target.title)" }.joined(separator: " · "))
                        .font(.caption2.weight(.bold)).foregroundStyle(ClientClay.gold)
                }
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
    @EnvironmentObject private var liveActivity: ClientRunLiveActivityManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State private var camera: MapCameraPosition = .automatic
    @State private var metricMode: RunningMetricMode = .pace
    @State private var completedResult: ClientRunningResult?
    @State private var lastSplitCount = 0
    @State private var splitToast: ClientRunningSplit?

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
                lastSplitCount = ClientRunningAchievements.splits(for: run.route).count
                if run.isPaused { location.pauseTracking() }
                else { location.resumeRun(route: run.route, maximumSpeedMetersPerSecond: run.maximumSpeedMetersPerSecond, elapsedSeconds: run.elapsedSeconds()) }
                Task {
                    await liveActivity.start(planTitle: plan.title, elapsedSeconds: run.elapsedSeconds())
                    await updateLiveActivity(force: true)
                }
            }
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active {
                session.updateRunRoute(location.route, maximumSpeedMetersPerSecond: location.maximumSpeedMetersPerSecond)
                Task { await updateLiveActivity(force: true) }
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
            if let splitToast {
                ClientRunSplitToast(split: splitToast)
                    .padding(.horizontal, 14)
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .padding(.bottom, 8)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) { controlDock }
        .onChange(of: location.route) { _, route in
            session.updateRunRoute(route, maximumSpeedMetersPerSecond: location.maximumSpeedMetersPerSecond, persist: route.count.isMultiple(of: 5))
            Task { await updateLiveActivity() }
            handleCompletedSplit(in: route)
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
            .background(ClientClay.surfaceElevated.opacity(0.96), in: RoundedRectangle(cornerRadius: 14))
            .overlay { RoundedRectangle(cornerRadius: 14).stroke(ClientClay.border) }
            .padding(.horizontal, 14)
            .padding(.top, 8)
    }

    private var controlDock: some View {
        VStack(spacing: 13) {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                VStack(spacing: 10) {
                    HStack(spacing: 10) {
                        liveMetric(title: "Tempo", value: ClientRunningFormat.duration(activeRun?.elapsedSeconds(at: context.date) ?? 0), symbol: "timer", prominence: true)
                        liveMetric(title: "Distanza", value: "\(location.distanceKm.formatted(.number.precision(.fractionLength(2)))) km", symbol: "point.topleft.down.to.point.bottomright.curvepath", prominence: true)
                    }
                    HStack(spacing: 10) {
                        liveMetric(title: "Ritmo attuale · 25s", value: currentPace, symbol: "metronome")
                        liveMetric(title: "Velocità attuale · 25s", value: currentSpeed, symbol: "speedometer")
                    }
                    HStack(spacing: 10) {
                        liveMetric(title: "Ritmo medio", value: averagePace(at: context.date), symbol: "gauge.with.needle")
                        liveMetric(title: "Velocità media", value: averageSpeed(at: context.date), symbol: "speedometer")
                    }
                }
            }
            Picker("Metrica sul blocco schermo", selection: $metricMode) {
                ForEach(RunningMetricMode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .tint(ClientClay.accent)
            .onChange(of: metricMode) { _, _ in
                ClientHaptics.selection()
                Task { await updateLiveActivity(force: true) }
            }

            HStack(spacing: 10) {
                Button {
                    if activeRun?.isPaused == true {
                        session.toggleRunPause()
                        if let run = activeRun { location.resumeRun(route: run.route, maximumSpeedMetersPerSecond: run.maximumSpeedMetersPerSecond, elapsedSeconds: run.elapsedSeconds()) }
                    } else {
                        session.toggleRunPause()
                        location.pauseTracking()
                    }
                    Task { await updateLiveActivity(force: true) }
                } label: {
                    Label(activeRun?.isPaused == true ? "Riprendi" : "Pausa", systemImage: activeRun?.isPaused == true ? "play.fill" : "pause.fill")
                }
                .buttonStyle(ClaySecondaryButtonStyle())
                HoldToFinishButton(action: finishRun)
            }
        }
        .padding(16)
        .background(ClientClay.canvas.opacity(0.97))
    }

    private var currentPace: String {
        if activeRun?.isPaused == true { return "In pausa" }
        return ClientRunningFormat.pace(speedMetersPerSecond: location.stabilizedSpeedMetersPerSecond)
    }

    private var currentSpeed: String {
        if activeRun?.isPaused == true { return "0.0 km/h" }
        return location.stabilizedSpeedMetersPerSecond.map { "\(($0 * 3.6).formatted(.number.precision(.fractionLength(1)))) km/h" } ?? "-- km/h"
    }

    private func averagePace(at date: Date) -> String {
        guard let elapsed = activeRun?.elapsedSeconds(at: date), location.distanceKm > 0.02 else { return "--'--\" /km" }
        return ClientRunningFormat.pace(elapsed / 60 / location.distanceKm)
    }

    private func averageSpeed(at date: Date) -> String {
        guard let elapsed = activeRun?.elapsedSeconds(at: date), elapsed > 0, location.distanceKm > 0 else { return "-- km/h" }
        return "\((location.distanceKm / (elapsed / 3_600)).formatted(.number.precision(.fractionLength(1)))) km/h"
    }

    private func liveMetric(title: String, value: String, symbol: String, prominence: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(title, systemImage: symbol).font(.caption).foregroundStyle(ClientClay.secondaryInk)
            Text(value).font(.system(prominence ? .title2 : .headline, design: .rounded, weight: .bold).monospacedDigit())
                .minimumScaleFactor(0.7).lineLimit(1).foregroundStyle(ClientClay.ink)
        }
        .padding(12).frame(maxWidth: .infinity, alignment: .leading)
        .background(ClientClay.surfaceElevated, in: RoundedRectangle(cornerRadius: 15))
        .overlay { RoundedRectangle(cornerRadius: 15).stroke(ClientClay.border) }
    }

    private func handleCompletedSplit(in route: [ClientRoutePoint]) {
        let splits = ClientRunningAchievements.splits(for: route)
        guard splits.count > lastSplitCount, let latest = splits.last else { return }
        lastSplitCount = splits.count
        ClientHaptics.completedSet()
        withAnimation(.snappy(duration: 0.28)) { splitToast = latest }
        Task {
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            guard splitToast?.index == latest.index else { return }
            withAnimation(.easeOut(duration: 0.2)) { splitToast = nil }
        }
    }

    private func finishRun() {
        let elapsed = activeRun?.elapsedSeconds() ?? 0
        let distanceMeters = ClientRunningMetrics.distanceMeters(for: location.route)
        location.stopTracking()
        session.updateRunRoute(location.route, maximumSpeedMetersPerSecond: location.maximumSpeedMetersPerSecond)
        completedResult = session.finishRun(effort: nil, note: "")
        Task {
            await liveActivity.end(elapsedSeconds: elapsed, distanceMeters: distanceMeters, displayMode: metricMode == .speed ? "speed" : "pace")
        }
        UIApplication.shared.isIdleTimerDisabled = false
    }

    private func updateLiveActivity(force: Bool = false) async {
        guard let run = activeRun else { return }
        await liveActivity.update(
            elapsedSeconds: run.elapsedSeconds(),
            distanceMeters: ClientRunningMetrics.distanceMeters(for: location.route),
            isPaused: run.isPaused,
            displayMode: metricMode == .speed ? "speed" : "pace",
            force: force
        )
    }
}

private struct HoldToFinishButton: View {
    let action: () -> Void
    @State private var isHolding = false

    var body: some View {
        Label("Tieni premuto", systemImage: "stop.fill")
            .font(.headline).foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(ClientClay.brandGradient, in: RoundedRectangle(cornerRadius: 16))
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

private struct ClientRunSplitToast: View {
    let split: ClientRunningSplit

    var body: some View {
        HStack(spacing: 12) {
            Text("\(split.index)")
                .font(.headline.monospacedDigit()).foregroundStyle(.white)
                .frame(width: 36, height: 36).background(ClientClay.runAccent, in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text("CHILOMETRO \(split.index) COMPLETATO").font(.caption.weight(.bold)).tracking(0.7)
                Text(ClientRunningFormat.effortDuration(split.durationSeconds))
                    .font(.title3.monospacedDigit().weight(.heavy))
            }
            Spacer()
            Text(ClientRunningFormat.pace(split.averagePaceMinutesPerKm))
                .font(.caption.monospacedDigit().weight(.semibold)).foregroundStyle(ClientClay.inkSoft)
        }
        .padding(12)
        .background(ClientClay.surfaceElevated.opacity(0.97), in: RoundedRectangle(cornerRadius: 17))
        .overlay { RoundedRectangle(cornerRadius: 17).stroke(ClientClay.runAccent.opacity(0.55)) }
        .shadow(color: .black.opacity(0.45), radius: 18, y: 8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Chilometro \(split.index) completato in \(ClientRunningFormat.effortDuration(split.durationSeconds))")
    }
}

private struct ClientRunningCompletionView: View {
    let result: ClientRunningResult
    let onDone: () -> Void
    @EnvironmentObject private var session: ClientSessionStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var visiblePointCount = 1
    @State private var showingSummary = false
    @State private var camera: MapCameraPosition = .automatic

    private var visibleRoute: [ClientRoutePoint] {
        Array(result.route.prefix(max(0, visiblePointCount)))
    }

    private var splits: [ClientRunningSplit] { ClientRunningAchievements.splits(for: result.route) }
    private var recordAchievements: [ClientRunningRecordAchievement] {
        ClientRunningAchievements.recordAchievements(results: session.activity.runningResults)
            .filter { $0.sessionID == result.id }
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
                    .overlay { RoundedRectangle(cornerRadius: 24).stroke(ClientClay.border) }
                    .accessibilityLabel("Mappa del percorso completato")

                    if showingSummary {
                        summary
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    } else {
                        ProgressView("Ripercorriamo la tua corsa…")
                            .tint(ClientClay.accent).padding()
                    }
                }
                .padding(.horizontal, ClientClay.pagePadding).padding(.vertical, 18)
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
            if !recordAchievements.isEmpty { personalBestSummary }
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                summaryMetric("Distanza", value: result.distanceKm.map { "\($0.formatted(.number.precision(.fractionLength(2)))) km" } ?? "Non disponibile")
                summaryMetric("Durata", value: ClientRunningFormat.duration(result.durationSeconds))
                summaryMetric("Ritmo medio", value: result.averagePaceMinutesPerKm.map(ClientRunningFormat.pace) ?? "Non disponibile")
                summaryMetric("Velocità media", value: result.averageSpeedKmh.map { "\($0.formatted(.number.precision(.fractionLength(1)))) km/h" } ?? "Non disponibile")
                summaryMetric("Velocità massima", value: result.maximumSpeedKmh.map { "\($0.formatted(.number.precision(.fractionLength(1)))) km/h" } ?? "Non disponibile")
            }
            if !splits.isEmpty { splitSummary }
            Button("Fine", action: onDone).buttonStyle(ClayPrimaryButtonStyle())
        }
        .clayCard()
    }

    private var personalBestSummary: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(recordAchievements.count == 1 ? "NUOVO PERSONAL BEST" : "NUOVI PERSONAL BEST", systemImage: "trophy.fill")
                .font(.headline.weight(.heavy)).foregroundStyle(ClientClay.gold)
            ForEach(recordAchievements, id: \.target) { achievement in
                let current = ClientRunningAchievements.bestEffort(for: result.route, target: achievement.target)
                let previous = ClientRunningAchievements.leaderboard(
                    results: session.activity.runningResults.filter { $0.completedAt < result.completedAt },
                    target: achievement.target,
                    limit: 1
                ).first
                VStack(alignment: .leading, spacing: 7) {
                    HStack {
                        Text(achievement.target.title).font(.caption.weight(.bold)).tracking(0.8)
                        Spacer()
                        Text(ClientRunningFormat.effortDuration(achievement.durationSeconds))
                            .font(.title3.monospacedDigit().weight(.heavy))
                    }
                    if let current, let previous {
                        HStack {
                            Text("PB precedente \(ClientRunningFormat.effortDuration(previous.effort.durationSeconds))")
                            Spacer()
                            Text("-\(ClientRunningFormat.effortDuration(previous.effort.durationSeconds - current.durationSeconds))")
                        }
                        .font(.caption.monospacedDigit()).foregroundStyle(ClientClay.inkSoft)
                    } else {
                        Text("Prima prestazione registrata su questa distanza")
                            .font(.caption).foregroundStyle(ClientClay.inkSoft)
                    }
                }
                .padding(12).background(ClientClay.inset, in: RoundedRectangle(cornerRadius: 14))
            }
        }
        .padding(15)
        .background(ClientClay.gold.opacity(0.10), in: RoundedRectangle(cornerRadius: 18))
        .overlay { RoundedRectangle(cornerRadius: 18).stroke(ClientClay.gold.opacity(0.38)) }
    }

    private var splitSummary: some View {
        VStack(alignment: .leading, spacing: 10) {
            ClientSectionHeader(title: "Split automatici", detail: "Ogni 1 km", symbol: "flag.checkered")
            ForEach(splits) { split in
                HStack {
                    Text("KM \(split.index)").font(.subheadline.weight(.bold))
                    Spacer()
                    Text(ClientRunningFormat.effortDuration(split.durationSeconds)).font(.headline.monospacedDigit())
                    Text(ClientRunningFormat.pace(split.averagePaceMinutesPerKm)).font(.caption.monospacedDigit()).foregroundStyle(ClientClay.secondaryInk)
                }
                .padding(.vertical, 5)
                .accessibilityElement(children: .combine)
            }
        }
        .padding(14).background(ClientClay.inset, in: RoundedRectangle(cornerRadius: 16))
        .overlay { RoundedRectangle(cornerRadius: 16).stroke(ClientClay.border) }
    }

    private func summaryMetric(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption).foregroundStyle(ClientClay.secondaryInk)
            Text(value).font(.headline.monospacedDigit()).minimumScaleFactor(0.7).lineLimit(2)
        }
        .padding(12).frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
        .background(ClientClay.inset, in: RoundedRectangle(cornerRadius: 14))
        .overlay { RoundedRectangle(cornerRadius: 14).stroke(ClientClay.border) }
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

private struct ClientPersonalBestDetailView: View {
    let target: ClientRunningTarget
    let results: [ClientRunningResult]
    @Environment(\.dismiss) private var dismiss

    private var top: [ClientRunningLeaderboardEntry] {
        ClientRunningAchievements.leaderboard(results: results, target: target)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(target.title).font(.caption.weight(.bold)).tracking(1).foregroundStyle(ClientClay.gold)
                        Text("Migliori prestazioni").font(.system(.title, design: .rounded, weight: .heavy)).foregroundStyle(.white)
                        Text("Un solo miglior tratto per corsa, calcolato sui campioni GPS effettivi.")
                            .font(.subheadline).foregroundStyle(.white.opacity(0.68))
                    }
                    .premiumCard(tint: ClientClay.gold)

                    ForEach(Array(top.enumerated()), id: \.element.id) { index, entry in
                        HStack(alignment: .top, spacing: 13) {
                            Image(systemName: "\(index + 1).circle.fill")
                                .font(.title2).foregroundStyle(index == 0 ? ClientClay.gold : ClientClay.secondaryInk)
                            VStack(alignment: .leading, spacing: 5) {
                                Text(index == 0 ? "RECORD" : "\(index + 1)° TEMPO")
                                    .font(.caption.weight(.bold)).tracking(0.8).foregroundStyle(ClientClay.secondaryInk)
                                Text(ClientRunningFormat.effortDuration(entry.effort.durationSeconds))
                                    .font(.system(.title2, design: .rounded, weight: .heavy).monospacedDigit())
                                Text("\(ClientRunningFormat.pace(entry.effort.averagePaceMinutesPerKm)) · \(entry.effort.averageSpeedKmh?.formatted(.number.precision(.fractionLength(1))) ?? "—") km/h")
                                    .font(.caption.monospacedDigit()).foregroundStyle(ClientClay.inkSoft)
                                Text(entry.completedAt.formatted(date: .long, time: .omitted))
                                    .font(.caption).foregroundStyle(ClientClay.secondaryInk)
                                if (entry.sessionDistanceKm ?? target.kilometers) > target.kilometers + 0.05 {
                                    Label("Tratto interno di una corsa da \(entry.sessionDistanceKm?.formatted(.number.precision(.fractionLength(1))) ?? "—") km", systemImage: "point.topleft.down.to.point.bottomright.curvepath")
                                        .font(.caption2).foregroundStyle(ClientClay.runAccent)
                                }
                            }
                            Spacer()
                            if index > 0, let first = top.first {
                                Text("+\(ClientRunningFormat.effortDuration(entry.effort.durationSeconds - first.effort.durationSeconds))")
                                    .font(.caption.monospacedDigit().weight(.semibold)).foregroundStyle(ClientClay.secondaryInk)
                            }
                        }
                        .clayCard(padding: 15)
                        .accessibilityElement(children: .combine)
                    }
                }
                .padding(.horizontal, ClientClay.pagePadding).padding(.vertical, 18)
            }
            .clientPage()
            .navigationTitle("Top 3 · \(target.title)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Fine") { dismiss() } } }
        }
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

enum ClientRunningFormat {
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

    static func effortDuration(_ seconds: TimeInterval) -> String {
        let value = max(0, Int(seconds.rounded()))
        if value >= 3_600 { return String(format: "%02d:%02d:%02d", value / 3_600, value / 60 % 60, value % 60) }
        return String(format: "%02d:%02d", value / 60, value % 60)
    }
}

private extension ClientRoutePoint {
    var coordinate: CLLocationCoordinate2D { CLLocationCoordinate2D(latitude: latitude, longitude: longitude) }
}
