import Foundation
import Supabase

struct ClientAppConfiguration: Sendable {
    let supabaseURL: URL
    let publishableKey: String

    static func load(bundle: Bundle = .main) throws -> ClientAppConfiguration {
        guard let rawURL = bundle.object(forInfoDictionaryKey: "SUPABASE_URL") as? String,
              let components = URLComponents(string: rawURL.trimmingCharacters(in: .whitespacesAndNewlines)),
              components.scheme?.lowercased() == "https",
              components.user == nil,
              components.password == nil,
              let host = components.host, !host.isEmpty,
              let url = components.url,
              let key = bundle.object(forInfoDictionaryKey: "SUPABASE_PUBLISHABLE_KEY") as? String,
              key.hasPrefix("sb_publishable_") || key.hasPrefix("eyJ") else {
            throw ClientAppError.configuration
        }
        return ClientAppConfiguration(supabaseURL: url, publishableKey: key)
    }
}

enum ClientSupabaseProvider {
    private static let configuration = try? ClientAppConfiguration.load()
    static var isConfigured: Bool { configuration != nil }

    static let client: SupabaseClient = {
        let config = configuration ?? ClientAppConfiguration(
            supabaseURL: URL(string: "https://configuration.invalid")!,
            publishableKey: "sb_publishable_configuration_missing"
        )
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown"
        return SupabaseClient(
            supabaseURL: config.supabaseURL,
            supabaseKey: config.publishableKey,
            options: SupabaseClientOptions(
                auth: .init(storage: KeychainLocalStorage(service: "com.gymmanager.client.ios.auth")),
                global: .init(headers: ["x-client-info": "gymmanager-client-ios/\(version)"])
            )
        )
    }()
}

enum ClientAppError: LocalizedError, Equatable, Sendable {
    case configuration
    case unsupportedRole
    case inactiveProfile
    case duplicateClientLinks
    case invalidClientLink
    case registrationUnavailable
    case trainerCodeUnavailable
    case message(String)

    var errorDescription: String? {
        switch self {
        case .configuration: "Configurazione Client non disponibile."
        case .unsupportedRole: "Questo account usa l’app dedicata ai professionisti."
        case .inactiveProfile: "L’account Cliente non è attivo. Contatta il tuo Trainer."
        case .duplicateClientLinks: "Sono presenti più collegamenti Cliente. Contatta l’assistenza."
        case .invalidClientLink: "Il collegamento al Trainer non è valido o non è attivo."
        case .registrationUnavailable: "La registrazione autonoma sarà disponibile nella Fase 2. Nessun account è stato creato."
        case .trainerCodeUnavailable: "Il collegamento tramite codice Trainer sarà disponibile nella Fase 2. Nessun codice è stato inviato o consumato."
        case .message(let text): text
        }
    }
}

protocol TrainerCodeActivating: Sendable {
    func activate(code: String) async throws
}

struct TrainerCodeService: TrainerCodeActivating {
    static func normalized(_ code: String) -> String {
        code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    }

    func activate(code: String) async throws {
        _ = Self.normalized(code)
        throw ClientAppError.trainerCodeUnavailable
    }
}
