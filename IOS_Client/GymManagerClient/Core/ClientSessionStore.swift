import Combine
import Foundation
import OSLog
import Supabase

enum ClientEmailVerificationStatus: Equatable {
    case unavailable
    case checking(email: String?)
    case unverified(email: String)
    case verified(email: String)

    var email: String? {
        switch self {
        case .checking(let email): email
        case .unverified(let email), .verified(let email): email
        case .unavailable: nil
        }
    }
}

@MainActor
final class ClientSessionStore: ObservableObject {
    enum State {
        case loading
        case onboarding
        case emailConfirmation(email: String)
        case active(identity: ClientIdentity, snapshot: ClientSnapshot, source: ClientDataSource)
        case failure(String)
    }

    @Published private(set) var state: State = .loading
    @Published private(set) var agenda: [PersonalAgendaTask] = []
    @Published private(set) var activity: ClientActivityState = .empty
    @Published private(set) var restReadyExerciseID: UUID?
    @Published private(set) var personalContent: ClientPersonalContentState = .empty
    @Published private(set) var shouldOfferTrainerCode = false
    @Published private(set) var isRefreshing = false
    @Published private(set) var readPhase: ClientLoadPhase = .idle
    @Published private(set) var refreshError: String?
    @Published var isSubmitting = false
    @Published var notice: String?
    @Published var registrationIssue: ClientRegistrationIssue?
    @Published private(set) var registrationStage: ClientRegistrationStage = .idle
    @Published private(set) var emailVerificationStatus: ClientEmailVerificationStatus = .unavailable

    var canResumePendingRegistration: Bool { pendingRegistration != nil }

    private let auth: AuthClient
    private let repository: ClientRepository
    private let agendaStore: PersonalAgendaStore
    private let activityStore: ClientActivityStore
    private let personalContentStore: ClientPersonalContentStore
    private let personalRepository: ClientPersonalRepository
    private let trainerCodeActivator: any TrainerCodeActivating
    private var pendingRegistration: PendingRegistration?
    private var exerciseCatalogCache: [ClientExerciseCatalogItem]?
    private var foodCatalogCache: [ClientFoodCatalogItem]?
    private var refreshTask: Task<Void, Never>?
    private var refreshGeneration = UUID()
    private var sessionGeneration = UUID()
    private var bootstrapTask: Task<Void, Never>?

    private struct PendingRegistration {
        let email: String
        let password: String
    }

    private static let registrationLogger = Logger(
        subsystem: "com.gymmanager.client.ios",
        category: "ClientRegistration"
    )

    init(
        auth: AuthClient = ClientSupabaseProvider.client.auth,
        repository: ClientRepository = .shared,
        agendaStore: PersonalAgendaStore = PersonalAgendaStore(),
        activityStore: ClientActivityStore = ClientActivityStore(),
        personalContentStore: ClientPersonalContentStore = ClientPersonalContentStore(),
        personalRepository: ClientPersonalRepository = ClientPersonalRepository(),
        trainerCodeActivator: any TrainerCodeActivating = TrainerCodeService()
    ) {
        self.auth = auth
        self.repository = repository
        self.agendaStore = agendaStore
        self.activityStore = activityStore
        self.personalContentStore = personalContentStore
        self.personalRepository = personalRepository
        self.trainerCodeActivator = trainerCodeActivator
    }

    func prepare() async {
        if let bootstrapTask { await bootstrapTask.value; return }
        if case .active = state { return }
        guard ClientSupabaseProvider.isConfigured else {
            state = .failure(ClientAppError.configuration.localizedDescription)
            return
        }
        invalidateSessionReads()
        let generation = sessionGeneration
        // Initial restoration, like refresh, is session-owned rather than view-owned.
        let task = Task { @MainActor [weak self] in
            guard let self else { return }
            await self.performPrepare(generation: generation)
        }
        bootstrapTask = task
        await task.value
    }

    private func performPrepare(generation: UUID) async {
        guard sessionGeneration == generation, !Task.isCancelled else { return }
        let requestID = UUID()
        readPhase = .authBootstrap
        ClientLoadDiagnostics.record("AUTH", requestID: requestID, event: "start", stage: "restore")
        defer { if sessionGeneration == generation { bootstrapTask = nil } }
        do {
            let session = try await auth.session
            guard sessionGeneration == generation, !Task.isCancelled else {
                ClientLoadDiagnostics.record("AUTH", requestID: requestID, event: "stale", stage: "restore")
                return
            }
            updateEmailVerificationStatus(from: session.user)
            ClientLoadDiagnostics.record("AUTH", requestID: requestID, event: "success", stage: "restore", sessionReady: true)
            await load(userID: session.user.id, email: session.user.email, ownerGeneration: generation, requestID: requestID)
        } catch {
            guard sessionGeneration == generation else { return }
            if ClientRefreshErrorPolicy.isCancellation(error) || Task.isCancelled {
                readPhase = .idle
                ClientLoadDiagnostics.record("AUTH", requestID: requestID, event: "cancel", stage: "restore")
                return
            }
            ClientLoadDiagnostics.record("AUTH", requestID: requestID, event: "failure", stage: "restore", code: ClientRefreshErrorPolicy.diagnosticCode(for: error))
            emailVerificationStatus = .unavailable
            if let authError = error as? AuthError, case .sessionMissing = authError {
                readPhase = .idle
                state = .onboarding
            } else {
                readPhase = .error
                state = .failure(ClientRefreshErrorPolicy.message(for: error) ?? "Impossibile ripristinare la sessione.")
            }
        }
    }

    func signIn(identifier: String, password: String) async {
        let email = ClientIdentityLogic.technicalEmail(for: identifier)
        guard !email.isEmpty, !password.isEmpty else {
            notice = "Inserisci email o username e password."
            return
        }
        isSubmitting = true
        registrationIssue = nil
        invalidateSessionReads()
        let generation = sessionGeneration
        defer { isSubmitting = false }
        do {
            let response = try await auth.signIn(email: email, password: password)
            guard sessionGeneration == generation, !Task.isCancelled else { return }
            updateEmailVerificationStatus(from: response.user)
            await load(userID: response.user.id, email: response.user.email, ownerGeneration: generation)
        } catch {
            guard sessionGeneration == generation, !ClientRefreshErrorPolicy.isCancellation(error) else { return }
            try? await auth.signOut(scope: .local)
            guard sessionGeneration == generation else { return }
            notice = (error as? LocalizedError)?.errorDescription ?? "Accesso non riuscito."
        }
    }

    func register(_ input: ClientRegistrationInput) async {
        registrationStage = .validating
        if let issue = ClientRegistrationValidation.stepOneIssue(for: input)
            ?? ClientRegistrationValidation.stepTwoIssue(for: input) {
            registrationIssue = issue
            registrationStage = .failed
            Self.logRegistration(stage: .validating, message: "Client-side validation rejected the form")
            return
        }
        guard let biologicalSex = input.biologicalSex else { return }

        let firstName = ClientRegistrationValidation.normalizedName(input.firstName)
        let lastName = ClientRegistrationValidation.normalizedName(input.lastName)
        let email = ClientRegistrationValidation.normalizedEmail(input.email)
        let username = ClientRegistrationValidation.normalizedUsername(input.username)

        isSubmitting = true
        registrationIssue = nil
        registrationStage = .authSignUp
        pendingRegistration = nil
        invalidateSessionReads()
        let generation = sessionGeneration
        Self.logRegistration(stage: .authSignUp, message: "Starting Supabase Auth sign-up")
        defer { isSubmitting = false }
        do {
            let response = try await auth.signUp(
                email: email,
                password: input.password,
                data: [
                    "account_type": .string("client_self_registration"),
                    "username": .string(username),
                    "first_name": .string(firstName),
                    "last_name": .string(lastName),
                    "biological_sex": .string(biologicalSex.rawValue)
                ]
            )

            guard sessionGeneration == generation, !Task.isCancelled else { return }

            Self.logRegistration(
                stage: .authSignUp,
                message: "Auth user created",
                userID: response.user.id
            )

            if let activeSession = response.session {
                registrationStage = .profileVerification
                updateEmailVerificationStatus(from: activeSession.user)
                Self.logRegistration(
                    stage: .sessionCreation,
                    message: "Session returned by sign-up",
                    userID: activeSession.user.id
                )
                await load(userID: activeSession.user.id, email: activeSession.user.email, ownerGeneration: generation)
            } else {
                pendingRegistration = PendingRegistration(email: email, password: input.password)
                registrationStage = .emailConfirmationRequired
                Self.logRegistration(
                    stage: .emailConfirmationRequired,
                    message: "Auth user created; email confirmation required before session",
                    userID: response.user.id
                )
                state = .emailConfirmation(email: email)
            }
        } catch let AuthError.weakPassword(message, _) {
            guard sessionGeneration == generation, !Task.isCancelled else { return }
            registrationStage = .failed
            Self.logRegistration(stage: .authSignUp, message: message, code: "weak_password")
            registrationIssue = ClientRegistrationErrorClassifier.issue(message: message, code: "weak_password")
        } catch let AuthError.api(message, errorCode, _, response) {
            guard sessionGeneration == generation, !Task.isCancelled else { return }
            registrationStage = .failed
            Self.logRegistration(
                stage: .authSignUp,
                message: message,
                status: response.statusCode,
                code: errorCode.rawValue
            )
            registrationIssue = ClientRegistrationErrorClassifier.issue(
                message: message,
                code: errorCode.rawValue,
                status: response.statusCode
            )
        } catch {
            guard sessionGeneration == generation, !Task.isCancelled,
                  !ClientRefreshErrorPolicy.isCancellation(error) else { return }
            registrationStage = .failed
            Self.logRegistration(stage: .authSignUp, message: error.localizedDescription)
            registrationIssue = ClientRegistrationErrorClassifier.issue(message: error.localizedDescription)
        }
    }

    func resumePendingRegistrationAfterEmailConfirmation() async {
        guard let pendingRegistration else {
            notice = "La registrazione non è più in memoria. Accedi con email e password dopo aver confermato l’indirizzo."
            return
        }

        isSubmitting = true
        registrationIssue = nil
        registrationStage = .sessionCreation
        invalidateSessionReads()
        let generation = sessionGeneration
        Self.logRegistration(stage: .sessionCreation, message: "Attempting session after email confirmation")
        defer { isSubmitting = false }

        do {
            let response = try await auth.signIn(
                email: pendingRegistration.email,
                password: pendingRegistration.password
            )
            guard sessionGeneration == generation, !Task.isCancelled else { return }
            self.pendingRegistration = nil
            registrationStage = .profileVerification
            updateEmailVerificationStatus(from: response.user)
            Self.logRegistration(
                stage: .sessionCreation,
                message: "Confirmed account session created",
                userID: response.user.id
            )
            await load(userID: response.user.id, email: response.user.email, ownerGeneration: generation)
        } catch let AuthError.api(message, errorCode, _, response) {
            guard sessionGeneration == generation, !Task.isCancelled else { return }
            Self.logRegistration(
                stage: .sessionCreation,
                message: message,
                status: response.statusCode,
                code: errorCode.rawValue
            )
            let issue = ClientRegistrationErrorClassifier.issue(
                message: message,
                code: errorCode.rawValue,
                status: response.statusCode
            )
            if errorCode.rawValue == "email_not_confirmed" {
                registrationStage = .emailConfirmationRequired
                notice = issue.message
            } else {
                registrationStage = .failed
                registrationIssue = issue
                notice = issue.message
            }
        } catch {
            guard sessionGeneration == generation, !Task.isCancelled,
                  !ClientRefreshErrorPolicy.isCancellation(error) else { return }
            registrationStage = .failed
            Self.logRegistration(stage: .sessionCreation, message: error.localizedDescription)
            notice = ClientRegistrationErrorClassifier.issue(message: error.localizedDescription).message
        }
    }

    @discardableResult
    func connectTrainer(code: String) async -> Bool {
        guard case .active(let identity, _, let source) = state,
              source == .live,
              identity.mode == .standalone else {
            notice = "Il codice può essere usato solo da un account Cliente non ancora collegato."
            return false
        }
        guard TrainerCodeService.isValid(code) else {
            notice = "Inserisci un codice GymManager valido."
            return false
        }

        isSubmitting = true
        let generation = sessionGeneration
        defer { isSubmitting = false }
        do {
            let activation = try await trainerCodeActivator.activate(code: code)
            guard sessionGeneration == generation, !Task.isCancelled else { return false }
            try await repository.completeInitialOnboarding()
            guard sessionGeneration == generation, !Task.isCancelled else { return false }
            await load(userID: identity.authUserID, email: identity.email, ownerGeneration: generation)
            guard sessionGeneration == generation, !Task.isCancelled else { return false }
            guard case .active(let linkedIdentity, _, _) = state,
                  linkedIdentity.clientID == activation.clientID,
                  linkedIdentity.trainerID == activation.trainerID else {
                notice = "Codice riscattato, ma il profilo non è ancora aggiornato. Trascina per ricaricare."
                return false
            }
            notice = activation.alreadyLinked ? "Account già collegato al Trainer." : "Collegamento al Trainer completato."
            return true
        } catch {
            guard sessionGeneration == generation, !Task.isCancelled,
                  !ClientRefreshErrorPolicy.isCancellation(error) else { return false }
            notice = (error as? LocalizedError)?.errorDescription ?? "Collegamento al Trainer non riuscito."
            return false
        }
    }

    func skipTrainerLinking() async {
        guard case .active(let identity, _, let source) = state, source == .live else { return }
        isSubmitting = true
        let generation = sessionGeneration
        defer { isSubmitting = false }
        do {
            try await repository.completeInitialOnboarding()
            guard sessionGeneration == generation, !Task.isCancelled else { return }
            await load(userID: identity.authUserID, email: identity.email, ownerGeneration: generation)
        } catch {
            guard sessionGeneration == generation, !Task.isCancelled,
                  !ClientRefreshErrorPolicy.isCancellation(error) else { return }
            notice = (error as? LocalizedError)?.errorDescription ?? "Non è stato possibile completare il primo accesso."
        }
    }

    func signOut() async {
        invalidateSessionReads()
        let generation = sessionGeneration
        readPhase = .loading
        state = .loading
        try? await auth.signOut(scope: .local)
        guard sessionGeneration == generation else { return }
        agenda = []
        activity = .empty
        restReadyExerciseID = nil
        personalContent = .empty
        shouldOfferTrainerCode = false
        notice = nil
        registrationIssue = nil
        pendingRegistration = nil
        registrationStage = .idle
        emailVerificationStatus = .unavailable
        readPhase = .idle
        state = .onboarding
    }

    func showOnboarding() {
        invalidateSessionReads()
        shouldOfferTrainerCode = false
        notice = nil
        registrationIssue = nil
        pendingRegistration = nil
        registrationStage = .idle
        emailVerificationStatus = .unavailable
        state = .onboarding
    }

    func refreshEmailVerification() async {
        guard case .active(let identity, _, let source) = state, source == .live else { return }
        let generation = sessionGeneration
        let previousStatus = emailVerificationStatus
        emailVerificationStatus = .checking(email: previousStatus.email)
        do {
            let user = try await auth.user()
            guard sessionGeneration == generation, user.id == identity.authUserID, !Task.isCancelled else { return }
            updateEmailVerificationStatus(from: user)
        } catch {
            guard sessionGeneration == generation else { return }
            emailVerificationStatus = previousStatus
        }
    }

    func resendEmailVerification(to explicitEmail: String? = nil) async {
        let email = explicitEmail ?? emailVerificationStatus.email
        guard let email, !email.isEmpty else {
            notice = "Non è disponibile un indirizzo email a cui inviare la conferma."
            return
        }

        isSubmitting = true
        defer { isSubmitting = false }
        do {
            try await auth.resend(email: email, type: .signup)
            notice = "Ti abbiamo inviato un nuovo link di conferma a \(email)."
        } catch {
            notice = "Non è stato possibile reinviare subito l’email. Attendi qualche minuto e riprova."
        }
    }

    func handleAuthCallback(_ url: URL) async {
        let generation = sessionGeneration
        do {
            let callbackSession = try await auth.session(from: url)
            guard sessionGeneration == generation, !Task.isCancelled else { return }
            pendingRegistration = nil
            registrationStage = .profileVerification
            updateEmailVerificationStatus(from: callbackSession.user)
            await load(userID: callbackSession.user.id, email: callbackSession.user.email, ownerGeneration: generation)
        } catch {
            guard sessionGeneration == generation, !Task.isCancelled else { return }
            await refreshEmailVerification()
        }
    }

    func refresh() async {
        // SwiftUI cancels .task(id:) when switching tabs. The shared read operation
        // belongs to the session, not to any individual screen requesting it.
        if let refreshTask {
            await refreshTask.value
            return
        }
        guard case .active(_, _, let source) = state, source == .live else { return }
        let generation = refreshGeneration
        let task = Task { @MainActor [weak self] in
            guard let self else { return }
            await self.performContentRefresh(generation: generation)
        }
        refreshTask = task
        await task.value
    }

    private func performContentRefresh(generation: UUID) async {
        guard refreshGeneration == generation, !Task.isCancelled else { return }
        guard case .active(let identity, let previousSnapshot, let source) = state, source == .live else { return }
        guard !isRefreshing else { return }
        isRefreshing = true
        readPhase = .loading
        let requestID = UUID()
        ClientLoadDiagnostics.record("HOME", requestID: requestID, event: "start", stage: "refresh")
        defer {
            if refreshGeneration == generation {
                isRefreshing = false
                refreshTask = nil
                if readPhase == .loading { readPhase = refreshError == nil ? previousSnapshot.loadPhase : .error }
            }
        }
        var stage = "session"
        do {
            try Task.checkCancellation()
            // Retrieve/refresh the real session; never use another account's JWT
            // to reload the currently visible user's data.
            let activeSession = try await auth.session
            guard activeSession.user.id == identity.authUserID else {
                throw AuthError.sessionMissing
            }
            try Task.checkCancellation()
            stage = "identity"
            let refreshedIdentity = try await repository.identity(
                authUserID: identity.authUserID,
                email: identity.email, requestID: requestID
            )
            ClientLoadDiagnostics.record("TRAINER_CONNECTION", requestID: requestID, event: "success", stage: "identity_read",
                                         sessionReady: true, clientReady: refreshedIdentity.clientID != nil,
                                         trainerReady: refreshedIdentity.trainerID != nil)
            try Task.checkCancellation()
            stage = "content"
            let sameOwnership = refreshedIdentity.clientID == identity.clientID && refreshedIdentity.trainerID == identity.trainerID
            let snapshot = try await repository.snapshot(for: refreshedIdentity,
                                                        previous: sameOwnership ? previousSnapshot : nil,
                                                        requestID: requestID)
            try Task.checkCancellation()
            guard refreshGeneration == generation,
                  case .active(let currentIdentity, _, let currentSource) = state,
                  currentSource == .live, currentIdentity.authUserID == identity.authUserID else {
                ClientLoadDiagnostics.record("HOME", requestID: requestID, event: "stale", stage: "refresh_commit")
                return
            }
            state = .active(identity: refreshedIdentity, snapshot: snapshot, source: .live)
            shouldOfferTrainerCode = refreshedIdentity.mode == .standalone
                && !refreshedIdentity.hasCompletedInitialOnboarding
            refreshError = nil
            readPhase = snapshot.loadPhase
            ClientLoadDiagnostics.record("HOME", requestID: requestID, event: "success", stage: "refresh", sessionReady: true)
        } catch {
            guard refreshGeneration == generation, !Task.isCancelled,
                  !ClientRefreshErrorPolicy.isCancellation(error),
                  case .active(let currentIdentity, _, let currentSource) = state,
                  currentSource == .live, currentIdentity.authUserID == identity.authUserID else {
                ClientLoadDiagnostics.record("HOME", requestID: requestID,
                                             event: ClientRefreshErrorPolicy.isCancellation(error) || Task.isCancelled ? "cancel" : "stale",
                                             stage: stage, code: ClientRefreshErrorPolicy.diagnosticCode(for: error))
                return
            }
            #if DEBUG
            let code = ClientRefreshErrorPolicy.diagnosticCode(for: error)
            Self.registrationLogger.debug("operation=content_refresh stage=\(stage, privacy: .public) code=\(code, privacy: .public)")
            #endif
            refreshError = ClientRefreshErrorPolicy.message(for: error)
            readPhase = .error
            ClientLoadDiagnostics.record("HOME", requestID: requestID, event: "failure", stage: stage,
                                         code: ClientRefreshErrorPolicy.diagnosticCode(for: error))
        }
    }

    private func invalidateContentRefresh() {
        refreshGeneration = UUID()
        refreshTask?.cancel()
        refreshTask = nil
        isRefreshing = false
    }

    private func invalidateSessionReads() {
        sessionGeneration = UUID()
        bootstrapTask?.cancel()
        bootstrapTask = nil
        invalidateContentRefresh()
        refreshError = nil
        readPhase = .idle
    }

    func contentState(for section: ClientContentSection) -> ClientContentLoadState {
        guard case .active(_, let snapshot, _) = state else {
            return readPhase == .idle ? .idle : .loading
        }
        return ClientContentReadiness.resolve(snapshot.contentState(for: section), phase: readPhase, hasActiveIdentity: true)
    }

    /// A real error stays visible until the user explicitly retries. Foreground
    /// reads only refresh a previously successful snapshot, never silently retry it.
    var canRefreshOnForeground: Bool {
        refreshError == nil && (readPhase == .loaded || readPhase == .empty)
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
    func startDemo(_ persona: ClientDemoPersona) {
        invalidateSessionReads()
        let identity = ClientDemoData.identity(for: persona)
        let snapshot = ClientDemoData.snapshot(for: persona)
        agenda = agendaStore.load(userID: identity.authUserID, source: .demo)
        activity = activityStore.load(userID: identity.authUserID, source: .demo)
        restReadyExerciseID = nil
        personalContent = personalContentStore.load(userID: identity.authUserID)
        if agenda.isEmpty {
            agenda = ClientDemoData.agenda(for: persona)
            try? agendaStore.save(agenda, userID: identity.authUserID, source: .demo)
        }
        if activity.workouts.isEmpty,
           activity.meals.isEmpty,
           activity.runningResults.isEmpty,
           activity.activeRun == nil {
            activity = ClientDemoData.activity(for: persona)
            try? activityStore.save(activity, userID: identity.authUserID, source: .demo)
        }
        state = .active(identity: identity, snapshot: snapshot, source: .demo)
        readPhase = snapshot.loadPhase
        shouldOfferTrainerCode = false
        emailVerificationStatus = .unavailable
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

    func workoutExecution(sessionID: UUID, on date: Date = Date()) -> ClientWorkoutExecution? {
        activity.workout(sessionID: sessionID, on: date)
    }

    func generatePersonalWorkout(answers: ClientWorkoutQuestionnaireAnswers, catalog: [ClientExerciseCatalogItem], variation: Int = 0) throws -> ClientGeneratedWorkoutResult {
        let mode: ClientConnectionMode?
        if case .active(let identity, _, _) = state { mode = identity.mode } else { mode = nil }
        let eligibility = ClientWorkoutGenerationPolicy.evaluate(context: .init(mode: mode), answers: answers)
        guard eligibility == .allowed else { throw eligibility }
        return try ClientWorkoutGenerator().generate(answers: answers, catalog: catalog, variation: variation)
    }

    func savePersonalWorkoutPlan(_ plan: ClientPersonalWorkoutPlan) {
        guard case .active(let identity, _, let source) = state else { return }
        guard ClientAccessPolicy.canManagePersonalWorkoutPlans(in: identity.mode) else {
            notice = ClientAccessPolicy.trainerManagedPlansMessage
            return
        }
        let plansToSync = stagePersonalWorkoutPlan(plan, identity: identity)
        guard source == .live else { return }
        Task {
            do {
                for item in plansToSync { try await personalRepository.saveWorkoutPlan(item, userID: identity.authUserID) }
            }
            catch { notice = "Scheda salvata sul dispositivo; sincronizzazione non disponibile." }
        }
    }

    func savePersonalWorkoutPlanConfirmed(_ plan: ClientPersonalWorkoutPlan) async -> Bool {
        guard case .active(let identity, _, let source) = state else { return false }
        guard ClientAccessPolicy.canManagePersonalWorkoutPlans(in: identity.mode) else {
            notice = ClientAccessPolicy.trainerManagedPlansMessage
            return false
        }
        _ = stagePersonalWorkoutPlan(plan, identity: identity)
        guard source == .live else {
            notice = "Scheda salvata in modalità demo."
            return true
        }
        do {
            var active: [ClientPersonalWorkoutPlan] = []
            if plan.status == .active { active = try await personalRepository.activeWorkoutPlans(userID: identity.authUserID) }
            let archives = active.filter { $0.id != plan.id }.map { original in
                var archived = original; archived.status = .archived; archived.updatedAt = Date(); return archived
            }
            guard case .active(let savingIdentity, _, _) = state, savingIdentity.authUserID == identity.authUserID,
                  ClientAccessPolicy.canManagePersonalWorkoutPlans(in: savingIdentity.mode) else { return false }
            try await personalRepository.saveWorkoutPlans(archives + [plan], userID: identity.authUserID)
            let confirmed = try await personalRepository.workoutPlan(id: plan.id, userID: identity.authUserID)
            guard case .active(let currentIdentity, _, let currentSource) = state,
                  currentIdentity.authUserID == identity.authUserID, currentSource == source else { return false }
            guard ClientAccessPolicy.canManagePersonalWorkoutPlans(in: currentIdentity.mode) else {
                notice = ClientAccessPolicy.trainerManagedPlansMessage
                return false
            }
            guard let confirmed, confirmed.title == plan.title, confirmed.status == plan.status,
                  confirmed.sessions == plan.sessions, confirmed.source == plan.source,
                  confirmed.durationWeeks == plan.durationWeeks, confirmed.generationAnswers == plan.generationAnswers,
                  confirmed.progression == plan.progression, confirmed.validation == plan.validation,
                  confirmed.generationMetadata == plan.generationMetadata, confirmed.editProvenance == plan.editProvenance else {
                notice = "La scheda riletta dal server non corrisponde alla bozza. Riprova il salvataggio."
                return false
            }
            if let index = personalContent.workoutPlans.firstIndex(where: { $0.id == confirmed.id }) {
                personalContent.workoutPlans[index] = confirmed
            }
            for archived in archives {
                if let index = personalContent.workoutPlans.firstIndex(where: { $0.id == archived.id }) { personalContent.workoutPlans[index] = archived }
                else { personalContent.workoutPlans.append(archived) }
            }
            persistPersonalContent(identity: identity)
            notice = "Scheda salvata e verificata."
            return true
        } catch {
            guard case .active(let currentIdentity, _, _) = state,
                  currentIdentity.authUserID == identity.authUserID else { return false }
            // Preserve typed ownership denial instead of presenting it as an offline sync failure.
            if let reason = error as? ClientWorkoutGenerationEligibility {
                notice = reason.errorDescription
            } else {
                notice = "Scheda conservata sul dispositivo, ma il database non ha confermato la sincronizzazione."
            }
            return false
        }
    }

    func deletePersonalWorkoutPlan(_ id: UUID) {
        guard case .active(let identity, _, let source) = state else { return }
        guard ClientAccessPolicy.canManagePersonalWorkoutPlans(in: identity.mode) else {
            notice = ClientAccessPolicy.trainerManagedPlansMessage
            return
        }
        personalContent.workoutPlans.removeAll { $0.id == id }
        persistPersonalContent(identity: identity)
        guard source == .live else { return }
        Task {
            do { try await personalRepository.deleteWorkoutPlan(id) }
            catch { notice = "Scheda rimossa sul dispositivo; sincronizzazione non disponibile." }
        }
    }

    func savePersonalNutritionPlan(_ plan: ClientPersonalNutritionPlan) {
        guard case .active(let identity, _, let source) = state else { return }
        guard ClientAccessPolicy.canManagePersonalNutritionPlans(in: identity.mode) else {
            notice = ClientAccessPolicy.trainerManagedPlansMessage
            return
        }
        guard validateNutritionCoachBeforeSave(plan, mode: identity.mode) else { return }
        var plansToSync: [ClientPersonalNutritionPlan] = []
        if plan.status == .active {
            for index in personalContent.nutritionPlans.indices where personalContent.nutritionPlans[index].id != plan.id && personalContent.nutritionPlans[index].status == .active {
                personalContent.nutritionPlans[index].status = .archived
                personalContent.nutritionPlans[index].updatedAt = Date()
                plansToSync.append(personalContent.nutritionPlans[index])
            }
        }
        if let index = personalContent.nutritionPlans.firstIndex(where: { $0.id == plan.id }) { personalContent.nutritionPlans[index] = plan }
        else { personalContent.nutritionPlans.insert(plan, at: 0) }
        persistPersonalContent(identity: identity)
        guard source == .live else { return }
        plansToSync.append(plan)
        Task {
            do {
                for item in plansToSync { try await personalRepository.saveNutritionPlan(item, userID: identity.authUserID) }
            }
            catch { notice = "Piano salvato sul dispositivo; sincronizzazione non disponibile." }
        }
    }

    func deletePersonalNutritionPlan(_ id: UUID) {
        guard case .active(let identity, _, let source) = state else { return }
        guard ClientAccessPolicy.canManagePersonalNutritionPlans(in: identity.mode) else {
            notice = ClientAccessPolicy.trainerManagedPlansMessage
            return
        }
        personalContent.nutritionPlans.removeAll { $0.id == id }
        persistPersonalContent(identity: identity)
        guard source == .live else { return }
        Task {
            do { try await personalRepository.deleteNutritionPlan(id) }
            catch { notice = "Piano rimosso sul dispositivo; sincronizzazione non disponibile." }
        }
    }

    func savePersonalNutritionPlanConfirmed(_ plan: ClientPersonalNutritionPlan) async -> Bool {
        guard case .active(let identity, _, let source) = state else { return false }
        guard ClientAccessPolicy.canManagePersonalNutritionPlans(in: identity.mode) else {
            notice = ClientAccessPolicy.trainerManagedPlansMessage
            return false
        }
        guard validateNutritionCoachBeforeSave(plan, mode: identity.mode) else { return false }
        if plan.status == .active {
            for index in personalContent.nutritionPlans.indices where personalContent.nutritionPlans[index].id != plan.id && personalContent.nutritionPlans[index].status == .active {
                personalContent.nutritionPlans[index].status = .archived
                personalContent.nutritionPlans[index].updatedAt = Date()
            }
        }
        if let index = personalContent.nutritionPlans.firstIndex(where: { $0.id == plan.id }) { personalContent.nutritionPlans[index] = plan }
        else { personalContent.nutritionPlans.insert(plan, at: 0) }
        persistPersonalContent(identity: identity)
        guard source == .live else { notice = "Piano salvato in modalità demo."; return true }
        do {
            var active: [ClientPersonalNutritionPlan] = []
            if plan.status == .active { active = try await personalRepository.activeNutritionPlans(userID: identity.authUserID) }
            let remoteArchives = active.filter { $0.id != plan.id }.map { original in
                var archived = original; archived.status = .archived; archived.updatedAt = Date(); return archived
            }
            guard case .active(let savingIdentity, _, _) = state, savingIdentity.authUserID == identity.authUserID,
                  ClientAccessPolicy.canManagePersonalNutritionPlans(in: savingIdentity.mode) else { return false }
            try await personalRepository.saveNutritionPlans(remoteArchives + [plan], userID: identity.authUserID)
            let confirmed = try await personalRepository.nutritionPlan(id: plan.id, userID: identity.authUserID)
            guard case .active(let currentIdentity, _, let currentSource) = state,
                  currentIdentity.authUserID == identity.authUserID, currentSource == source else { return false }
            guard ClientAccessPolicy.canManagePersonalNutritionPlans(in: currentIdentity.mode) else {
                notice = ClientAccessPolicy.trainerManagedPlansMessage; return false
            }
            guard let confirmed, confirmed.title == plan.title, confirmed.status == plan.status,
                  confirmed.days == plan.days, confirmed.source == plan.source, confirmed.target == plan.target,
                  confirmed.creationAnswers == plan.creationAnswers, confirmed.generationMetadata == plan.generationMetadata,
                  confirmed.editProvenance == plan.editProvenance else {
                notice = "Il database non ha confermato il piano completo. La bozza è conservata: riprova."; return false
            }
            if let index = personalContent.nutritionPlans.firstIndex(where: { $0.id == plan.id }) { personalContent.nutritionPlans[index] = confirmed }
            for archive in remoteArchives {
                if let index = personalContent.nutritionPlans.firstIndex(where: { $0.id == archive.id }) { personalContent.nutritionPlans[index] = archive }
                else { personalContent.nutritionPlans.append(archive) }
            }
            persistPersonalContent(identity: identity)
            notice = "Piano salvato e verificato."
            return true
        } catch {
            guard case .active(let currentIdentity, _, _) = state, currentIdentity.authUserID == identity.authUserID else { return false }
            notice = "Piano conservato sul dispositivo, ma il database non ha confermato la sincronizzazione."
            return false
        }
    }

    private func validateNutritionCoachBeforeSave(_ plan: ClientPersonalNutritionPlan, mode: ClientConnectionMode) -> Bool {
        // Historical manual/legacy guided payloads remain readable/editable;5C evidence cannot skip validation.
        guard plan.generationMetadata != nil || plan.creationAnswers?.coachProfile != nil else { return true }
        let context = ClientNutritionCoachContext(mode: mode, profile: plan.creationAnswers?.coachProfile)
        guard ClientNutritionPlanValidator.inspect(plan, context: context, catalog: foodCatalogCache ?? []).isEmpty else {
            notice = ClientNutritionGenerationEligibility.invalidPlan.errorDescription
            return false
        }
        return true
    }

    func savePersonalMealTemplate(_ template: ClientPersonalMealTemplate) {
        guard case .active(let identity, _, let source) = state else { return }
        if let index = personalContent.mealTemplates.firstIndex(where: { $0.id == template.id }) { personalContent.mealTemplates[index] = template }
        else { personalContent.mealTemplates.insert(template, at: 0) }
        persistPersonalContent(identity: identity)
        guard source == .live else { return }
        Task {
            do { try await personalRepository.saveMealTemplate(template, userID: identity.authUserID) }
            catch { notice = "Modello pasto salvato sul dispositivo; sincronizzazione non disponibile." }
        }
    }

    func savePersonalExercise(_ exercise: ClientPersonalExercise) {
        guard case .active(let identity, _, let source) = state, source == .live else { return }
        Task {
            do { try await personalRepository.savePersonalExercise(exercise, userID: identity.authUserID) }
            catch { notice = "Esercizio disponibile nella scheda; libreria personale non sincronizzata." }
        }
    }

    func searchPersonalExercises(_ query: String) async -> [ClientExerciseCatalogItem] {
        (try? await personalRepository.searchExercises(query)) ?? []
    }

    func personalExerciseCatalog(forceReload: Bool = false) async -> [ClientExerciseCatalogItem] {
        if !forceReload, let exerciseCatalogCache { return exerciseCatalogCache }
        do {
            let catalog = try await personalRepository.exerciseCatalog()
            exerciseCatalogCache = catalog
            return catalog
        } catch {
            notice = "Database esercizi temporaneamente non disponibile."
            return exerciseCatalogCache ?? []
        }
    }

    func searchPersonalFoods(_ query: String) async -> [ClientFoodCatalogItem] {
        let catalog = await personalFoodCatalog()
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return query.isEmpty ? catalog : catalog.filter { $0.name.localizedStandardContains(query) }
    }

    func personalFoodCatalog(forceReload: Bool = false) async -> [ClientFoodCatalogItem] {
        if !forceReload, let foodCatalogCache { return foodCatalogCache }
        do {
            let catalog = try await personalRepository.foodCatalog()
            foodCatalogCache = catalog
            return catalog
        } catch {
            notice = "Catalogo alimenti temporaneamente non disponibile."
            return foodCatalogCache ?? []
        }
    }

    private func stagePersonalWorkoutPlan(_ plan: ClientPersonalWorkoutPlan, identity: ClientIdentity) -> [ClientPersonalWorkoutPlan] {
        var plansToSync: [ClientPersonalWorkoutPlan] = []
        if plan.status == .active {
            for index in personalContent.workoutPlans.indices where personalContent.workoutPlans[index].id != plan.id && personalContent.workoutPlans[index].status == .active {
                personalContent.workoutPlans[index].status = .archived
                personalContent.workoutPlans[index].updatedAt = Date()
                plansToSync.append(personalContent.workoutPlans[index])
            }
        }
        if let index = personalContent.workoutPlans.firstIndex(where: { $0.id == plan.id }) {
            personalContent.workoutPlans[index] = plan
        } else {
            personalContent.workoutPlans.insert(plan, at: 0)
        }
        persistPersonalContent(identity: identity)
        plansToSync.append(plan)
        return plansToSync
    }

    func beginWorkout(plan: ClientWorkoutPlan, workoutSession: ClientWorkoutSession, now: Date = Date()) {
        guard activity.workout(sessionID: workoutSession.id, on: now) == nil else { return }
        let exerciseLogs = workoutSession.exercises.map { exercise in
            ClientExerciseLog(
                id: UUID(),
                exerciseID: exercise.id,
                note: "",
                sets: (1...exercise.setCount).map { number in
                    ClientSetLog(
                        id: UUID(),
                        number: number,
                        prescribedRepetitions: exercise.repetitions,
                        prescribedLoadKg: exercise.loadKg,
                        actualRepetitions: exercise.suggestedActualRepetitions,
                        actualLoadKg: exercise.loadKg,
                        completedAt: nil
                    )
                }
            )
        }
        activity.workouts.append(ClientWorkoutExecution(
            id: UUID(), planID: plan.id, sessionID: workoutSession.id,
            dayKey: ClientDayKey.string(for: now), startedAt: now,
            completedAt: nil, exercises: exerciseLogs, feedback: nil
        ))
        persistActivity()
    }

    func completeSet(
        sessionID: UUID,
        exercise: ClientExercise,
        setNumber: Int,
        actualRepetitions: Int?,
        actualLoadKg: Double?,
        now: Date = Date()
    ) {
        guard let workoutIndex = activity.workouts.firstIndex(where: {
            $0.sessionID == sessionID && $0.dayKey == ClientDayKey.string(for: now) && !$0.isCompleted
        }), let exerciseIndex = activity.workouts[workoutIndex].exercises.firstIndex(where: { $0.exerciseID == exercise.id }),
              let setIndex = activity.workouts[workoutIndex].exercises[exerciseIndex].sets.firstIndex(where: { $0.number == setNumber }) else { return }

        activity.workouts[workoutIndex].exercises[exerciseIndex].sets[setIndex].actualRepetitions = actualRepetitions
        activity.workouts[workoutIndex].exercises[exerciseIndex].sets[setIndex].actualLoadKg = actualLoadKg
        activity.workouts[workoutIndex].exercises[exerciseIndex].sets[setIndex].completedAt = now
        restReadyExerciseID = nil
        activity.restTimer = nil // Completing another set replaces, never inherits, the previous recovery.

        let allComplete = activity.workouts[workoutIndex].exercises.allSatisfy(\.isCompleted)
        if let rest = exercise.restSeconds, rest > 0, !allComplete {
            let next = activity.workouts[workoutIndex].exercises[exerciseIndex].sets.first(where: { !$0.isCompleted })?.number
            activity.restTimer = ClientRestTimerState(
                exerciseID: exercise.id,
                nextSetNumber: next,
                phase: .running,
                endsAt: now.addingTimeInterval(TimeInterval(rest)),
                pausedSeconds: nil, startedAt: now, durationSeconds: TimeInterval(rest)
            )
        }
        persistActivity()
        ClientHaptics.completedSet()
    }

    func undoSet(sessionID: UUID, exerciseID: UUID, setNumber: Int, now: Date = Date()) {
        guard let workoutIndex = activity.workouts.firstIndex(where: { $0.sessionID == sessionID && $0.dayKey == ClientDayKey.string(for: now) }),
              let exerciseIndex = activity.workouts[workoutIndex].exercises.firstIndex(where: { $0.exerciseID == exerciseID }),
              let setIndex = activity.workouts[workoutIndex].exercises[exerciseIndex].sets.firstIndex(where: { $0.number == setNumber }) else { return }
        activity.workouts[workoutIndex].exercises[exerciseIndex].sets[setIndex].completedAt = nil
        if activity.restTimer?.exerciseID == exerciseID { activity.restTimer = nil }
        if restReadyExerciseID == exerciseID { restReadyExerciseID = nil }
        persistActivity()
    }

    func saveExerciseNote(sessionID: UUID, exerciseID: UUID, note: String, now: Date = Date()) {
        guard let workoutIndex = activity.workouts.firstIndex(where: { $0.sessionID == sessionID && $0.dayKey == ClientDayKey.string(for: now) }),
              let exerciseIndex = activity.workouts[workoutIndex].exercises.firstIndex(where: { $0.exerciseID == exerciseID }) else { return }
        activity.workouts[workoutIndex].exercises[exerciseIndex].note = note.trimmingCharacters(in: .whitespacesAndNewlines)
        persistActivity()
    }

    func pauseRestTimer(now: Date = Date()) {
        guard var timer = activity.restTimer, timer.phase == .running else { return }
        if timer.remainingSeconds(at: now) == 0 { finishRestTimerIfElapsed(at: now); return }
        timer.pause(at: now)
        activity.restTimer = timer
        persistActivity()
    }

    func resumeRestTimer(now: Date = Date()) {
        guard var timer = activity.restTimer, timer.phase == .paused else { return }
        timer.resume(at: now)
        activity.restTimer = timer
        persistActivity()
    }

    func adjustRestTimer(by seconds: Int, now: Date = Date()) {
        guard var timer = activity.restTimer else { return }
        timer.adjust(by: seconds, at: now)
        if timer.remainingSeconds(at: now) == 0 {
            restReadyExerciseID = timer.exerciseID; activity.restTimer = nil
            persistActivity(); ClientHaptics.timerFinished(); return
        }
        activity.restTimer = timer
        persistActivity()
    }

    func skipRestTimer() {
        restReadyExerciseID = nil
        activity.restTimer = nil
        persistActivity()
    }

    func finishRestTimerIfElapsed(at date: Date = Date()) {
        guard let timer = activity.restTimer, timer.phase == .running, timer.remainingSeconds(at: date) == 0 else { return }
        restReadyExerciseID = timer.exerciseID
        activity.restTimer = nil
        persistActivity()
        ClientHaptics.timerFinished()
    }

    func dismissRestReady() { restReadyExerciseID = nil }

    func finishWorkout(sessionID: UUID, feedback: ClientWorkoutFeedback, now: Date = Date()) {
        guard let index = activity.workouts.firstIndex(where: {
            $0.sessionID == sessionID && $0.dayKey == ClientDayKey.string(for: now) && !$0.isCompleted
        }), activity.workouts[index].exercises.allSatisfy(\.isCompleted) else { return }
        activity.workouts[index].completedAt = now
        activity.workouts[index].feedback = feedback
        activity.restTimer = nil
        restReadyExerciseID = nil
        persistActivity()
        ClientHaptics.workoutFinished()
    }

    func toggleMealCompletion(_ mealID: UUID, on date: Date = Date()) {
        let key = ClientDayKey.string(for: date)
        if let index = activity.meals.firstIndex(where: { $0.mealID == mealID && $0.dayKey == key }) {
            activity.meals.remove(at: index)
        } else {
            activity.meals.append(ClientMealCompletion(id: UUID(), mealID: mealID, dayKey: key, completedAt: date))
            ClientHaptics.completedSet()
        }
        persistActivity()
    }

    func beginRun(_ plan: ClientRunningPlan, now: Date = Date()) {
        guard activity.activeRun == nil else { return }
        activity.activeRun = ClientRunningExecution(
            id: UUID(), planID: plan.id, startedAt: now, resumedAt: now,
            accumulatedSeconds: 0, route: [], maximumSpeedMetersPerSecond: nil
        )
        persistActivity()
    }

    func updateRunRoute(_ route: [ClientRoutePoint], maximumSpeedMetersPerSecond: Double?, persist: Bool = true) {
        guard var run = activity.activeRun else { return }
        run.route = route
        run.maximumSpeedMetersPerSecond = maximumSpeedMetersPerSecond
        activity.activeRun = run
        if persist { persistActivity() }
    }

    func toggleRunPause(now: Date = Date()) {
        guard var run = activity.activeRun else { return }
        if let resumedAt = run.resumedAt {
            run.accumulatedSeconds += max(0, now.timeIntervalSince(resumedAt))
            run.resumedAt = nil
        } else {
            run.resumedAt = now
        }
        activity.activeRun = run
        persistActivity()
    }

    @discardableResult
    func finishRun(effort: Int?, note: String, now: Date = Date()) -> ClientRunningResult? {
        guard let run = activity.activeRun else { return nil }
        let measuredDistance = ClientRunningMetrics.distanceMeters(for: run.route) / 1_000
        let result = ClientRunningResult(
            id: UUID(), planID: run.planID, completedAt: now,
            durationSeconds: run.elapsedSeconds(at: now),
            distanceKm: measuredDistance > 0 ? measuredDistance : nil,
            route: run.route,
            maximumSpeedKmh: run.maximumSpeedMetersPerSecond.map { $0 * 3.6 },
            effort: effort,
            note: note.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        activity.runningResults.append(result)
        activity.activeRun = nil
        persistActivity()
        if case .active(let identity, _, let source) = state, source == .live {
            Task {
                do { try await personalRepository.saveRunningResult(result, userID: identity.authUserID) }
                catch { notice = "Corsa salvata sul dispositivo; sincronizzazione non disponibile." }
            }
        }
        ClientHaptics.workoutFinished()
        return result
    }

    private func load(userID: UUID, email: String?, ownerGeneration: UUID, requestID: UUID = UUID()) async {
        guard sessionGeneration == ownerGeneration, !Task.isCancelled else { return }
        invalidateContentRefresh()
        let generation = refreshGeneration
        readPhase = .authBootstrap
        state = .loading
        do {
            let activeSession = try await auth.session
            try Task.checkCancellation()
            guard sessionGeneration == ownerGeneration, refreshGeneration == generation else { return }
            guard activeSession.user.id == userID else { throw AuthError.sessionMissing }
            ClientLoadDiagnostics.record("HOME", requestID: requestID, event: "start", stage: "identity", sessionReady: true)
            let identity = try await repository.identity(authUserID: userID, email: email, requestID: requestID)
            try Task.checkCancellation()
            guard sessionGeneration == ownerGeneration, refreshGeneration == generation else { return }
            readPhase = .loading
            ClientLoadDiagnostics.record("TRAINER_CONNECTION", requestID: requestID, event: "success", stage: "identity_read",
                                         sessionReady: true, clientReady: identity.clientID != nil, trainerReady: identity.trainerID != nil)
            let snapshot = try await repository.snapshot(for: identity, requestID: requestID)
            try Task.checkCancellation()
            guard sessionGeneration == ownerGeneration, refreshGeneration == generation else { return }
            agenda = agendaStore.load(userID: identity.authUserID, source: .live)
            activity = activityStore.load(userID: identity.authUserID, source: .live)
            restReadyExerciseID = nil
            let localContent = personalContentStore.load(userID: identity.authUserID)
            personalContent = localContent
            if let remote = try? await personalRepository.content(userID: identity.authUserID) {
                try Task.checkCancellation()
                guard sessionGeneration == ownerGeneration, refreshGeneration == generation else { return }
                let merged = localContent.merging(remote)
                personalContent = merged
                try? personalContentStore.save(merged, userID: identity.authUserID)
                if merged != remote {
                    for plan in merged.workoutPlans {
                        guard sessionGeneration == ownerGeneration, refreshGeneration == generation else { return }
                        try? await personalRepository.saveWorkoutPlan(plan, userID: identity.authUserID)
                    }
                    for plan in merged.nutritionPlans {
                        guard sessionGeneration == ownerGeneration, refreshGeneration == generation else { return }
                        try? await personalRepository.saveNutritionPlan(plan, userID: identity.authUserID)
                    }
                    for template in merged.mealTemplates {
                        guard sessionGeneration == ownerGeneration, refreshGeneration == generation else { return }
                        try? await personalRepository.saveMealTemplate(template, userID: identity.authUserID)
                    }
                }
            }
            try Task.checkCancellation()
            guard sessionGeneration == ownerGeneration, refreshGeneration == generation else {
                ClientLoadDiagnostics.record("HOME", requestID: requestID, event: "stale", stage: "bootstrap_commit")
                return
            }
            state = .active(identity: identity, snapshot: snapshot, source: .live)
            refreshError = nil
            readPhase = snapshot.loadPhase
            ClientLoadDiagnostics.record("HOME", requestID: requestID, event: "success", stage: "bootstrap_commit", sessionReady: true)
            shouldOfferTrainerCode = identity.mode == .standalone && !identity.hasCompletedInitialOnboarding
            if registrationStage == .profileVerification {
                registrationStage = .completed
                Self.logRegistration(
                    stage: .completed,
                    message: identity.mode == .standalone
                        ? "Profile verified; standalone mode entered"
                        : "Profile verified; trainer-connected mode entered",
                    userID: identity.authUserID
                )
            }
        } catch {
            guard sessionGeneration == ownerGeneration, refreshGeneration == generation else { return }
            if ClientRefreshErrorPolicy.isCancellation(error) || Task.isCancelled {
                readPhase = .idle
                ClientLoadDiagnostics.record("HOME", requestID: requestID, event: "cancel", stage: "bootstrap")
                return
            }
            readPhase = .error
            ClientLoadDiagnostics.record("HOME", requestID: requestID, event: "failure", stage: "bootstrap",
                                         code: ClientRefreshErrorPolicy.diagnosticCode(for: error))
            shouldOfferTrainerCode = false
            if registrationStage == .profileVerification {
                registrationStage = .failed
                Self.logRegistration(
                    stage: .profileVerification,
                    message: error.localizedDescription,
                    userID: userID
                )
            }
            state = .failure(ClientRefreshErrorPolicy.message(for: error) ?? "Impossibile verificare il profilo Cliente.")
        }
    }

    private func updateEmailVerificationStatus(from user: User) {
        guard let email = user.email, !email.isEmpty else {
            emailVerificationStatus = .unavailable
            return
        }
        emailVerificationStatus = user.emailConfirmedAt == nil
            ? .unverified(email: email)
            : .verified(email: email)
    }

    private static func logRegistration(
        stage: ClientRegistrationStage,
        message: String,
        status: Int? = nil,
        code: String? = nil,
        userID: UUID? = nil
    ) {
        #if DEBUG
        // Legacy callers may pass server prose/IDs. Deliberately do not log
        // those parameters: Auth failures can embed emails and response bodies.
        let statusText = status.flatMap { (100...599).contains($0) ? String($0) : nil } ?? "n/a"
        let codeText = code.flatMap { $0.range(of: #"^[A-Za-z0-9_]{1,48}$"#, options: .regularExpression) != nil ? $0 : nil } ?? "n/a"
        registrationLogger.debug(
            "stage=\(stage.rawValue, privacy: .public) status=\(statusText, privacy: .public) code=\(codeText, privacy: .public)"
        )
        #endif
    }

    private func persistActivity() {
        guard case .active(let identity, _, let source) = state else { return }
        do { try activityStore.save(activity, userID: identity.authUserID, source: source) }
        catch { notice = "Attività non salvata su questo dispositivo." }
    }

    private func persistPersonalContent(identity: ClientIdentity) {
        do { try personalContentStore.save(personalContent, userID: identity.authUserID) }
        catch { notice = "Contenuti personali non salvati su questo dispositivo." }
    }
}
