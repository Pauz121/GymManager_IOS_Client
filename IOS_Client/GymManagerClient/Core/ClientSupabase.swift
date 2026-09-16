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
    case message(String)

    var errorDescription: String? {
        switch self {
        case .configuration: "Configurazione Client non disponibile."
        case .unsupportedRole: "Questo account usa l’app dedicata ai professionisti."
        case .inactiveProfile: "L’account Cliente non è attivo. Contatta il tuo Trainer."
        case .duplicateClientLinks: "Sono presenti più collegamenti Cliente. Contatta l’assistenza."
        case .invalidClientLink: "Il collegamento al Trainer non è valido o non è attivo."
        case .message(let text): text
        }
    }
}

protocol TrainerCodeActivating: Sendable {
    func activate(code: String) async throws -> TrainerCodeActivationResult
}

struct TrainerCodeActivationResult: Decodable, Equatable, Sendable {
    let clientID: UUID
    let trainerID: UUID
    let alreadyLinked: Bool

    enum CodingKeys: String, CodingKey {
        case alreadyLinked
        case clientID = "clientId"
        case trainerID = "trainerId"
    }
}

private struct TrainerCodeFunctionError: Decodable {
    let error: String
}

struct TrainerCodeService: TrainerCodeActivating {
    static func normalized(_ code: String) -> String {
        code.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: " ", with: "")
            .uppercased()
    }

    static func isValid(_ code: String) -> Bool {
        normalized(code).range(
            of: #"^GM-[0-9A-F]{4}(-[0-9A-F]{4}){4}$"#,
            options: .regularExpression
        ) != nil
    }

    func activate(code: String) async throws -> TrainerCodeActivationResult {
        let normalizedCode = Self.normalized(code)
        guard Self.isValid(normalizedCode) else {
            throw ClientAppError.message("Inserisci un codice GymManager valido.")
        }

        let accessToken: String
        do {
            let session = try await ClientSupabaseProvider.client.auth.session
            accessToken = session.accessToken
        } catch {
            throw ClientAppError.message("Sessione Cliente non valida. Accedi di nuovo prima di usare il codice Trainer.")
        }

        do {
            let result: TrainerCodeActivationResult = try await ClientSupabaseProvider.client.functions.invoke(
                "redeem-client-link-code",
                options: FunctionInvokeOptions(
                    headers: ["Authorization": "Bearer \(accessToken)"],
                    body: ["code": normalizedCode]
                )
            )
            return result
        } catch FunctionsError.httpError(_, let data) {
            let message = (try? JSONDecoder().decode(TrainerCodeFunctionError.self, from: data))?.error
                ?? "Collegamento al Trainer non riuscito."
            throw ClientAppError.message(message)
        } catch {
            throw ClientAppError.message("Connessione non disponibile. Riprova tra poco.")
        }
    }
}
