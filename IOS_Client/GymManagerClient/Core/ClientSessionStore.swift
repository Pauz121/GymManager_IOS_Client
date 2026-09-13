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
    @Published private(set) var activity: ClientActivityState = .empty
    @Published var isSubmitting = false
    @Published var notice: String?

    private let auth: AuthClient
    private let repository: ClientRepository
    private let agendaStore: PersonalAgendaStore
    private let activityStore: ClientActivityStore

    init(
        auth: AuthClient = ClientSupabaseProvider.client.auth,
        repository: ClientRepository = .shared,
        agendaStore: PersonalAgendaStore = PersonalAgendaStore(),
        activityStore: ClientActivityStore = ClientActivityStore()
    ) {
        self.auth = auth
        self.repository = repository
        self.agendaStore = agendaStore
        self.activityStore = activityStore
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
        activity = .empty
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
    func startDemo(_ persona: ClientDemoPersona) {
        let identity = ClientDemoData.identity(for: persona)
        let snapshot = ClientDemoData.snapshot(for: persona)
        agenda = agendaStore.load(userID: identity.authUserID, source: .demo)
        activity = activityStore.load(userID: identity.authUserID, source: .demo)
        state = .active(identity: identity, snapshot: snapshot, source: .demo)
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
            state = .active(identity: identity, snapshot: snapshot, source: .live)
        } catch {
            state = .failure((error as? LocalizedError)?.errorDescription ?? "Impossibile verificare il profilo Cliente.")
        }
    }

    private func persistActivity() {
        guard case .active(let identity, _, let source) = state else { return }
        do { try activityStore.save(activity, userID: identity.authUserID, source: source) }
        catch { notice = "Attività non salvata su questo dispositivo." }
    }
}
