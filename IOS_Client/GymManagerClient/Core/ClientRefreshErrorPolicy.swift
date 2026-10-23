import Foundation
import Supabase

/// A refresh only reads data: errors must never imply that a Trainer link was changed.
enum ClientRefreshErrorPolicy {
    static func isCancellation(_ error: Error) -> Bool {
        if error is CancellationError { return true }
        let underlying = error as NSError
        return underlying.domain == NSURLErrorDomain && underlying.code == NSURLErrorCancelled
    }

    static func message(for error: Error) -> String? {
        if isCancellation(error) { return nil }
        if let appError = error as? ClientAppError { return appError.errorDescription }
        let underlying = error as NSError
        if underlying.domain == NSURLErrorDomain {
            return "Connessione non disponibile o troppo lenta. Riprova ad aggiornare: i dati già caricati sono conservati."
        }
        if error is AuthError {
            return "Non è stato possibile verificare la sessione. Riprova; se il problema continua, accedi di nuovo."
        }
        if let databaseError = error as? PostgrestError {
            if ["PGRST301", "PGRST302", "PGRST303"].contains(databaseError.code ?? "") {
                return "La sessione non è valida. Accedi di nuovo."
            }
            if databaseError.code == "42501" {
                return "Non è stato possibile leggere il profilo: accesso non autorizzato."
            }
        }
        return "Non è stato possibile aggiornare i dati. Riprova: i dati già caricati sono conservati."
    }

    /// Never log payloads, URLs, tokens, database messages or personal data.
    static func diagnosticCode(for error: Error) -> String {
        if isCancellation(error) { return "cancelled" }
        if let databaseError = error as? PostgrestError,
           let code = databaseError.code,
           code.range(of: #"^[A-Z0-9]{5,12}$"#, options: .regularExpression) != nil {
            return code
        }
        let underlying = error as NSError
        if underlying.domain == NSURLErrorDomain { return "url_\(underlying.code)" }
        if error is DecodingError { return "decoding" }
        if error is AuthError { return "auth" }
        if error is ClientAppError { return "client_state" }
        return "unknown"
    }
}
