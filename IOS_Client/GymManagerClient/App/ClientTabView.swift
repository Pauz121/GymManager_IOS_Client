import SwiftUI
import UIKit

enum ClientTab: Hashable { case today, workout, nutrition, progress, space }

struct ClientTabView: View {
    let identity: ClientIdentity
    let snapshot: ClientSnapshot
    let source: ClientDataSource
    @State private var selectedTab: ClientTab = .today
    @EnvironmentObject private var session: ClientSessionStore
    @EnvironmentObject private var healthKit: HealthKitStepService
    @EnvironmentObject private var avatarStore: ClientAvatarStore
    @Environment(\.scenePhase) private var scenePhase
    @State private var didEnterBackground = false

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack { ClientHomeView(identity: identity, snapshot: snapshot, source: source, selectedTab: $selectedTab) }
                .tag(ClientTab.today)
            NavigationStack { ClientWorkoutView(snapshot: snapshot, identity: identity) }
                .tag(ClientTab.workout)
            NavigationStack { ClientNutritionView(snapshot: snapshot, identity: identity) }
                .tag(ClientTab.nutrition)
            NavigationStack { ClientProgressView(entries: snapshot.progress, identity: identity, source: source) }
                .tag(ClientTab.progress)
            NavigationStack { PersonalSpaceView(identity: identity, snapshot: snapshot, source: source) }
                .tag(ClientTab.space)
        }
        .tint(ClientClay.accent)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            ClientPremiumTabBar(
                selection: $selectedTab,
                avatar: avatarStore.image(for: identity.authUserID)
            )
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            VStack(spacing: 0) {
                if source == .demo {
                    Text("DEMO · nessun dato reale")
                        .font(.caption2.weight(.bold)).tracking(0.8)
                        .foregroundStyle(ClientClay.color(.backgroundPrimary)).padding(.horizontal, 12).padding(.vertical, 6)
                        .background(ClientClay.warning, in: Capsule()).padding(.vertical, 5)
                        .accessibilityLabel("Modalità demo, nessun dato reale")
                        .allowsHitTesting(false)
                }
                if let message = session.refreshError {
                    ClientContentFailureCard(title: "Aggiornamento dati", message: message, isRefreshing: session.isRefreshing) {
                        Task { await session.refresh() }
                    }
                    .padding(.horizontal, ClientClay.pagePadding).padding(.vertical, 6)
                }
            }
        }
        .task(id: identity.authUserID) { avatarStore.load(userID: identity.authUserID) }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { session.finishRestTimerIfElapsed() }
            if phase == .background { didEnterBackground = true }
            guard source == .live, phase == .active, didEnterBackground else { return }
            didEnterBackground = false
            guard session.canRefreshOnForeground else { return }
            Task { await session.refresh() }
        }
        .sheet(isPresented: healthConnectionPrompt) {
            ClientHealthConnectionPrompt()
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
    }

    private var healthConnectionPrompt: Binding<Bool> {
        Binding(
            get: {
                source == .live
                    && !session.shouldOfferTrainerCode
                    && healthKit.shouldOfferConnectionPrompt
            },
            set: { isPresented in
                if !isPresented, healthKit.permissionDecision == .notAsked {
                    healthKit.declineConnection()
                }
            }
        )
    }
}

private struct ClientHealthConnectionPrompt: View {
    @EnvironmentObject private var healthKit: HealthKitStepService

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Image(systemName: "heart.text.square.fill")
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(ClientClay.sage)
                .frame(width: 64, height: 64)
                .background(ClientClay.sage.opacity(0.13), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            VStack(alignment: .leading, spacing: 7) {
                Text("Collega Apple Salute")
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .foregroundStyle(ClientClay.ink)
                Text("GymManager può leggere i passi registrati dal tuo iPhone per aggiornare automaticamente l’attività di oggi.")
                    .font(.subheadline).foregroundStyle(ClientClay.secondaryInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Label("Viene richiesto soltanto l’accesso in lettura ai passi.", systemImage: "lock.shield.fill")
                .font(.caption).foregroundStyle(ClientClay.secondaryInk)
            Spacer(minLength: 0)
            Button {
                Task { await healthKit.requestAccessAndRefresh() }
            } label: {
                Label("Collega", systemImage: "heart.fill")
            }
            .buttonStyle(ClayPrimaryButtonStyle())
            Button("Non ora") { healthKit.declineConnection() }
                .buttonStyle(ClaySecondaryButtonStyle())
        }
        .padding(.horizontal, ClientClay.pagePadding)
        .padding(.vertical, 24)
        .clientPage()
    }
}

private struct ClientPremiumTabBar: View {
    @Binding var selection: ClientTab
    let avatar: UIImage?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled
    @State private var switchControlEnabled = UIAccessibility.isSwitchControlRunning
    @State private var scrub = ClientTabScrubState()
    @GestureState private var isScrubbing = false

    private let tabs: [(ClientTab, String, String)] = [
        (.today, "Oggi", "sun.max.fill"),
        (.workout, "Allenamento", "dumbbell.fill"),
        (.nutrition, "Nutrizione", "leaf.fill"),
        (.progress, "Progressi", "chart.xyaxis.line"),
        (.space, "Spazio", "person.crop.circle.fill")
    ]

    var body: some View {
        Group {
            if voiceOverEnabled || switchControlEnabled {
                tabButtons
            } else {
                // Limited to the bar: a recognized hold consumes the button
                // press; an ordinary tap still uses its native Button.
                tabButtons.highPriorityGesture(scrubGesture)
            }
        }
        .padding(6)
        .background(ClientClay.color(.surfaceElevated), in: RoundedRectangle(cornerRadius: ClientRadius.card))
        .overlay {
            RoundedRectangle(cornerRadius: ClientRadius.card)
                .stroke(ClientClay.color(isScrubbing ? .brandAccent : .borderSubtle),
                        lineWidth: isScrubbing ? ClientBorder.emphasized : ClientBorder.subtle)
        }
        .padding(.horizontal, ClientSpacing.control).padding(.vertical, 6)
        .background(ClientClay.color(.backgroundPrimary))
        .onChange(of: isScrubbing) { _, active in if !active { scrub.end() } }
        .onChange(of: voiceOverEnabled) { _, _ in scrub.end() }
        .onReceive(NotificationCenter.default.publisher(for: UIAccessibility.switchControlStatusDidChangeNotification)) { _ in
            switchControlEnabled = UIAccessibility.isSwitchControlRunning
            scrub.end()
        }
    }

    private var tabButtons: some View {
        HStack(spacing: 2) {
            ForEach(tabs, id: \.0) { item in
                let tab = item.0
                let title = item.1
                let symbol = item.2
                Button {
                    select(tab)
                } label: {
                    VStack(spacing: 4) {
                        if tab == .space, let avatar {
                            Image(uiImage: avatar)
                                .resizable().scaledToFill()
                                .frame(width: 23, height: 23).clipShape(Circle())
                                .overlay { Circle().stroke(ClientClay.color(selection == tab ? .brandAccent : .borderSubtle), lineWidth: 1.5) }
                        } else {
                            Image(systemName: symbol).font(.system(size: 18, weight: .semibold))
                        }
                        Text(title).font(.caption2.weight(.semibold))
                            .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
                    }
                    .foregroundStyle(ClientClay.color(selection == tab ? .brandAccent : .textSecondary))
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .padding(.vertical, ClientSpacing.micro)
                    .background(selection == tab ? ClientClay.color(.brandAccentMuted) : .clear, in: RoundedRectangle(cornerRadius: ClientRadius.control, style: .continuous))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(title)
                .accessibilityAddTraits(selection == tab ? [.isSelected] : [])
                .accessibilityIdentifier("client-tab-\(title)")
            }
        }
    }

    private var scrubGesture: some Gesture {
        LongPressGesture(minimumDuration: 0.45, maximumDistance: 12)
            .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .local))
            .updating($isScrubbing) { value, state, _ in
                if case .second(true, _) = value { state = true }
            }
            .onChanged { value in
                guard case .second(true, .some(let drag)) = value else { return }
                if scrub.index == nil {
                    scrub.begin(index: tabs.firstIndex(where: { $0.0 == selection }) ?? 0)
                }
                if let index = scrub.update(horizontal: Double(drag.translation.width),
                                            vertical: Double(drag.translation.height), count: tabs.count) {
                    select(tabs[index].0)
                }
            }
            .onEnded { _ in scrub.end() }
    }

    private func select(_ tab: ClientTab) {
        guard selection != tab else { return }
        ClientHaptics.selection()
        withAnimation(reduceMotion ? nil : .snappy(duration: 0.22)) { selection = tab }
    }
}
