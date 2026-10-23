import SwiftUI

struct ClientContentFailureCard: View {
    let title: String
    let message: String
    var isRefreshing = false
    let retry: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: "exclamationmark.triangle.fill")
                .font(.subheadline.weight(.semibold)).foregroundStyle(ClientClay.warning)
            Text(message).font(.footnote).foregroundStyle(ClientClay.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)
            Button(isRefreshing ? "Aggiornamento…" : "Riprova", action: retry)
                .font(.subheadline.weight(.semibold)).foregroundStyle(ClientClay.accent)
                .frame(minHeight: 44).disabled(isRefreshing)
        }
        .clayCard(padding: 14)
    }
}

struct ClientContentGate<Content: View>: View {
    let section: ClientContentSection
    let state: ClientContentLoadState
    var isRefreshing = false
    let retry: () -> Void
    private let content: () -> Content

    init(section: ClientContentSection, state: ClientContentLoadState, isRefreshing: Bool = false,
         retry: @escaping () -> Void, @ViewBuilder content: @escaping () -> Content) {
        self.section = section
        self.state = state
        self.isRefreshing = isRefreshing
        self.retry = retry
        self.content = content
    }

    var body: some View {
        switch state {
        case .idle, .loading:
            ProgressView("Caricamento \(section.title.lowercased())…")
                .frame(maxWidth: .infinity, alignment: .leading).clayCard(padding: 14)
        case .failed(let message):
            ClientContentFailureCard(title: section.title, message: message, isRefreshing: isRefreshing, retry: retry)
        case .loaded, .empty:
            content()
        }
    }
}
