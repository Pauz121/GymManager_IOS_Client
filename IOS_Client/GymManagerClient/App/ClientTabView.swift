import SwiftUI

enum ClientTab: Hashable { case today, workout, nutrition, progress, space }

struct ClientTabView: View {
    let identity: ClientIdentity
    let snapshot: ClientSnapshot
    let source: ClientDataSource
    @State private var selectedTab: ClientTab = .today
    @EnvironmentObject private var avatarStore: ClientAvatarStore

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack { ClientHomeView(identity: identity, snapshot: snapshot, source: source, selectedTab: $selectedTab) }
                .tabItem { Label("Oggi", systemImage: "sun.max.fill") }.tag(ClientTab.today)
            NavigationStack { ClientWorkoutView(snapshot: snapshot, identity: identity) }
                .tabItem { Label("Scheda", systemImage: "dumbbell.fill") }.tag(ClientTab.workout)
            NavigationStack { ClientNutritionView(plan: snapshot.nutrition, identity: identity) }
                .tabItem { Label("Nutrizione", systemImage: "leaf.fill") }.tag(ClientTab.nutrition)
            NavigationStack { ClientProgressView(entries: snapshot.progress, identity: identity, source: source) }
                .tabItem { Label("Progressi", systemImage: "chart.xyaxis.line") }.tag(ClientTab.progress)
            NavigationStack { PersonalSpaceView(identity: identity, snapshot: snapshot, source: source) }
                .tabItem {
                    if let avatar = avatarStore.image(for: identity.authUserID) {
                        Label { Text("Spazio") } icon: { Image(uiImage: avatar).renderingMode(.original) }
                    } else {
                        Label("Spazio", systemImage: "person.crop.circle.fill")
                    }
                }
                .tag(ClientTab.space)
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            if source == .demo {
                Text("DEMO · nessun dato reale")
                    .font(.caption2.weight(.bold)).tracking(0.8)
                    .foregroundStyle(.white).padding(.horizontal, 12).padding(.vertical, 6)
                    .background(ClientClay.warning, in: Capsule()).padding(.vertical, 5)
                    .accessibilityLabel("Modalità demo, nessun dato reale")
                    .allowsHitTesting(false)
            }
        }
        .task(id: identity.authUserID) { avatarStore.load(userID: identity.authUserID) }
    }
}
