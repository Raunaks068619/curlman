import AppKit
import Foundation

enum TopTab: String, CaseIterable, Identifiable {
    case request = "Request"
    case response = "Response"
    case history = "History"

    var id: String { rawValue }
}

enum RequestSection: String, CaseIterable, Identifiable {
    case body = "Body"
    case params = "Params"
    case headers = "Headers"
    case auth = "Auth"

    var id: String { rawValue }
}

enum ResponseSection: String, CaseIterable, Identifiable {
    case pretty = "Pretty"
    case raw = "Raw"
    case headers = "Headers"

    var id: String { rawValue }
}

@MainActor
final class AppModel: ObservableObject {
    @Published var draft = HTTPRequestDraft.empty
    @Published var selectedTab: TopTab = .request
    @Published var requestSection: RequestSection = .body
    @Published var responseSection: ResponseSection = .pretty
    @Published var response: HTTPResponseSnapshot?
    @Published var isSending = false
    @Published var isCompact = false
    @Published var curlWarnings: [String] = []
    @Published var inlineError: String?
    @Published var historySearch = ""

    let historyStore: HistoryStore
    private let httpClient: HTTPClient
    private let credentialStore: CredentialStoring
    private let curlParser = CurlParser()
    private var requestTask: Task<Void, Never>?

    init(
        historyStore: HistoryStore,
        httpClient: HTTPClient = HTTPClient(),
        credentialStore: CredentialStoring = KeychainCredentialStore()
    ) {
        self.historyStore = historyStore
        self.httpClient = httpClient
        self.credentialStore = credentialStore
    }

    var availableTabs: [TopTab] {
        response == nil ? [.request, .history] : [.request, .response, .history]
    }

    var filteredHistory: [HistoryRecord] {
        let query = historySearch.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return historyStore.records }
        return historyStore.records.filter {
            $0.displayName.localizedCaseInsensitiveContains(query) ||
            $0.urlString.localizedCaseInsensitiveContains(query) ||
            $0.method.localizedCaseInsensitiveContains(query) ||
            String($0.statusCode ?? 0).contains(query)
        }
    }

    func updateURLInput(_ value: String) {
        guard isCurlCommand(value) else {
            draft.urlString = value
            return
        }
        importCurl(value)
    }

    func importCurl(_ command: String) {
        do {
            let result = try curlParser.parse(normalizedCurlCommand(command))
            draft = result.request
            curlWarnings = result.warnings
            inlineError = nil
            response = nil
            selectedTab = .request
        } catch {
            inlineError = error.localizedDescription
        }
    }

    func isCurlCommand(_ value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.hasPrefix("curl ") ||
            trimmed.hasPrefix("/usr/bin/curl ") ||
            trimmed.hasPrefix("$ curl ") ||
            trimmed.hasPrefix("$ /usr/bin/curl ")
    }

    private func normalizedCurlCommand(_ command: String) -> String {
        let trimmed = command.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.hasPrefix("$ ") ? String(trimmed.dropFirst(2)) : trimmed
    }

    func formatRequestBody() {
        guard let object = draft.parsedJSONBody,
              let data = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys, .fragmentsAllowed]),
              let formatted = String(data: data, encoding: .utf8) else {
            inlineError = "The JSON body is invalid and could not be formatted."
            return
        }
        draft.body = formatted
        inlineError = nil
    }

    func send() {
        if isSending {
            requestTask?.cancel()
            return
        }
        guard let error = draft.validationError() else {
            inlineError = nil
            beginExecution()
            return
        }
        inlineError = error
    }

    func newRequest() {
        requestTask?.cancel()
        draft = .empty
        response = nil
        curlWarnings = []
        inlineError = nil
        selectedTab = .request
        requestSection = .body
    }

    func showHistory() {
        selectedTab = .history
    }

    func restore(_ record: HistoryRecord) {
        guard var restored = record.request else { return }
        if let credentialID = restored.authentication.credentialID,
           let secret = try? credentialStore.load(id: credentialID) {
            restored.authentication.secret = secret
        }
        draft = restored
        response = record.response
        inlineError = nil
        curlWarnings = []
        selectedTab = .request
    }

    func openStoredResponse(_ record: HistoryRecord) {
        restore(record)
        if response != nil { selectedTab = .response }
    }

    func togglePin(_ record: HistoryRecord) {
        do { try historyStore.togglePin(record) }
        catch { inlineError = error.localizedDescription }
    }

    func deleteHistory(_ record: HistoryRecord) {
        do { try historyStore.delete(record) }
        catch { inlineError = error.localizedDescription }
    }

    func clearHistory() {
        do { try historyStore.clear() }
        catch { inlineError = error.localizedDescription }
    }

    private func beginExecution() {
        var executionDraft = draft
        do {
            if executionDraft.authentication.kind != .none,
               !executionDraft.authentication.secret.isEmpty {
                let credentialID = executionDraft.authentication.credentialID ?? UUID()
                try credentialStore.save(secret: executionDraft.authentication.secret, id: credentialID)
                executionDraft.authentication.credentialID = credentialID
                draft.authentication.credentialID = credentialID
            }
            let historyID = try historyStore.begin(request: executionDraft)
            isSending = true
            requestTask = Task { [weak self] in
                guard let self else { return }
                do {
                    let result = try await httpClient.execute(executionDraft)
                    try historyStore.finalize(id: historyID, response: result)
                    response = result
                } catch {
                    let cancelled = error is CancellationError || (error as? URLError)?.code == .cancelled
                    try? historyStore.finalizeFailure(id: historyID, error: error, cancelled: cancelled)
                    response = HTTPResponseSnapshot(
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
                }
                isSending = false
                selectedTab = .response
            }
        } catch {
            inlineError = error.localizedDescription
        }
    }
}
