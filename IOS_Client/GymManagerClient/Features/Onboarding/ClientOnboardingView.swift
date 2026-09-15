import SwiftUI
import UIKit

struct ClientOnboardingView: View {
    enum Path: Hashable { case signIn, register }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Spacer()
                VStack(spacing: 18) {
                    Image("AppIcon")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 92, height: 92)
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                        .shadow(color: ClientClay.accent.opacity(0.26), radius: 24, y: 10)
                    Text("FIT MANAGER")
                        .font(.system(.largeTitle, design: .rounded, weight: .black))
                        .tracking(1.8)
                        .foregroundStyle(ClientClay.ink)
                }
                .accessibilityElement(children: .combine)
                Spacer()
                VStack(spacing: 14) {
                    NavigationLink(value: Path.signIn) { Text("Accedi") }
                        .buttonStyle(ClayPrimaryButtonStyle())
                    NavigationLink(value: Path.register) { Text("Registrati") }
                        .buttonStyle(ClaySecondaryButtonStyle())
                }
            }
            .padding(.horizontal, ClientClay.pagePadding)
            .padding(.vertical, 28)
            .clientPage()
            .navigationDestination(for: Path.self) { path in
                switch path {
                case .signIn: ClientSignInView()
                case .register: ClientRegistrationView()
                }
            }
        }
    }
}

private struct ClientRegistrationView: View {
    private enum Field: Hashable { case firstName, lastName, email, username, password, confirmation }

    @EnvironmentObject private var session: ClientSessionStore
    @FocusState private var focusedField: Field?
    @State private var step = 1
    @State private var attemptedStepOne = false
    @State private var attemptedStepTwo = false
    @State private var input = ClientRegistrationInput(
        firstName: "", lastName: "", biologicalSex: nil, email: "",
        username: "", password: "", passwordConfirmation: ""
    )

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                stepHeader
                if step == 1 { personalDataStep } else { credentialsStep }
            }
            .padding(.horizontal, ClientClay.pagePadding)
            .padding(.vertical, 20)
        }
        .scrollDismissesKeyboard(.interactively)
        .clientPage()
        .navigationTitle("Registrazione")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { session.registrationIssue = nil }
    }

    private var stepHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("PASSO \(step) DI 2")
                .font(.caption.weight(.bold))
                .tracking(1.2)
                .foregroundStyle(ClientClay.accentSoft)
            HStack(spacing: 8) {
                Capsule().fill(ClientClay.accent).frame(height: 5)
                Capsule().fill(step == 2 ? ClientClay.accent : ClientClay.surfaceElevated).frame(height: 5)
            }
            .accessibilityLabel("Passo \(step) di 2")
        }
    }

    private var personalDataStep: some View {
        VStack(alignment: .leading, spacing: 22) {
            ClientPageTitle("I tuoi dati", eyebrow: "Account Fit Manager", subtitle: "Inserisci le informazioni di base del tuo profilo.")
            VStack(alignment: .leading, spacing: 14) {
                registrationField("Nome", text: $input.firstName, contentType: .givenName, field: .firstName)
                inlineIssue(for: .firstName, attempted: attemptedStepOne)
                registrationField("Cognome", text: $input.lastName, contentType: .familyName, field: .lastName)
                inlineIssue(for: .lastName, attempted: attemptedStepOne)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Sesso").font(.subheadline.weight(.semibold)).foregroundStyle(ClientClay.secondaryInk)
                    Picker("Sesso", selection: $input.biologicalSex) {
                        Text("Uomo").tag(ClientBiologicalSex?.some(.male))
                        Text("Donna").tag(ClientBiologicalSex?.some(.female))
                    }
                    .pickerStyle(.segmented)
                    .frame(minHeight: 48)
                }
                inlineIssue(for: .biologicalSex, attempted: attemptedStepOne)

                registrationField("Email", text: $input.email, contentType: .emailAddress, field: .email)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                inlineIssue(for: .email, attempted: attemptedStepOne)
            }
            .clayCard()

            Button("Continua") {
                attemptedStepOne = true
                session.registrationIssue = nil
                guard ClientRegistrationValidation.stepOneIssue(for: input) == nil else { return }
                withAnimation(.easeInOut(duration: 0.22)) { step = 2 }
                focusedField = .username
            }
            .buttonStyle(ClayPrimaryButtonStyle())
            .disabled(session.isSubmitting)
        }
    }

    private var credentialsStep: some View {
        VStack(alignment: .leading, spacing: 22) {
            ClientPageTitle("Crea le credenziali", eyebrow: "Account Fit Manager", subtitle: "Scegli uno username e una password sicura.")
            VStack(alignment: .leading, spacing: 14) {
                registrationField("Username", text: $input.username, contentType: .username, field: .username)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                inlineIssue(for: .username, attempted: attemptedStepTwo)

                SecureField("Password · almeno 12 caratteri", text: $input.password)
                    .textContentType(.newPassword)
                    .focused($focusedField, equals: .password)
                    .submitLabel(.next)
                    .onSubmit { focusedField = .confirmation }
                    .clientInputField()
                inlineIssue(for: .password, attempted: attemptedStepTwo)

                SecureField("Ripeti password", text: $input.passwordConfirmation)
                    .textContentType(.newPassword)
                    .focused($focusedField, equals: .confirmation)
                    .submitLabel(.done)
                    .clientInputField()
                inlineIssue(for: .passwordConfirmation, attempted: attemptedStepTwo)

                if let issue = session.registrationIssue, issue.field == .form {
                    InlineRegistrationIssue(message: issue.message)
                }
            }
            .clayCard()

            VStack(spacing: 12) {
                Button {
                    attemptedStepTwo = true
                    guard ClientRegistrationValidation.stepTwoIssue(for: input) == nil else { return }
                    Task { await session.register(input) }
                } label: {
                    if session.isSubmitting {
                        HStack(spacing: 10) {
                            ProgressView().tint(.white)
                            Text("Creazione account…")
                        }
                    } else {
                        Text("Crea account")
                    }
                }
                .buttonStyle(ClayPrimaryButtonStyle())
                .disabled(session.isSubmitting)

                Button("Indietro") {
                    session.registrationIssue = nil
                    withAnimation(.easeInOut(duration: 0.22)) { step = 1 }
                }
                .buttonStyle(ClaySecondaryButtonStyle())
                .disabled(session.isSubmitting)
            }
        }
    }

    private func registrationField(
        _ title: String,
        text: Binding<String>,
        contentType: UITextContentType?,
        field: Field
    ) -> some View {
        TextField(title, text: text)
            .textContentType(contentType)
            .focused($focusedField, equals: field)
            .submitLabel(field == .email ? .done : .next)
            .onSubmit { advance(after: field) }
            .clientInputField()
    }

    private func advance(after field: Field) {
        switch field {
        case .firstName: focusedField = .lastName
        case .lastName: focusedField = .email
        case .email: focusedField = nil
        case .username: focusedField = .password
        case .password: focusedField = .confirmation
        case .confirmation: focusedField = nil
        }
    }

    @ViewBuilder
    private func inlineIssue(for field: ClientRegistrationField, attempted: Bool) -> some View {
        let localIssue = step == 1
            ? ClientRegistrationValidation.stepOneIssue(for: input)
            : ClientRegistrationValidation.stepTwoIssue(for: input)
        if let serverIssue = session.registrationIssue, serverIssue.field == field {
            InlineRegistrationIssue(message: serverIssue.message)
        } else if attempted, let localIssue, localIssue.field == field {
            InlineRegistrationIssue(message: localIssue.message)
        }
    }
}

struct ClientEmailConfirmationView: View {
    let email: String
    @EnvironmentObject private var session: ClientSessionStore

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()
                Image(systemName: "envelope.badge.shield.half.filled")
                    .font(.system(size: 48, weight: .semibold))
                    .foregroundStyle(ClientClay.accentSoft)
                    .frame(width: 92, height: 92)
                    .background(ClientClay.accent.opacity(0.13), in: Circle())
                ClientPageTitle("Controlla la tua email", eyebrow: "Account creato", subtitle: "Abbiamo inviato il link di verifica a \(email). Dopo la conferma potrai accedere.")
                    .multilineTextAlignment(.center)
                Spacer()
                NavigationLink {
                    ClientSignInView(prefilledIdentifier: email)
                } label: {
                    Text("Accedi dopo la conferma")
                }
                .buttonStyle(ClayPrimaryButtonStyle())
                Button("Torna alla schermata iniziale") { session.showOnboarding() }
                    .buttonStyle(ClaySecondaryButtonStyle())
            }
            .padding(.horizontal, ClientClay.pagePadding)
            .padding(.vertical, 28)
            .clientPage()
        }
    }
}

struct ClientTrainerInvitationView: View {
    @EnvironmentObject private var session: ClientSessionStore
    @State private var showsCodeField = false
    @State private var code = ""

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 22) {
                Spacer()
                Image(systemName: "person.2.badge.plus")
                    .font(.system(size: 44, weight: .semibold))
                    .foregroundStyle(ClientClay.accentSoft)
                    .frame(width: 88, height: 88)
                    .background(ClientClay.accent.opacity(0.14), in: Circle())
                ClientPageTitle(
                    "Hai un codice di accesso?",
                    eyebrow: "Trainer opzionale",
                    subtitle: "Se il tuo Trainer ti ha fornito un codice, puoi collegare ora la tua scheda. Puoi farlo anche più tardi da Account."
                )

                if showsCodeField {
                    TrainerCodeEntryForm(code: $code, actionTitle: "Collega Trainer") {
                        await session.connectTrainer(code: code)
                    }
                    Button("Non ora") { Task { await session.skipTrainerLinking() } }
                        .buttonStyle(ClaySecondaryButtonStyle())
                        .disabled(session.isSubmitting)
                } else {
                    Button("Inserisci codice") {
                        withAnimation(.easeInOut(duration: 0.2)) { showsCodeField = true }
                    }
                    .buttonStyle(ClayPrimaryButtonStyle())
                    Button("Non ora") { Task { await session.skipTrainerLinking() } }
                        .buttonStyle(ClaySecondaryButtonStyle())
                        .disabled(session.isSubmitting)
                }
                Spacer()
            }
            .padding(.horizontal, ClientClay.pagePadding)
            .padding(.vertical, 24)
            .clientPage()
        }
    }
}

struct TrainerCodeEntryForm: View {
    @EnvironmentObject private var session: ClientSessionStore
    @Binding var code: String
    let actionTitle: String
    let onSubmit: () async -> Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("Codice di accesso", text: $code)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .textContentType(.oneTimeCode)
                .font(.body.monospaced())
                .clientInputField()
                .onChange(of: code) { _, value in code = TrainerCodeService.normalized(value) }
            if !code.isEmpty && !TrainerCodeService.isValid(code) {
                InlineRegistrationIssue(message: "Inserisci il codice completo nel formato GM-XXXX-XXXX-XXXX-XXXX-XXXX.")
            }
            Button(actionTitle) {
                Task {
                    if await onSubmit() { code = "" }
                }
            }
            .buttonStyle(ClayPrimaryButtonStyle())
            .disabled(session.isSubmitting || !TrainerCodeService.isValid(code))
            Label("Il codice viene verificato e consumato dal servizio protetto.", systemImage: "lock.shield")
                .font(.caption)
                .foregroundStyle(ClientClay.secondaryInk)
        }
    }
}

private struct InlineRegistrationIssue: View {
    let message: String
    var body: some View {
        Label(message, systemImage: "exclamationmark.circle.fill")
            .font(.caption.weight(.semibold))
            .foregroundStyle(ClientClay.accentHot)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityLabel("Errore: \(message)")
    }
}

private struct ClientSignInView: View {
    @EnvironmentObject private var session: ClientSessionStore
    @State private var identifier: String
    @State private var password = ""

    init(prefilledIdentifier: String = "") {
        _identifier = State(initialValue: prefilledIdentifier)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                ClientPageTitle("Bentornato", eyebrow: "Accesso Cliente", subtitle: "Accedi con la tua email. Gli account esistenti possono continuare a usare lo username.")
                VStack(spacing: 14) {
                    TextField("Email o username esistente", text: $identifier)
                        .textContentType(.username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .clientInputField()
                    SecureField("Password", text: $password)
                        .textContentType(.password)
                        .clientInputField()
                    Button { Task { await session.signIn(identifier: identifier, password: password) } } label: {
                        if session.isSubmitting { ProgressView().tint(.white) } else { Text("Accedi") }
                    }
                    .buttonStyle(ClayPrimaryButtonStyle())
                    .disabled(session.isSubmitting || identifier.isEmpty || password.isEmpty)
                }
                .clayCard()

                #if DEBUG
                DemoEntryButtons()
                #endif
            }
            .padding(.horizontal, ClientClay.pagePadding)
            .padding(.vertical, 20)
        }
        .clientPage()
        .navigationTitle("Accesso")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#if DEBUG
private struct DemoEntryButtons: View {
    @EnvironmentObject private var session: ClientSessionStore
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Account demo").font(.headline)
            Text("Dati sintetici: nessuna credenziale o chiamata reale.")
                .font(.caption).foregroundStyle(ClientClay.secondaryInk)
            Button { session.startDemo(.trainerConnected) } label: {
                Label("Demo · Cliente con Trainer", systemImage: "person.2.fill")
            }
            .buttonStyle(ClaySecondaryButtonStyle())
            Button { session.startDemo(.standalone) } label: {
                Label("Demo · Cliente autonomo", systemImage: "figure.walk")
            }
            .buttonStyle(ClaySecondaryButtonStyle())
        }
        .clayCard()
    }
}
#endif
