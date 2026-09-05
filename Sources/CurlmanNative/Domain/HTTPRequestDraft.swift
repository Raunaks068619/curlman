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
    case formURLEncoded = "Form URL Encoded"
    case multipart = "Multipart"
    case none = "None"

    var id: String { rawValue }
}

enum AuthenticationKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case none = "None"
    case bearer = "Bearer"
    case basic = "Basic"
    case apiKey = "API Key"

    var id: String { rawValue }
}

enum APIKeyPlacement: String, Codable, CaseIterable, Identifiable, Sendable {
    case header = "Header"
    case query = "Query"

    var id: String { rawValue }
}

enum RedirectPolicy: String, Codable, CaseIterable, Identifiable, Sendable {
    case follow = "Follow redirects"
    case never = "Do not follow"

    var id: String { rawValue }
}

enum CookiePolicy: String, Codable, CaseIterable, Identifiable, Sendable {
    case disabled = "Disabled"
    case isolated = "This request only"
    case persistent = "Persistent session"

    var id: String { rawValue }
}

enum MultipartPartKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case text = "Text"
    case file = "File"

    var id: String { rawValue }
}

struct MultipartPart: Identifiable, Codable, Hashable, Sendable {
    var id = UUID()
    var isEnabled = true
    var name = ""
    var kind: MultipartPartKind = .text
    var value = ""
    var filePath = ""
    var mimeType = "application/octet-stream"
    var isFileAccessApproved = false
}

struct Authentication: Codable, Hashable, Sendable {
    var kind: AuthenticationKind = .none
    var username = ""
    var secret = ""
    var credentialID: UUID?
    var apiKeyName = "X-API-Key"
    var apiKeyPlacement: APIKeyPlacement = .header

    var sanitized: Authentication {
        var copy = self
        copy.secret = ""
        return copy
    }
}

extension Authentication {
    private enum CodingKeys: String, CodingKey {
        case kind, username, secret, credentialID, apiKeyName, apiKeyPlacement
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        kind = try container.decodeIfPresent(AuthenticationKind.self, forKey: .kind) ?? .none
        username = try container.decodeIfPresent(String.self, forKey: .username) ?? ""
        secret = try container.decodeIfPresent(String.self, forKey: .secret) ?? ""
        credentialID = try container.decodeIfPresent(UUID.self, forKey: .credentialID)
        apiKeyName = try container.decodeIfPresent(String.self, forKey: .apiKeyName) ?? "X-API-Key"
        apiKeyPlacement = try container.decodeIfPresent(APIKeyPlacement.self, forKey: .apiKeyPlacement) ?? .header
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
    var formItems: [KeyValueItem] = []
    var multipartParts: [MultipartPart] = []
    var authentication = Authentication()
    var timeoutInterval: TimeInterval = 60
    var redirectPolicy: RedirectPolicy = .follow
    var cookiePolicy: CookiePolicy = .disabled

    static var empty: HTTPRequestDraft {
        HTTPRequestDraft(
            queryItems: [KeyValueItem()],
            headers: [KeyValueItem()]
        )
    }

    var sanitizedForPersistence: HTTPRequestDraft {
        var copy = self
        copy.authentication = authentication.sanitized
        copy.multipartParts = multipartParts.map { part in
            var redacted = part
            redacted.isFileAccessApproved = false
            return redacted
        }
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
        guard timeoutInterval >= 1, timeoutInterval <= 600 else {
            return "Use a request timeout between 1 and 600 seconds."
        }
        if authentication.kind == .apiKey,
           authentication.apiKeyName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Enter a name for the API key."
        }
        if bodyKind == .multipart,
           multipartParts.contains(where: { $0.isEnabled && $0.kind == .file && !$0.isFileAccessApproved }) {
            return "Approve each multipart file before sending it."
        }
        return nil
    }

    var parsedJSONBody: Any? {
        guard let data = body.data(using: .utf8), !data.isEmpty else { return nil }
        return try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
    }
}

extension HTTPRequestDraft {
    private enum CodingKeys: String, CodingKey {
        case id, name, method, urlString, queryItems, headers, bodyKind, body
        case formItems, multipartParts, authentication, timeoutInterval, redirectPolicy, cookiePolicy
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        method = try container.decodeIfPresent(HTTPMethod.self, forKey: .method) ?? .get
        urlString = try container.decodeIfPresent(String.self, forKey: .urlString) ?? ""
        queryItems = try container.decodeIfPresent([KeyValueItem].self, forKey: .queryItems) ?? []
        headers = try container.decodeIfPresent([KeyValueItem].self, forKey: .headers) ?? []
        bodyKind = try container.decodeIfPresent(RequestBodyKind.self, forKey: .bodyKind) ?? .none
        body = try container.decodeIfPresent(String.self, forKey: .body) ?? ""
        formItems = try container.decodeIfPresent([KeyValueItem].self, forKey: .formItems) ?? []
        multipartParts = try container.decodeIfPresent([MultipartPart].self, forKey: .multipartParts) ?? []
        authentication = try container.decodeIfPresent(Authentication.self, forKey: .authentication) ?? Authentication()
        timeoutInterval = try container.decodeIfPresent(TimeInterval.self, forKey: .timeoutInterval) ?? 60
        redirectPolicy = try container.decodeIfPresent(RedirectPolicy.self, forKey: .redirectPolicy) ?? .follow
        cookiePolicy = try container.decodeIfPresent(CookiePolicy.self, forKey: .cookiePolicy) ?? .disabled
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
