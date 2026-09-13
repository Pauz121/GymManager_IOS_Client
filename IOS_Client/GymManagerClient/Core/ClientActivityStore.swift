import Foundation

struct ClientActivityStore {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    static func storageKey(userID: UUID, source: ClientDataSource) -> String {
        "gymmanager.client.activity.\(source.rawValue).\(userID.uuidString.lowercased())"
    }

    func load(userID: UUID, source: ClientDataSource) -> ClientActivityState {
        guard let data = defaults.data(forKey: Self.storageKey(userID: userID, source: source)),
              let state = try? JSONDecoder().decode(ClientActivityState.self, from: data) else {
            return .empty
        }
        return state
    }

    func save(_ state: ClientActivityState, userID: UUID, source: ClientDataSource) throws {
        let data = try JSONEncoder().encode(state)
        defaults.set(data, forKey: Self.storageKey(userID: userID, source: source))
    }
}
