@preconcurrency import CoreLocation
import Combine
import Foundation

@MainActor
final class RunningLocationService: NSObject, ObservableObject, @preconcurrency CLLocationManagerDelegate {
    enum State: Equatable {
        case idle
        case requestingPermission
        case tracking
        case reducedAccuracy
        case denied
        case restricted
        case unavailable
        case failed(String)
    }

    @Published private(set) var state: State = CLLocationManager.locationServicesEnabled() ? .idle : .unavailable
    @Published private(set) var route: [ClientRoutePoint] = []
    @Published private(set) var currentSpeedMetersPerSecond: Double?
    @Published private(set) var stabilizedSpeedMetersPerSecond: Double?
    @Published private(set) var maximumSpeedMetersPerSecond: Double?

    private let manager = CLLocationManager()
    private var shouldTrack = false
    private var previousAcceptedSpeed: Double?
    private var accumulatedActiveSeconds: TimeInterval = 0
    private var activeStartedAt: Date?
    private var lastStabilizedElapsed: TimeInterval = 0
    private let stabilizedUpdateInterval: TimeInterval = 25
    private let smoothingWindow: TimeInterval = 30

    override init() {
        super.init()
        manager.delegate = self
        manager.activityType = .fitness
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = 2
        manager.pausesLocationUpdatesAutomatically = false
    }

    var distanceKm: Double { ClientRunningMetrics.distanceMeters(for: route) / 1_000 }

    func beginNewRun(now: Date = Date()) {
        route = []
        currentSpeedMetersPerSecond = nil
        stabilizedSpeedMetersPerSecond = nil
        maximumSpeedMetersPerSecond = nil
        previousAcceptedSpeed = nil
        accumulatedActiveSeconds = 0
        activeStartedAt = now
        lastStabilizedElapsed = 0
        beginTracking()
    }

    func resumeRun(
        route existingRoute: [ClientRoutePoint],
        maximumSpeedMetersPerSecond: Double?,
        elapsedSeconds: TimeInterval,
        now: Date = Date()
    ) {
        if route.isEmpty { route = existingRoute }
        self.maximumSpeedMetersPerSecond = maximumSpeedMetersPerSecond
        accumulatedActiveSeconds = max(0, elapsedSeconds)
        activeStartedAt = now
        lastStabilizedElapsed = accumulatedActiveSeconds
        stabilizedSpeedMetersPerSecond = nil
        beginTracking()
    }

    func stopTracking(now: Date = Date()) {
        captureElapsed(at: now)
        shouldTrack = false
        manager.stopUpdatingLocation()
        manager.allowsBackgroundLocationUpdates = false
        manager.showsBackgroundLocationIndicator = false
        currentSpeedMetersPerSecond = nil
        stabilizedSpeedMetersPerSecond = nil
        if state != .denied, state != .restricted, state != .unavailable { state = .idle }
    }

    func pauseTracking(now: Date = Date()) {
        captureElapsed(at: now)
        shouldTrack = false
        manager.stopUpdatingLocation()
        manager.allowsBackgroundLocationUpdates = false
        manager.showsBackgroundLocationIndicator = false
        currentSpeedMetersPerSecond = nil
        stabilizedSpeedMetersPerSecond = nil
        if state != .denied, state != .restricted, state != .unavailable { state = .idle }
    }

    private func beginTracking() {
        shouldTrack = true
        guard CLLocationManager.locationServicesEnabled() else {
            state = .unavailable
            return
        }
        switch manager.authorizationStatus {
        case .notDetermined:
            state = .requestingPermission
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            startAuthorizedTracking()
        case .denied:
            state = .denied
        case .restricted:
            state = .restricted
        @unknown default:
            state = .failed("Stato autorizzazione posizione non riconosciuto.")
        }
    }

    private func startAuthorizedTracking() {
        guard shouldTrack else { return }
        state = manager.accuracyAuthorization == .reducedAccuracy ? .reducedAccuracy : .tracking
        manager.allowsBackgroundLocationUpdates = true
        manager.showsBackgroundLocationIndicator = true
        manager.startUpdatingLocation()
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard shouldTrack else { return }
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            startAuthorizedTracking()
        case .denied:
            state = .denied
        case .restricted:
            state = .restricted
        case .notDetermined:
            state = .requestingPermission
        @unknown default:
            state = .failed("Stato autorizzazione posizione non riconosciuto.")
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        guard shouldTrack else { return }
        state = .failed(error.localizedDescription)
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard shouldTrack else { return }
        for location in locations.sorted(by: { $0.timestamp < $1.timestamp }) {
            accept(location)
        }
    }

    private func accept(_ location: CLLocation) {
        guard location.horizontalAccuracy >= 0, location.horizontalAccuracy <= 25 else { return }
        if let previous = route.last {
            guard location.timestamp > previous.timestamp else { return }
            let priorLocation = CLLocation(latitude: previous.latitude, longitude: previous.longitude)
            let segmentDistance = location.distance(from: priorLocation)
            guard segmentDistance >= 2, segmentDistance <= 250 else { return }
        }

        let plausibleSpeed = location.speed >= 0 && location.speed <= 12 ? location.speed : nil
        route.append(ClientRoutePoint(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            timestamp: location.timestamp,
            horizontalAccuracy: location.horizontalAccuracy,
            speedMetersPerSecond: plausibleSpeed,
            elapsedSeconds: activeElapsed(at: location.timestamp)
        ))
        currentSpeedMetersPerSecond = plausibleSpeed
        refreshStabilizedSpeedIfNeeded()

        if let speed = plausibleSpeed, let previousSpeed = previousAcceptedSpeed,
           abs(speed - previousSpeed) <= max(1.5, previousSpeed * 0.45) {
            maximumSpeedMetersPerSecond = max(maximumSpeedMetersPerSecond ?? 0, speed)
        }
        previousAcceptedSpeed = plausibleSpeed
        state = manager.accuracyAuthorization == .reducedAccuracy ? .reducedAccuracy : .tracking
    }

    private func activeElapsed(at date: Date) -> TimeInterval {
        accumulatedActiveSeconds + (activeStartedAt.map { max(0, date.timeIntervalSince($0)) } ?? 0)
    }

    private func captureElapsed(at date: Date) {
        guard let activeStartedAt else { return }
        accumulatedActiveSeconds += max(0, date.timeIntervalSince(activeStartedAt))
        self.activeStartedAt = nil
    }

    private func refreshStabilizedSpeedIfNeeded() {
        guard let latest = route.last,
              let latestElapsed = latest.elapsedSeconds,
              latestElapsed - lastStabilizedElapsed >= stabilizedUpdateInterval else { return }
        lastStabilizedElapsed = latestElapsed
        let speed = ClientRunningMetrics.stabilizedSpeedMetersPerSecond(for: route, windowSeconds: smoothingWindow)
        if let speed, speed >= 0.8, speed <= 12 { stabilizedSpeedMetersPerSecond = speed }
        else { stabilizedSpeedMetersPerSecond = nil }
    }
}
