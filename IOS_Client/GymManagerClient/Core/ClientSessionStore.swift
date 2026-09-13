import Combine
import Foundation
import Supabase

@MainActor
final class ClientSessionStore: ObservableObject {
    enum State {
        case loading
        case onboarding
        case active(identity: ClientIdentity, snapshot: ClientSnapshot, source: ClientDataSource)
        case failure(String)
    }

    @Published private(set) var state: State = .loading
    @Published private(set) var agenda: [PersonalAgendaTask] = []
    @Published var isSubmitting = false
    @Published var notice: String?

    private let auth: AuthClient
    private let repository: ClientRepository
    private let agendaStore: PersonalAgendaStore

    init(
        auth: AuthClient = ClientSupabaseProvider.client.auth,
        repository: ClientRepository = .shared,
        agendaStore: PersonalAgendaStore = PersonalAgendaStore()
    ) {
        self.auth = auth
        self.repository = repository
        self.agendaStore = agendaStore
    }

    func prepare() async {
        guard ClientSupabaseProvider.isConfigured else {
            state = .failure(ClientAppError.configuration.localizedDescription)
            return
        }
        do {
            let session = try await auth.session
            await load(userID: session.user.id, email: session.user.email)
        } catch {
            state = .onboarding
        }
    }

    func signIn(identifier: String, password: String) async {
        let email = ClientIdentityLogic.technicalEmail(for: identifier)
        guard !email.isEmpty, !password.isEmpty else {
            notice = "Inserisci email o username e password."
            return
        }
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            let response = try await auth.signIn(email: email, password: password)
            await load(userID: response.user.id, email: response.user.email)
        } catch {
            try? await auth.signOut(scope: .local)
            notice = (error as? LocalizedError)?.errorDescription ?? "Accesso non riuscito."
        }
    }

    func signOut() async {
        try? await auth.signOut(scope: .local)
        agenda = []
        notice = nil
        state = .onboarding
    }

    func showOnboarding() {
        notice = nil
        state = .onboarding
    }

    func refresh() async {
        guard case .active(let identity, _, let source) = state, source == .live else { return }
        state = .loading
        let snapshot = await repository.snapshot(for: identity)
        state = .active(identity: identity, snapshot: snapshot, source: .live)
    }

    func updatePassword(_ password: String) async {
        guard password.count >= 12 else {
            notice = "Usa almeno 12 caratteri."
            return
        }
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            try await auth.update(user: UserAttributes(password: password))
            notice = "Password aggiornata."
        } catch {
            notice = "Password non aggiornata. Verifica la sessione e i requisiti di sicurezza."
        }
    }

    #if DEBUG
    func startDemo() {
        let identity = ClientDemoData.identity
        agenda = agendaStore.load(userID: identity.authUserID, source: .demo)
        state = .active(identity: identity, snapshot: ClientDemoData.snapshot, source: .demo)
    }
    #endif

    func addAgendaTask(title: String, date: Date?, notes: String, kind: PersonalAgendaKind, priority: PersonalAgendaPriority) {
        guard case .active(let identity, _, let source) = state else { return }
        do {
            let clean = try PersonalAgendaStore.validatedTitle(title)
            agenda.append(PersonalAgendaTask(id: UUID(), title: clean, date: date, notes: notes, kind: kind, priority: priority, isCompleted: false))
            try agendaStore.save(agenda, userID: identity.authUserID, source: source)
        } catch { notice = (error as? LocalizedError)?.errorDescription ?? "Agenda non aggiornata." }
    }

    func toggleAgendaTask(_ id: UUID) {
        guard case .active(let identity, _, let source) = state,
              let index = agenda.firstIndex(where: { $0.id == id }) else { return }
        agenda[index].isCompleted.toggle()
        do { try agendaStore.save(agenda, userID: identity.authUserID, source: source) }
        catch { notice = "Agenda non aggiornata." }
    }

    func deleteAgendaTask(_ id: UUID) {
        guard case .active(let identity, _, let source) = state else { return }
        agenda.removeAll { $0.id == id }
        do { try agendaStore.save(agenda, userID: identity.authUserID, source: source) }
        catch { notice = "Agenda non aggiornata." }
    }

    private func load(userID: UUID, email: String?) async {
        state = .loading
        do {
            let identity = try await repository.identity(authUserID: userID, email: email)
            let snapshot = await repository.snapshot(for: identity)
            agenda = agendaStore.load(userID: identity.authUserID, source: .live)
            state = .active(identity: identity, snapshot: snapshot, source: .live)
        } catch {
            state = .failure((error as? LocalizedError)?.errorDescription ?? "Impossibile verificare il profilo Cliente.")
        }
    }
}
