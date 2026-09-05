import Foundation

@MainActor
protocol DraftStoring: AnyObject {
    func load() -> HTTPRequestDraft?
    func save(_ draft: HTTPRequestDraft)
}

@MainActor
final class UserDefaultsDraftStore: DraftStoring {
    private static let storageKey = "currentRequestDraftV1"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> HTTPRequestDraft? {
        guard let data = defaults.data(forKey: Self.storageKey) else { return nil }
        guard let draft = try? JSONDecoder().decode(HTTPRequestDraft.self, from: data) else {
            defaults.removeObject(forKey: Self.storageKey)
            return nil
        }
        return draft
    }

    func save(_ draft: HTTPRequestDraft) {
        guard let data = try? JSONEncoder().encode(draft.sanitizedForPersistence) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }
}

@MainActor
final class TransientDraftStore: DraftStoring {
    func load() -> HTTPRequestDraft? { nil }
    func save(_ draft: HTTPRequestDraft) {}
}
