import Foundation

@MainActor
final class PersonalAgendaStore {
    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    nonisolated static func storageKey(userID: UUID, source: ClientDataSource) -> String {
        "gymmanager.client.agenda.\(source.rawValue).\(userID.uuidString.lowercased())"
    }

    func load(userID: UUID, source: ClientDataSource) -> [PersonalAgendaTask] {
        guard let data = defaults.data(forKey: Self.storageKey(userID: userID, source: source)),
              let tasks = try? decoder.decode([PersonalAgendaTask].self, from: data) else { return [] }
        return tasks
    }

    func save(_ tasks: [PersonalAgendaTask], userID: UUID, source: ClientDataSource) throws {
        let data = try encoder.encode(tasks)
        defaults.set(data, forKey: Self.storageKey(userID: userID, source: source))
    }

    nonisolated static func validatedTitle(_ title: String) throws -> String {
        let clean = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty, clean.count <= 160 else {
            throw ClientAppError.message("Inserisci un titolo tra 1 e 160 caratteri.")
        }
        return clean
    }
}
