import XCTest
@testable import CurlmanNative

@MainActor
final class DraftStoreTests: XCTestCase {
    func testSavesAndRestoresRedactedDraft() throws {
        let defaults = try makeDefaults()
        let store = UserDefaultsDraftStore(defaults: defaults)
        var draft = HTTPRequestDraft.empty
        draft.urlString = "https://example.com"
        draft.authentication = Authentication(kind: .bearer, secret: "top-secret")
        draft.headers = [KeyValueItem(name: "Authorization", value: "another-secret")]

        store.save(draft)
        let restored = try XCTUnwrap(store.load())

        XCTAssertEqual(restored.urlString, "https://example.com")
        XCTAssertEqual(restored.authentication.secret, "")
        XCTAssertEqual(restored.headers.first?.value, "<stored securely>")
    }

    func testCorruptDraftIsDiscarded() throws {
        let defaults = try makeDefaults()
        defaults.set(Data("not-json".utf8), forKey: "currentRequestDraftV1")
        let store = UserDefaultsDraftStore(defaults: defaults)

        XCTAssertNil(store.load())
        XCTAssertNil(defaults.data(forKey: "currentRequestDraftV1"))
    }

    func testAppModelRestoresDraftAndHydratesKeychainSecret() throws {
        let credentialID = UUID()
        var savedDraft = HTTPRequestDraft.empty
        savedDraft.urlString = "https://example.com/restored"
        savedDraft.authentication = Authentication(kind: .bearer, credentialID: credentialID)
        let draftStore = DraftStoreStub(draft: savedDraft)
        let credentials = CredentialStoreStub(secret: "restored-secret")

        let model = AppModel(
            historyStore: try HistoryStore(inMemory: true),
            credentialStore: credentials,
            draftStore: draftStore
        )

        XCTAssertEqual(model.draft.urlString, "https://example.com/restored")
        XCTAssertEqual(model.draft.authentication.secret, "restored-secret")

        model.draft.method = .patch
        XCTAssertEqual(draftStore.draft?.method, .patch)
    }

    private func makeDefaults() throws -> UserDefaults {
        let suiteName = "DraftStoreTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}

@MainActor
private final class DraftStoreStub: DraftStoring {
    var draft: HTTPRequestDraft?

    init(draft: HTTPRequestDraft?) {
        self.draft = draft
    }

    func load() -> HTTPRequestDraft? { draft }
    func save(_ draft: HTTPRequestDraft) { self.draft = draft }
}

private final class CredentialStoreStub: CredentialStoring, @unchecked Sendable {
    let secret: String?

    init(secret: String?) {
        self.secret = secret
    }

    func save(secret: String, id: UUID) throws {}
    func load(id: UUID) throws -> String? { secret }
    func delete(id: UUID) throws {}
}
