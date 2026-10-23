import Foundation
import OSLog

enum ClientLoadPhase: String, Sendable {
    case idle, authBootstrap, loading, loaded, empty, error
}

enum ClientContentSection: String, CaseIterable, Codable, Sendable {
    case workout = "WORKOUT", nutrition = "NUTRITION", appointments = "APPOINTMENTS", progress = "PROGRESS"

    var title: String {
        switch self {
        case .workout: "Allenamento"
        case .nutrition: "Nutrizione"
        case .appointments: "Appuntamenti"
        case .progress: "Progressi"
        }
    }
}

enum ClientContentLoadState: Codable, Equatable, Sendable {
    case idle, loading, loaded, empty
    case failed(String)

    var failure: String? {
        if case .failed(let message) = self { return message }
        return nil
    }

    var isPending: Bool { self == .idle || self == .loading }
}

/// Common presentation readiness, not a retry policy or authentication shortcut.
enum ClientContentReadiness {
    static func resolve(_ section: ClientContentLoadState, phase: ClientLoadPhase, hasActiveIdentity: Bool) -> ClientContentLoadState {
        guard hasActiveIdentity, phase != .idle, phase != .authBootstrap else { return .loading }
        return section // A real ready-state failure remains visible, including during explicit refresh.
    }
}

extension ClientSnapshot {
    func contentState(for section: ClientContentSection) -> ClientContentLoadState {
        if let state = contentStates?[section] { return state }
        // Compatibility with demo and older snapshots, not a loading/error fallback.
        if let warning = warnings.first(where: { $0.hasPrefix(section.title + ":") }) {
            return .failed(warning)
        }
        switch section {
        case .workout: return workout == nil ? .empty : .loaded
        case .nutrition: return nutrition == nil ? .empty : .loaded
        case .appointments: return appointments.isEmpty ? .empty : .loaded
        case .progress: return progress.isEmpty ? .empty : .loaded
        }
    }

    mutating func setContentState(_ state: ClientContentLoadState, for section: ClientContentSection) {
        if contentStates == nil { contentStates = [:] }
        contentStates?[section] = state
    }

    mutating func retainFailedSections(from previous: ClientSnapshot?) {
        guard let previous else { return }
        if contentState(for: .workout).failure != nil { workout = previous.workout }
        if contentState(for: .nutrition).failure != nil { nutrition = previous.nutrition }
        if contentState(for: .appointments).failure != nil { appointments = previous.appointments }
        if contentState(for: .progress).failure != nil { progress = previous.progress }
    }

    var loadPhase: ClientLoadPhase {
        let states = ClientContentSection.allCases.map { contentState(for: $0) }
        if states.contains(where: { $0.failure != nil }) { return .error }
        if states.contains(where: \.isPending) { return .loading }
        return states.allSatisfy { $0 == .empty } ? .empty : .loaded
    }
}

/// Random request IDs and fixed operation/stage codes only. Never log user IDs,
/// URLs, server messages, tokens, names or fitness/health payloads.
enum ClientLoadDiagnostics {
    private static let logger = Logger(subsystem: "com.gymmanager.client.ios", category: "ContentRead")

    static func record(_ component: String, requestID: UUID, event: String,
                       stage: String, code: String = "none",
                       sessionReady: Bool = false, clientReady: Bool = false, trainerReady: Bool = false,
                       prerequisitesReady: Bool = false) {
        #if DEBUG
        logger.debug("[IOS_CLIENT][\(component, privacy: .public)] request_id=\(requestID.uuidString, privacy: .public) event=\(event, privacy: .public) stage=\(stage, privacy: .public) code=\(code, privacy: .public) prerequisites_ready=\(prerequisitesReady, privacy: .public) sessionReady=\(sessionReady, privacy: .public) clientReady=\(clientReady, privacy: .public) trainerReady=\(trainerReady, privacy: .public)")
        #endif
    }
}
