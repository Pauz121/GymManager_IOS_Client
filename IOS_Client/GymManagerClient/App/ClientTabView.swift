import SwiftUI
import UIKit

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
                .tag(ClientTab.today)
            NavigationStack { ClientWorkoutView(snapshot: snapshot, identity: identity) }
                .tag(ClientTab.workout)
            NavigationStack { ClientNutritionView(plan: snapshot.nutrition, identity: identity) }
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

private struct ClientPremiumTabBar: View {
    @Binding var selection: ClientTab
    let avatar: UIImage?

    private let tabs: [(ClientTab, String, String)] = [
        (.today, "Oggi", "sun.max.fill"),
        (.workout, "Allenamento", "dumbbell.fill"),
        (.nutrition, "Nutrizione", "leaf.fill"),
        (.progress, "Progressi", "chart.xyaxis.line"),
        (.space, "Spazio", "person.crop.circle.fill")
    ]

    var body: some View {
        HStack(spacing: 2) {
            ForEach(tabs, id: \.0) { item in
                let tab = item.0
                let title = item.1
                let symbol = item.2
                Button {
                    ClientHaptics.selection()
                    withAnimation(.snappy(duration: 0.22)) { selection = tab }
                } label: {
                    VStack(spacing: 4) {
                        if tab == .space, let avatar {
                            Image(uiImage: avatar)
                                .resizable().scaledToFill()
                                .frame(width: 23, height: 23).clipShape(Circle())
                                .overlay { Circle().stroke(selection == tab ? ClientClay.accent : ClientClay.border, lineWidth: 1.5) }
                        } else {
                            Image(systemName: symbol).font(.system(size: 18, weight: .semibold))
                        }
                        Text(title).font(.caption2.weight(.semibold)).lineLimit(1).minimumScaleFactor(0.72)
                    }
                    .foregroundStyle(selection == tab ? ClientClay.accent : ClientClay.secondaryInk)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(selection == tab ? ClientClay.accent.opacity(0.11) : .clear, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(title)
                .accessibilityAddTraits(selection == tab ? [.isSelected] : [])
            }
        }
        .padding(6)
        .background(ClientClay.surfaceElevated, in: RoundedRectangle(cornerRadius: 23, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 23, style: .continuous).stroke(ClientClay.border) }
        .shadow(color: .black.opacity(0.44), radius: 18, y: 8)
        .padding(.horizontal, 12).padding(.vertical, 6)
        .background(ClientClay.canvas.opacity(0.96))
    }
}
