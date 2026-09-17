import Combine
import Foundation
import OSLog
import Supabase

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
    @Published private(set) var personalContent: ClientPersonalContentState = .empty
    @Published private(set) var shouldOfferTrainerCode = false
    @Published var isSubmitting = false
    @Published var notice: String?
    @Published var registrationIssue: ClientRegistrationIssue?
    @Published private(set) var registrationStage: ClientRegistrationStage = .idle

    var canResumePendingRegistration: Bool { pendingRegistration != nil }

    private let auth: AuthClient
    private let repository: ClientRepository
    private let agendaStore: PersonalAgendaStore
    private let activityStore: ClientActivityStore
    private let personalContentStore: ClientPersonalContentStore
    private let personalRepository: ClientPersonalRepository
    private let trainerCodeActivator: any TrainerCodeActivating
    private var pendingRegistration: PendingRegistration?

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
        registrationIssue = nil
        defer { isSubmitting = false }
        do {
            let response = try await auth.signIn(email: email, password: password)
            await load(userID: response.user.id, email: response.user.email)
        } catch {
            try? await auth.signOut(scope: .local)
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

            Self.logRegistration(
                stage: .authSignUp,
                message: "Auth user created",
                userID: response.user.id
            )

            if let activeSession = response.session {
                registrationStage = .profileVerification
                Self.logRegistration(
                    stage: .sessionCreation,
                    message: "Session returned by sign-up",
                    userID: activeSession.user.id
                )
                await load(userID: activeSession.user.id, email: activeSession.user.email)
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
            registrationStage = .failed
            Self.logRegistration(stage: .authSignUp, message: message, code: "weak_password")
            registrationIssue = ClientRegistrationErrorClassifier.issue(message: message, code: "weak_password")
        } catch let AuthError.api(message, errorCode, _, response) {
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
        Self.logRegistration(stage: .sessionCreation, message: "Attempting session after email confirmation")
        defer { isSubmitting = false }

        do {
            let response = try await auth.signIn(
                email: pendingRegistration.email,
                password: pendingRegistration.password
            )
            self.pendingRegistration = nil
            registrationStage = .profileVerification
            Self.logRegistration(
                stage: .sessionCreation,
                message: "Confirmed account session created",
                userID: response.user.id
            )
            await load(userID: response.user.id, email: response.user.email)
        } catch let AuthError.api(message, errorCode, _, response) {
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
        defer { isSubmitting = false }
        do {
            let activation = try await trainerCodeActivator.activate(code: code)
            try await repository.completeInitialOnboarding()
            await load(userID: identity.authUserID, email: identity.email)
            guard case .active(let linkedIdentity, _, _) = state,
                  linkedIdentity.clientID == activation.clientID,
                  linkedIdentity.trainerID == activation.trainerID else {
                notice = "Codice riscattato, ma il profilo non è ancora aggiornato. Trascina per ricaricare."
                return false
            }
            notice = activation.alreadyLinked ? "Account già collegato al Trainer." : "Collegamento al Trainer completato."
            return true
        } catch {
            notice = (error as? LocalizedError)?.errorDescription ?? "Collegamento al Trainer non riuscito."
            return false
        }
    }

    func skipTrainerLinking() async {
        guard case .active(let identity, _, let source) = state, source == .live else { return }
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            try await repository.completeInitialOnboarding()
            await load(userID: identity.authUserID, email: identity.email)
        } catch {
            notice = (error as? LocalizedError)?.errorDescription ?? "Non è stato possibile completare il primo accesso."
        }
    }

    func signOut() async {
        try? await auth.signOut(scope: .local)
        agenda = []
        activity = .empty
        personalContent = .empty
        shouldOfferTrainerCode = false
        notice = nil
        registrationIssue = nil
        pendingRegistration = nil
        registrationStage = .idle
        state = .onboarding
    }

    func showOnboarding() {
        shouldOfferTrainerCode = false
        notice = nil
        registrationIssue = nil
        pendingRegistration = nil
        registrationStage = .idle
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
    func startDemo(_ persona: ClientDemoPersona) {
        let identity = ClientDemoData.identity(for: persona)
        let snapshot = ClientDemoData.snapshot(for: persona)
        agenda = agendaStore.load(userID: identity.authUserID, source: .demo)
        activity = activityStore.load(userID: identity.authUserID, source: .demo)
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
        shouldOfferTrainerCode = false
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

    func savePersonalWorkoutPlan(_ plan: ClientPersonalWorkoutPlan) {
        guard case .active(let identity, _, let source) = state else { return }
        var plansToSync: [ClientPersonalWorkoutPlan] = []
        if plan.status == .active {
            for index in personalContent.workoutPlans.indices where personalContent.workoutPlans[index].id != plan.id && personalContent.workoutPlans[index].status == .active {
                personalContent.workoutPlans[index].status = .archived
                personalContent.workoutPlans[index].updatedAt = Date()
                plansToSync.append(personalContent.workoutPlans[index])
            }
        }
        if let index = personalContent.workoutPlans.firstIndex(where: { $0.id == plan.id }) { personalContent.workoutPlans[index] = plan }
        else { personalContent.workoutPlans.insert(plan, at: 0) }
        persistPersonalContent(identity: identity)
        guard source == .live else { return }
        plansToSync.append(plan)
        Task {
            do {
                for item in plansToSync { try await personalRepository.saveWorkoutPlan(item, userID: identity.authUserID) }
            }
            catch { notice = "Scheda salvata sul dispositivo; sincronizzazione non disponibile." }
        }
    }

    func deletePersonalWorkoutPlan(_ id: UUID) {
        guard case .active(let identity, _, let source) = state else { return }
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
        personalContent.nutritionPlans.removeAll { $0.id == id }
        persistPersonalContent(identity: identity)
        guard source == .live else { return }
        Task {
            do { try await personalRepository.deleteNutritionPlan(id) }
            catch { notice = "Piano rimosso sul dispositivo; sincronizzazione non disponibile." }
        }
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

    func searchPersonalFoods(_ query: String) async -> [ClientFoodCatalogItem] {
        (try? await personalRepository.searchFoods(query)) ?? []
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

        let allComplete = activity.workouts[workoutIndex].exercises.allSatisfy(\.isCompleted)
        if let rest = exercise.restSeconds, rest > 0, !allComplete {
            let next = activity.workouts[workoutIndex].exercises[exerciseIndex].sets.first(where: { !$0.isCompleted })?.number
            activity.restTimer = ClientRestTimerState(
                exerciseID: exercise.id,
                nextSetNumber: next,
                phase: .running,
                endsAt: now.addingTimeInterval(TimeInterval(rest)),
                pausedSeconds: nil
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
        timer.pausedSeconds = TimeInterval(timer.remainingSeconds(at: now))
        timer.endsAt = nil
        timer.phase = .paused
        activity.restTimer = timer
        persistActivity()
    }

    func resumeRestTimer(now: Date = Date()) {
        guard var timer = activity.restTimer, timer.phase == .paused else { return }
        timer.endsAt = now.addingTimeInterval(timer.pausedSeconds ?? 0)
        timer.pausedSeconds = nil
        timer.phase = .running
        activity.restTimer = timer
        persistActivity()
    }

    func adjustRestTimer(by seconds: Int, now: Date = Date()) {
        guard var timer = activity.restTimer else { return }
        if timer.phase == .running {
            let remaining = max(0, timer.remainingSeconds(at: now) + seconds)
            timer.endsAt = now.addingTimeInterval(TimeInterval(remaining))
        } else {
            timer.pausedSeconds = TimeInterval(max(0, timer.remainingSeconds(at: now) + seconds))
        }
        activity.restTimer = timer
        persistActivity()
    }

    func skipRestTimer() {
        activity.restTimer = nil
        persistActivity()
    }

    func finishRestTimerIfElapsed(at date: Date = Date()) {
        guard let timer = activity.restTimer, timer.phase == .running, timer.remainingSeconds(at: date) == 0 else { return }
        activity.restTimer = nil
        persistActivity()
        ClientHaptics.timerFinished()
    }

    func finishWorkout(sessionID: UUID, feedback: ClientWorkoutFeedback, now: Date = Date()) {
        guard let index = activity.workouts.firstIndex(where: {
            $0.sessionID == sessionID && $0.dayKey == ClientDayKey.string(for: now) && !$0.isCompleted
        }), activity.workouts[index].exercises.allSatisfy(\.isCompleted) else { return }
        activity.workouts[index].completedAt = now
        activity.workouts[index].feedback = feedback
        activity.restTimer = nil
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

    private func load(userID: UUID, email: String?) async {
        state = .loading
        do {
            let identity = try await repository.identity(authUserID: userID, email: email)
            let snapshot = await repository.snapshot(for: identity)
            agenda = agendaStore.load(userID: identity.authUserID, source: .live)
            activity = activityStore.load(userID: identity.authUserID, source: .live)
            let localContent = personalContentStore.load(userID: identity.authUserID)
            personalContent = localContent
            if let remote = try? await personalRepository.content(userID: identity.authUserID) {
                let merged = localContent.merging(remote)
                personalContent = merged
                try? personalContentStore.save(merged, userID: identity.authUserID)
                if merged != remote {
                    for plan in merged.workoutPlans { try? await personalRepository.saveWorkoutPlan(plan, userID: identity.authUserID) }
                    for plan in merged.nutritionPlans { try? await personalRepository.saveNutritionPlan(plan, userID: identity.authUserID) }
                    for template in merged.mealTemplates { try? await personalRepository.saveMealTemplate(template, userID: identity.authUserID) }
                }
            }
            state = .active(identity: identity, snapshot: snapshot, source: .live)
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
            shouldOfferTrainerCode = false
            if registrationStage == .profileVerification {
                registrationStage = .failed
                Self.logRegistration(
                    stage: .profileVerification,
                    message: error.localizedDescription,
                    userID: userID
                )
            }
            state = .failure((error as? LocalizedError)?.errorDescription ?? "Impossibile verificare il profilo Cliente.")
        }
    }

    private static func logRegistration(
        stage: ClientRegistrationStage,
        message: String,
        status: Int? = nil,
        code: String? = nil,
        userID: UUID? = nil
    ) {
        #if DEBUG
        let statusText = status.map { String($0) } ?? "n/a"
        let codeText = code ?? "n/a"
        let userText = userID?.uuidString ?? "n/a"
        registrationLogger.debug(
            "stage=\(stage.rawValue, privacy: .public) status=\(statusText, privacy: .public) code=\(codeText, privacy: .public) user=\(userText, privacy: .public) message=\(message, privacy: .public)"
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
