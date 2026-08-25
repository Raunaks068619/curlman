import Foundation

@MainActor
final class LegacyDataMigrator {
    private static let migrationMarker = "didMigrateAPIPanelDataToCurlmanV1"

    private let defaults: UserDefaults
    private let fileManager: FileManager
    private let legacyCredentials: CredentialStoring
    private let curlmanCredentials: CredentialStoring

    init(
        defaults: UserDefaults = .standard,
        fileManager: FileManager = .default,
        legacyCredentials: CredentialStoring = KeychainCredentialStore(service: KeychainCredentialStore.legacyService),
        curlmanCredentials: CredentialStoring = KeychainCredentialStore()
    ) {
        self.defaults = defaults
        self.fileManager = fileManager
        self.legacyCredentials = legacyCredentials
        self.curlmanCredentials = curlmanCredentials
    }

    func migrateIfNeeded(into curlmanHistory: HistoryStore) throws {
        guard !defaults.bool(forKey: Self.migrationMarker) else { return }
        guard legacyStoreExists else {
            defaults.set(true, forKey: Self.migrationMarker)
            return
        }

        let legacyHistory = try HistoryStore(configurationName: "APIPanel")
        try migrate(records: legacyHistory.records, into: curlmanHistory)
        defaults.set(true, forKey: Self.migrationMarker)
    }

    func migrate(records: [HistoryRecord], into curlmanHistory: HistoryStore) throws {
        try curlmanHistory.importLegacyRecords(records)
        try migrateCredentials(referencedBy: records)
    }

    private var legacyStoreExists: Bool {
        guard let directory = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return false
        }
        return fileManager.fileExists(atPath: directory.appending(path: "APIPanel.store").path)
    }

    private func migrateCredentials(referencedBy records: [HistoryRecord]) throws {
        let identifiers = Set(records.compactMap { $0.request?.authentication.credentialID })
        for identifier in identifiers {
            guard try curlmanCredentials.load(id: identifier) == nil,
                  let secret = try legacyCredentials.load(id: identifier) else {
                continue
            }
            try curlmanCredentials.save(secret: secret, id: identifier)
        }
    }
}
