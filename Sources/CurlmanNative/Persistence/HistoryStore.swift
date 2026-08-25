import Foundation
import SwiftData

enum HistoryOutcome: String, Codable, CaseIterable, Sendable {
    case pending
    case success
    case httpError
    case transportFailure
    case cancelled
}

@Model
final class HistoryRecord {
    @Attribute(.unique) var id: UUID
    var startedAt: Date
    var completedAt: Date?
    var displayName: String
    var method: String
    var urlString: String
    var requestData: Data
    var responseData: Data?
    var outcomeRawValue: String
    var statusCode: Int?
    var duration: Double
    var responseSize: Int
    var bodyTruncated: Bool
    var errorMessage: String?
    var isPinned: Bool

    init(id: UUID = UUID(), request: HTTPRequestDraft) throws {
        self.id = id
        self.startedAt = Date()
        self.completedAt = nil
        self.displayName = request.name
        self.method = request.method.rawValue
        self.urlString = request.urlString
        self.requestData = try JSONEncoder().encode(request.sanitizedForPersistence)
        self.responseData = nil
        self.outcomeRawValue = HistoryOutcome.pending.rawValue
        self.statusCode = nil
        self.duration = 0
        self.responseSize = 0
        self.bodyTruncated = false
        self.errorMessage = nil
        self.isPinned = false
    }

    init(copying record: HistoryRecord) {
        self.id = record.id
        self.startedAt = record.startedAt
        self.completedAt = record.completedAt
        self.displayName = record.displayName
        self.method = record.method
        self.urlString = record.urlString
        self.requestData = record.requestData
        self.responseData = record.responseData
        self.outcomeRawValue = record.outcomeRawValue
        self.statusCode = record.statusCode
        self.duration = record.duration
        self.responseSize = record.responseSize
        self.bodyTruncated = record.bodyTruncated
        self.errorMessage = record.errorMessage
        self.isPinned = record.isPinned
    }

    var outcome: HistoryOutcome {
        get { HistoryOutcome(rawValue: outcomeRawValue) ?? .transportFailure }
        set { outcomeRawValue = newValue.rawValue }
    }

    var request: HTTPRequestDraft? {
        try? JSONDecoder().decode(HTTPRequestDraft.self, from: requestData)
    }

    var response: HTTPResponseSnapshot? {
        guard let responseData else { return nil }
        return try? JSONDecoder().decode(HTTPResponseSnapshot.self, from: responseData)
    }
}

@MainActor
final class HistoryStore: ObservableObject {
    @Published private(set) var records: [HistoryRecord] = []

    let container: ModelContainer
    private let context: ModelContext
    private let responseBodyLimit: Int

    init(
        inMemory: Bool = false,
        responseBodyLimit: Int = 2 * 1_024 * 1_024,
        configurationName: String = "Curlman"
    ) throws {
        let schema = Schema([HistoryRecord.self])
        let configuration = ModelConfiguration(configurationName, schema: schema, isStoredInMemoryOnly: inMemory)
        self.container = try ModelContainer(for: schema, configurations: [configuration])
        self.context = ModelContext(container)
        self.responseBodyLimit = responseBodyLimit
        try reload()
    }

    @discardableResult
    func begin(request: HTTPRequestDraft) throws -> UUID {
        let record = try HistoryRecord(request: request)
        context.insert(record)
        try context.save()
        try reload()
        return record.id
    }

    func finalize(id: UUID, response: HTTPResponseSnapshot) throws {
        guard let record = record(with: id) else { return }
        var storedResponse = response
        if storedResponse.body.count > responseBodyLimit {
            storedResponse.body = Data(storedResponse.body.prefix(responseBodyLimit))
            record.bodyTruncated = true
        }
        record.completedAt = Date()
        record.statusCode = response.statusCode
        record.duration = response.duration
        record.responseSize = response.receivedByteCount
        record.errorMessage = response.errorDescription
        if response.wasCancelled {
            record.outcome = .cancelled
        } else if response.isTransportFailure {
            record.outcome = .transportFailure
        } else if let statusCode = response.statusCode, statusCode >= 400 {
            record.outcome = .httpError
        } else {
            record.outcome = .success
        }
        record.responseData = try JSONEncoder().encode(storedResponse)
        try context.save()
        try reload()
    }

    func finalizeFailure(id: UUID, error: Error, cancelled: Bool) throws {
        let response = HTTPResponseSnapshot(
            statusCode: nil,
            reasonPhrase: "",
            headers: [:],
            body: Data(),
            mimeType: nil,
            duration: 0,
            receivedByteCount: 0,
            errorDescription: cancelled ? "Request cancelled" : error.localizedDescription,
            wasCancelled: cancelled
        )
        try finalize(id: id, response: response)
    }

    func togglePin(_ record: HistoryRecord) throws {
        record.isPinned.toggle()
        try context.save()
        try reload()
    }

    func rename(_ record: HistoryRecord, to name: String) throws {
        record.displayName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        try context.save()
        try reload()
    }

    func delete(_ record: HistoryRecord) throws {
        context.delete(record)
        try context.save()
        try reload()
    }

    func clear() throws {
        try context.delete(model: HistoryRecord.self)
        try context.save()
        try reload()
    }

    func importLegacyRecords(_ legacyRecords: [HistoryRecord]) throws {
        let existingIDs = Set(records.map(\.id))
        for record in legacyRecords where !existingIDs.contains(record.id) {
            context.insert(HistoryRecord(copying: record))
        }
        try context.save()
        try reload()
    }

    func reload() throws {
        records = try context.fetch(FetchDescriptor<HistoryRecord>()).sorted {
            if $0.isPinned != $1.isPinned { return $0.isPinned && !$1.isPinned }
            return $0.startedAt > $1.startedAt
        }
    }

    private func record(with id: UUID) -> HistoryRecord? {
        records.first { $0.id == id }
    }
}
