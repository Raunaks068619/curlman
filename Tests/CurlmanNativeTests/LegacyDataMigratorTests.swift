import Foundation
import Testing
@testable import CurlmanNative

@MainActor
struct LegacyDataMigratorTests {
    @Test
    func migrationCopiesHistoryAndCredentialsOnlyOnce() throws {
        let credentialID = UUID()
        let legacyHistory = try HistoryStore(inMemory: true, configurationName: "LegacyTests")
        var request = HTTPRequestDraft.empty
        request.method = .post
        request.urlString = "https://example.com/items"
        request.authentication = Authentication(kind: .bearer, secret: "", credentialID: credentialID)
        _ = try legacyHistory.begin(request: request)

        let curlmanHistory = try HistoryStore(inMemory: true, configurationName: "CurlmanTests")
        let legacyCredentials = MemoryCredentialStore(values: [credentialID: "legacy-token"])
        let curlmanCredentials = MemoryCredentialStore()
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let migrator = LegacyDataMigrator(
            defaults: defaults,
            legacyCredentials: legacyCredentials,
            curlmanCredentials: curlmanCredentials
        )

        try migrator.migrate(records: legacyHistory.records, into: curlmanHistory)
        try migrator.migrate(records: legacyHistory.records, into: curlmanHistory)

        #expect(curlmanHistory.records.count == 1)
        #expect(curlmanHistory.records.first?.urlString == "https://example.com/items")
        #expect(try curlmanCredentials.load(id: credentialID) == "legacy-token")
        #expect(try legacyCredentials.load(id: credentialID) == "legacy-token")
    }
}

private final class MemoryCredentialStore: CredentialStoring, @unchecked Sendable {
    private var values: [UUID: String]

    init(values: [UUID: String] = [:]) {
        self.values = values
    }

    func save(secret: String, id: UUID) throws {
        values[id] = secret
    }

    func load(id: UUID) throws -> String? {
        values[id]
    }

    func delete(id: UUID) throws {
        values[id] = nil
    }
}
