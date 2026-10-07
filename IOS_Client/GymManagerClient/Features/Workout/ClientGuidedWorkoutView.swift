import SwiftUI

struct ClientWorkoutCreationChoiceView: View {
    enum Choice { case manual, guided }

    let onSelect: (Choice) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("COME VUOI CREARLA?")
                            .font(.caption.weight(.bold)).tracking(1.3).foregroundStyle(ClientClay.accent)
                        Text("Il tuo prossimo programma")
                            .font(.system(.title, design: .rounded, weight: .heavy)).foregroundStyle(ClientClay.ink)
                        Text("Puoi partire da un foglio vuoto oppure lasciare che Weol costruisca una base coerente, sempre modificabile.")
                            .font(.subheadline).foregroundStyle(ClientClay.secondaryInk)
                    }
                    .premiumCard(tint: ClientClay.accent)

                    choiceCard(
                        title: "Crea da zero",
                        detail: "Scegli giorni, esercizi, serie, ripetizioni, recuperi e note.",
                        symbol: "slider.horizontal.3",
                        tint: ClientClay.sage
                    ) { select(.manual) }

                    choiceCard(
                        title: "Crea per me",
                        detail: "Rispondi a poche domande e ricevi un programma guidato, controllato e modificabile.",
                        symbol: "wand.and.stars",
                        tint: ClientClay.accent
                    ) { select(.guided) }

                    Label("Disponibile solo senza Trainer collegato", systemImage: "lock.shield.fill")
                        .font(.caption.weight(.semibold)).foregroundStyle(ClientClay.secondaryInk)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .padding(ClientClay.pagePadding)
            }
            .clientPage()
            .navigationTitle("Nuova scheda")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Chiudi") { dismiss() } } }
        }
    }

    private func choiceCard(
        title: String,
        detail: String,
        symbol: String,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: symbol)
                    .font(.title2.weight(.bold)).foregroundStyle(.white)
                    .frame(width: 52, height: 52)
                    .background(tint.gradient, in: RoundedRectangle(cornerRadius: 17, style: .continuous))
                VStack(alignment: .leading, spacing: 5) {
                    Text(title).font(.title3.weight(.bold)).foregroundStyle(ClientClay.ink)
                    Text(detail).font(.subheadline).foregroundStyle(ClientClay.secondaryInk).multilineTextAlignment(.leading)
                }
                Spacer(minLength: 4)
                Image(systemName: "chevron.right").font(.headline).foregroundStyle(tint)
            }
            .clayCard()
        }
        .buttonStyle(.plain)
        .accessibilityHint(detail)
    }

    private func select(_ choice: Choice) {
        dismiss()
        onSelect(choice)
    }
}

struct ClientGuidedWorkoutView: View {
    let onSaved: () -> Void
    let onEdit: (ClientPersonalWorkoutPlan) -> Void

    @EnvironmentObject private var session: ClientSessionStore
    @Environment(\.dismiss) private var dismiss
    @State private var answers = ClientWorkoutQuestionnaireAnswers()
    @State private var step = 0
    @State private var catalog: [ClientExerciseCatalogItem] = []
    @State private var isLoadingCatalog = true
    @State private var isSaving = false
    @State private var avoidedExercises = ""
    @State private var generationError: String?
    @State private var result: ClientGeneratedWorkoutResult?
    @State private var variation = 0
    @State private var selectedSessionID: UUID?

    private let generator = ClientWorkoutGenerator()
    private let stepCount = 10
    private let columns = [GridItem(.adaptive(minimum: 118), spacing: 10)]

    var body: some View {
        NavigationStack {
            Group {
                if let result {
                    preview(result)
                } else {
                    questionnaire
                }
            }
            .clientPage()
            .navigationTitle(result == nil ? "Programma guidato" : "Il tuo programma")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Chiudi") { dismiss() }.disabled(isSaving)
                }
            }
            .task {
                catalog = await session.personalExerciseCatalog()
                isLoadingCatalog = false
            }
        }
        .interactiveDismissDisabled(isSaving)
    }

    private var questionnaire: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    wizardHeader
                    stepContent
                    if let generationError {
                        Label(generationError, systemImage: "exclamationmark.triangle.fill")
                            .font(.subheadline).foregroundStyle(ClientClay.accentSoft)
                            .clayCard(padding: 14)
                    }
                }
                .padding(ClientClay.pagePadding)
            }
            navigationBar
        }
    }

    private var wizardHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("PASSO \(step + 1) DI \(stepCount)")
                    .font(.caption.weight(.bold)).tracking(1.2).foregroundStyle(ClientClay.accent)
                Spacer()
                Text("\(Int(Double(step + 1) / Double(stepCount) * 100))%")
                    .font(.caption.monospacedDigit().weight(.bold)).foregroundStyle(ClientClay.secondaryInk)
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(ClientClay.inset).frame(height: 7)
                    Capsule().fill(ClientClay.brandGradient)
                        .frame(width: proxy.size.width * Double(step + 1) / Double(stepCount), height: 7)
                }
            }
            .frame(height: 7)
            Text(stepTitle).font(.system(.title2, design: .rounded, weight: .heavy)).foregroundStyle(ClientClay.ink)
            Text(stepSubtitle).font(.subheadline).foregroundStyle(ClientClay.secondaryInk)
        }
        .premiumCard(tint: step == stepCount - 1 ? ClientClay.sage : ClientClay.accent)
    }

    @ViewBuilder private var stepContent: some View {
        switch step {
        case 0: experienceStep
        case 1: frequencyStep
        case 2: durationStep
        case 3: equipmentStep
        case 4: splitStep
        case 5: priorityStep
        case 6: goalStep
        case 7: phaseStep
        case 8: limitationsStep
        default: planDurationStep
        }
    }

    private var experienceStep: some View {
        VStack(spacing: 10) {
            ForEach(ClientTrainingExperience.allCases, id: \.self) { value in
                selectionCard(value.displayName, detail: experienceDetail(value), selected: answers.experience == value) {
                    answers.experience = value
                }
            }
        }
    }

    private var frequencyStep: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(2...6, id: \.self) { value in
                metricChoice("\(value)", detail: "giorni", selected: answers.weeklyFrequency == value) {
                    answers.weeklyFrequency = value
                    resizeCustomSplit()
                }
            }
        }
    }

    private var durationStep: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach([30, 45, 60, 75, 90], id: \.self) { value in
                metricChoice("\(value)", detail: "minuti", selected: answers.sessionDurationMinutes == value) {
                    answers.sessionDurationMinutes = value
                }
            }
        }
    }

    private var equipmentStep: some View {
        VStack(spacing: 10) {
            ForEach(ClientTrainingEquipment.allCases, id: \.self) { value in
                selectionCard(value.displayName, detail: equipmentDetail(value), selected: answers.equipment == value) {
                    answers.equipment = value
                }
            }
        }
    }

    private var splitStep: some View {
        VStack(spacing: 12) {
            ForEach(availableSplits, id: \.self) { value in
                selectionCard(value.displayName, detail: splitDetail(value), selected: answers.splitPreference == value) {
                    answers.splitPreference = value
                    if value == .custom { resizeCustomSplit() }
                }
            }
            if answers.splitPreference == .custom {
                customSplitEditor
            }
        }
    }

    private var priorityStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                answers.priorityMuscles = []
            } label: {
                Label("Nessuno in particolare", systemImage: answers.priorityMuscles.isEmpty ? "checkmark.circle.fill" : "circle")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(ClaySecondaryButtonStyle())

            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(ClientMuscleRegion.allCases, id: \.self) { muscle in
                    chip(muscle.displayName, selected: answers.priorityMuscles.contains(muscle)) {
                        if answers.priorityMuscles.contains(muscle) { answers.priorityMuscles.remove(muscle) }
                        else { answers.priorityMuscles.insert(muscle) }
                    }
                }
            }
            Text("La priorità aumenta moderatamente ordine o volume, senza trascurare gli altri gruppi.")
                .font(.caption).foregroundStyle(ClientClay.secondaryInk)
        }
        .clayCard()
    }

    private var goalStep: some View {
        VStack(spacing: 10) {
            ForEach(ClientTrainingGoal.allCases, id: \.self) { value in
                selectionCard(value.displayName, detail: goalDetail(value), selected: answers.goal == value) {
                    answers.goal = value
                }
            }
        }
    }

    private var phaseStep: some View {
        VStack(spacing: 10) {
            ForEach(ClientNutritionPhase.allCases, id: \.self) { value in
                selectionCard(value.displayName, detail: phaseDetail(value), selected: answers.nutritionPhase == value) {
                    answers.nutritionPhase = value
                }
            }
            Text("La fase modifica soprattutto volume e recupero: non trasforma automaticamente tutte le ripetizioni.")
                .font(.caption).foregroundStyle(ClientClay.secondaryInk).clayCard(padding: 14)
        }
    }

    private var limitationsStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Esercizi da evitare").font(.headline).foregroundStyle(ClientClay.ink)
                TextField("Es. leg press, french press", text: $avoidedExercises)
                    .textInputAutocapitalization(.never).clientInputField()
                Text("Separa più esercizi con una virgola.").font(.caption).foregroundStyle(ClientClay.secondaryInk)
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("Limitazioni o preferenze").font(.headline).foregroundStyle(ClientClay.ink)
                TextField("Facoltativo", text: $answers.limitations, axis: .vertical)
                    .lineLimit(3...6).clientInputField()
            }
            Label(
                "Weol non genera protocolli riabilitativi. In presenza di dolore importante o infortunio, la generazione viene fermata.",
                systemImage: "cross.case.fill"
            )
            .font(.caption).foregroundStyle(ClientClay.secondaryInk)
        }
        .clayCard()
    }

    private var planDurationStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach([4, 6, 8, 12], id: \.self) { value in
                    metricChoice("\(value)", detail: "settimane", selected: answers.durationWeeks == value) {
                        answers.durationWeeks = value
                    }
                }
            }
            Label("Default consigliato: 8 settimane", systemImage: "calendar.badge.checkmark")
                .font(.caption.weight(.semibold)).foregroundStyle(ClientClay.secondaryInk)
                .clayCard(padding: 14)
        }
    }

    private var navigationBar: some View {
        HStack(spacing: 12) {
            if step > 0 {
                Button("Indietro") { withAnimation(.snappy) { step -= 1 } }
                    .buttonStyle(ClaySecondaryButtonStyle())
            }
            Button {
                if step == stepCount - 1 { generate() }
                else { withAnimation(.snappy) { step += 1 } }
            } label: {
                Label(step == stepCount - 1 ? "Crea programma" : "Continua", systemImage: step == stepCount - 1 ? "wand.and.stars" : "arrow.right")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(ClayPrimaryButtonStyle())
            .disabled(isLoadingCatalog || !canContinue)
        }
        .padding(.horizontal, ClientClay.pagePadding).padding(.vertical, 12)
        .background(ClientClay.canvas.opacity(0.97))
    }

    private func preview(_ generated: ClientGeneratedWorkoutResult) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 8) {
                    ClientBadge(text: "PROGRAMMA CONTROLLATO", tint: ClientClay.sage, symbol: "checkmark.shield.fill")
                    Text(generated.plan.title).font(.system(.title2, design: .rounded, weight: .heavy)).foregroundStyle(.white)
                    Text("\(generated.plan.sessions.count) allenamenti · \(generated.plan.durationWeeks ?? 8) settimane · double progression")
                        .font(.subheadline).foregroundStyle(.white.opacity(0.72))
                }
                .premiumCard(tint: ClientClay.sage)

                validationSummary(generated.validation)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 9) {
                        ForEach(generated.plan.sessions) { workout in
                            Button {
                                withAnimation(.snappy) { selectedSessionID = workout.id }
                            } label: {
                                Text(workout.name)
                                    .font(.subheadline.weight(.bold))
                                    .padding(.horizontal, 14).frame(minHeight: 44)
                                    .background(selectedWorkout(in: generated.plan)?.id == workout.id ? ClientClay.accent : ClientClay.surfaceElevated, in: Capsule())
                                    .foregroundStyle(selectedWorkout(in: generated.plan)?.id == workout.id ? .white : ClientClay.ink)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                if let workout = selectedWorkout(in: generated.plan) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(workout.name).font(.title3.weight(.bold)).foregroundStyle(ClientClay.ink)
                                Text("\(workout.durationMinutes ?? answers.sessionDurationMinutes) min · \(workout.exercises.count) esercizi")
                                    .font(.caption).foregroundStyle(ClientClay.secondaryInk)
                            }
                            Spacer()
                            ClientBadge(text: weekdayName(workout.weekday), tint: ClientClay.accent, symbol: "calendar")
                        }
                        ForEach(Array(workout.exercises.enumerated()), id: \.element.id) { index, exercise in
                            HStack(alignment: .top, spacing: 12) {
                                Text("\(index + 1)").font(.caption.weight(.bold)).foregroundStyle(.white)
                                    .frame(width: 28, height: 28).background(ClientClay.accent, in: Circle())
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(exercise.name).font(.headline).foregroundStyle(ClientClay.ink)
                                    Text("\(exercise.sets) × \(exercise.repetitions) · \(exercise.effortTarget) · \(exercise.restSeconds)s")
                                        .font(.caption).foregroundStyle(ClientClay.secondaryInk)
                                    if let muscles = exercise.primaryMuscles, !muscles.isEmpty {
                                        Text(muscles.map(\.displayName).joined(separator: " · "))
                                            .font(.caption2.weight(.semibold)).foregroundStyle(ClientClay.accent)
                                    }
                                }
                            }
                            if index < workout.exercises.count - 1 { Divider().opacity(0.35) }
                        }
                    }
                    .clayCard()
                }

                VStack(spacing: 10) {
                    Button {
                        Task { await save(generated.plan) }
                    } label: {
                        if isSaving { ProgressView().tint(.white).frame(maxWidth: .infinity) }
                        else { Label("Usa questa scheda", systemImage: "checkmark.circle.fill").frame(maxWidth: .infinity) }
                    }
                    .buttonStyle(ClayPrimaryButtonStyle()).disabled(isSaving)

                    Button { onEdit(generated.plan) } label: {
                        Label("Modifica", systemImage: "pencil").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(ClaySecondaryButtonStyle()).disabled(isSaving)

                    Button {
                        variation += 1
                        generate()
                    } label: {
                        Label("Rigenera", systemImage: "arrow.triangle.2.circlepath").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(ClaySecondaryButtonStyle()).disabled(isSaving)
                }
            }
            .padding(ClientClay.pagePadding)
        }
    }

    private func validationSummary(_ validation: ClientWorkoutPlanValidation) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("CONTROLLO DI COERENZA").font(.caption.weight(.bold)).tracking(1.1).foregroundStyle(ClientClay.sage)
            validationRow("Gruppi principali", passed: validation.allMajorGroupsCovered)
            validationRow("Volume settimanale", passed: validation.weeklyVolumeValid)
            validationRow("Durata sessioni", passed: validation.sessionDurationPlausible)
            validationRow("Attrezzatura", passed: validation.equipmentCompatible)
            validationRow("Recupero e pattern", passed: validation.recoveryPlausible && validation.movementBalanceValid)
        }
        .clayCard()
    }

    private func validationRow(_ title: String, passed: Bool) -> some View {
        HStack {
            Text(title).font(.subheadline).foregroundStyle(ClientClay.ink)
            Spacer()
            Label(passed ? "OK" : "Da rivedere", systemImage: passed ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .font(.caption.weight(.bold)).foregroundStyle(passed ? ClientClay.sage : ClientClay.accent)
        }
    }

    private func selectionCard(_ title: String, detail: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.headline).foregroundStyle(ClientClay.ink)
                    Text(detail).font(.caption).foregroundStyle(ClientClay.secondaryInk).multilineTextAlignment(.leading)
                }
                Spacer()
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.title3).foregroundStyle(selected ? ClientClay.accent : ClientClay.secondaryInk)
            }
            .clayCard(padding: 14)
            .overlay { RoundedRectangle(cornerRadius: ClientClay.radius).stroke(selected ? ClientClay.accent.opacity(0.72) : ClientClay.border, lineWidth: selected ? 1.5 : 1) }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func metricChoice(_ value: String, detail: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Text(value).font(.title2.monospacedDigit().weight(.heavy))
                Text(detail).font(.caption.weight(.semibold))
            }
            .foregroundStyle(selected ? .white : ClientClay.ink)
            .frame(maxWidth: .infinity, minHeight: 74)
            .background(selected ? ClientClay.brandGradient : LinearGradient(colors: [ClientClay.surfaceElevated, ClientClay.surface], startPoint: .top, endPoint: .bottom), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay { RoundedRectangle(cornerRadius: 18).stroke(selected ? ClientClay.accentSoft.opacity(0.65) : ClientClay.border) }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func chip(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(.caption.weight(.bold)).lineLimit(1).minimumScaleFactor(0.75)
                .frame(maxWidth: .infinity, minHeight: 44)
                .foregroundStyle(selected ? .white : ClientClay.ink)
                .background(selected ? ClientClay.accent : ClientClay.surfaceElevated, in: Capsule())
                .overlay { Capsule().stroke(selected ? ClientClay.accentSoft : ClientClay.border) }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var customSplitEditor: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(0..<answers.weeklyFrequency, id: \.self) { day in
                VStack(alignment: .leading, spacing: 8) {
                    Text("GIORNO \(day + 1)").font(.caption.weight(.bold)).tracking(1).foregroundStyle(ClientClay.accent)
                    LazyVGrid(columns: columns, spacing: 8) {
                        ForEach(ClientMuscleRegion.allCases, id: \.self) { muscle in
                            chip(muscle.displayName, selected: customGroup(day).contains(muscle)) {
                                toggleCustomMuscle(muscle, day: day)
                            }
                        }
                    }
                }
            }
        }
        .clayCard()
    }

    private var availableSplits: [ClientWorkoutSplitPreference] {
        var values: [ClientWorkoutSplitPreference] = [.automatic, .fullBody]
        if answers.weeklyFrequency >= 3 { values.append(.upperLower) }
        if answers.weeklyFrequency >= 3 { values.append(.pushPullLegs) }
        values.append(.custom)
        return values
    }

    private var canContinue: Bool {
        if step == 4, answers.splitPreference == .custom {
            return answers.customSplitGroups.count == answers.weeklyFrequency
                && answers.customSplitGroups.allSatisfy { !$0.isEmpty }
        }
        return true
    }

    private var stepTitle: String {
        ["La tua esperienza", "Frequenza settimanale", "Durata della sessione", "Attrezzatura", "Organizzazione dei gruppi", "Gruppi prioritari", "Obiettivo", "Fase attuale", "Preferenze e limitazioni", "Durata del programma"][step]
    }

    private var stepSubtitle: String {
        [
            "Serve a calibrare volume e complessità.",
            "Quante volte vuoi allenarti ogni settimana?",
            "Quanto tempo vuoi dedicare mediamente a ogni allenamento?",
            "Mostreremo solo esercizi compatibili.",
            "Scegli uno split oppure lascia decidere a Weol.",
            "Puoi dare una priorità moderata senza perdere equilibrio.",
            "Il range di ripetizioni dipenderà anche dal tipo di esercizio.",
            "Bulk, mantenimento e cut modificano il carico di lavoro, non stravolgono il programma.",
            "Facoltativo. Nessuna diagnosi o prescrizione riabilitativa.",
            "La progressione coprirà l'intero periodo."
        ][step]
    }

    private func experienceDetail(_ value: ClientTrainingExperience) -> String {
        switch value {
        case .beginner: "Poco tempo di allenamento o tecnica ancora in costruzione."
        case .intermediate: "Buona familiarità con i principali esercizi."
        case .advanced: "Esperienza solida, tecnica e recupero già conosciuti."
        }
    }

    private func equipmentDetail(_ value: ClientTrainingEquipment) -> String {
        switch value {
        case .fullGym: "Macchine, cavi, bilancieri e manubri."
        case .homeGym: "Attrezzatura essenziale, manubri o bilanciere."
        case .bodyweight: "Corpo libero e supporti essenziali."
        }
    }

    private func splitDetail(_ value: ClientWorkoutSplitPreference) -> String {
        switch value {
        case .automatic: "La struttura più adatta alla frequenza scelta."
        case .fullBody: "Tutto il corpo distribuito in ogni sessione."
        case .upperLower: "Parte alta e parte bassa alternate."
        case .pushPullLegs: "Spinta, tirata e gambe in rotazione."
        case .custom: "Scegli i gruppi di ogni giornata."
        }
    }

    private func goalDetail(_ value: ClientTrainingGoal) -> String {
        switch value {
        case .hypertrophy: "Volume equilibrato e range moderati."
        case .strengthAndMass: "Alcuni fondamentali più pesanti, complementari moderati."
        case .recomposition: "Programma completo e sostenibile."
        case .maintenance: "Stimolo efficace con fatica controllata."
        }
    }

    private func phaseDetail(_ value: ClientNutritionPhase) -> String {
        switch value {
        case .bulk: "Volume medio e progressione quando il recupero lo consente."
        case .maintenance: "Equilibrio tra volume, intensità e recupero."
        case .cut: "Mantiene carichi significativi e riduce il volume inutile."
        }
    }

    private func resizeCustomSplit() {
        while answers.customSplitGroups.count < answers.weeklyFrequency { answers.customSplitGroups.append([]) }
        if answers.customSplitGroups.count > answers.weeklyFrequency {
            answers.customSplitGroups = Array(answers.customSplitGroups.prefix(answers.weeklyFrequency))
        }
    }

    private func customGroup(_ day: Int) -> [ClientMuscleRegion] {
        answers.customSplitGroups.indices.contains(day) ? answers.customSplitGroups[day] : []
    }

    private func toggleCustomMuscle(_ muscle: ClientMuscleRegion, day: Int) {
        resizeCustomSplit()
        if let index = answers.customSplitGroups[day].firstIndex(of: muscle) {
            answers.customSplitGroups[day].remove(at: index)
        } else {
            answers.customSplitGroups[day].append(muscle)
        }
    }

    private func generate() {
        answers.avoidedExerciseNames = avoidedExercises.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        generationError = nil
        do {
            let generated = try generator.generate(answers: answers, catalog: catalog, variation: variation)
            result = generated
            selectedSessionID = generated.plan.sessions.first?.id
            ClientHaptics.success()
        } catch {
            generationError = (error as? LocalizedError)?.errorDescription ?? "Non è stato possibile creare un programma coerente."
            ClientHaptics.warning()
        }
    }

    private func selectedWorkout(in plan: ClientPersonalWorkoutPlan) -> ClientPersonalWorkoutSession? {
        plan.sessions.first(where: { $0.id == selectedSessionID }) ?? plan.sessions.first
    }

    private func save(_ plan: ClientPersonalWorkoutPlan) async {
        isSaving = true
        let confirmed = await session.savePersonalWorkoutPlanConfirmed(plan)
        isSaving = false
        if confirmed {
            ClientHaptics.success()
            onSaved()
            dismiss()
        } else {
            ClientHaptics.warning()
        }
    }

    private func weekdayName(_ value: Int?) -> String {
        guard let value, (1...7).contains(value) else { return "Giorno libero" }
        return ["Lun", "Mar", "Mer", "Gio", "Ven", "Sab", "Dom"][value - 1]
    }
}
