import Foundation

enum HTTPMethod: String, Codable, CaseIterable, Identifiable, Sendable {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case patch = "PATCH"
    case delete = "DELETE"
    case head = "HEAD"
    case options = "OPTIONS"

    var id: String { rawValue }
}

struct KeyValueItem: Identifiable, Codable, Hashable, Sendable {
    var id = UUID()
    var isEnabled = true
    var name = ""
    var value = ""
}

enum RequestBodyKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case json = "JSON"
    case raw = "Raw"
    case none = "None"

    var id: String { rawValue }
}

enum AuthenticationKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case none = "None"
    case bearer = "Bearer"
    case basic = "Basic"

    var id: String { rawValue }
}

struct Authentication: Codable, Hashable, Sendable {
    var kind: AuthenticationKind = .none
    var username = ""
    var secret = ""
    var credentialID: UUID?

    var sanitized: Authentication {
        var copy = self
        copy.secret = ""
        return copy
    }
}

struct HTTPRequestDraft: Identifiable, Codable, Hashable, Sendable {
    var id = UUID()
    var name = ""
    var method: HTTPMethod = .get
    var urlString = ""
    var queryItems: [KeyValueItem] = []
    var headers: [KeyValueItem] = []
    var bodyKind: RequestBodyKind = .json
    var body = ""
    var authentication = Authentication()

    static var empty: HTTPRequestDraft {
        HTTPRequestDraft(
            queryItems: [KeyValueItem()],
            headers: [KeyValueItem()]
        )
    }

    var sanitizedForPersistence: HTTPRequestDraft {
        var copy = self
        copy.authentication = authentication.sanitized
        copy.headers = headers.map { header in
            guard header.name.caseInsensitiveCompare("Authorization") == .orderedSame else {
                return header
            }
            var redacted = header
            redacted.value = "<stored securely>"
            return redacted
        }
        return copy
    }

    func validationError() -> String? {
        let trimmedURL = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedURL.isEmpty else { return "Enter a URL or paste a curl request." }
        guard let components = URLComponents(string: trimmedURL),
              let scheme = components.scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              components.host != nil else {
            return "Use a complete HTTP or HTTPS URL."
        }

        if bodyKind == .json, !body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            guard parsedJSONBody != nil else {
                return "The JSON body is invalid. Format or correct it before sending."
            }
        }
        return nil
    }

    var parsedJSONBody: Any? {
        guard let data = body.data(using: .utf8), !data.isEmpty else { return nil }
        return try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
    }
}

struct HTTPResponseSnapshot: Identifiable, Codable, Hashable, Sendable {
    var id = UUID()
    var statusCode: Int?
    var reasonPhrase: String
    var headers: [String: String]
    var body: Data
    var mimeType: String?
    var duration: TimeInterval
    var receivedByteCount: Int
    var errorDescription: String?
    var wasCancelled = false

    var isTransportFailure: Bool { statusCode == nil }

    var statusLabel: String {
        if wasCancelled { return "Cancelled" }
        if let errorDescription { return errorDescription }
        guard let statusCode else { return "No response" }
        return reasonPhrase.isEmpty ? "\(statusCode)" : "\(statusCode) \(reasonPhrase)"
    }

    var bodyText: String {
        String(data: body, encoding: .utf8) ?? "Binary response (\(body.count) bytes)"
    }

    var prettyBodyText: String {
        guard let object = try? JSONSerialization.jsonObject(with: body),
              let pretty = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys]),
              let text = String(data: pretty, encoding: .utf8) else {
            return bodyText
        }
        return text
    }
}
