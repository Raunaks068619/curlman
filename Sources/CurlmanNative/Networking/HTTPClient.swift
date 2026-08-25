import Foundation

enum HTTPClientError: LocalizedError, Equatable {
    case invalidURL
    case invalidComponents

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "The URL is invalid."
        case .invalidComponents: return "The request URL could not be assembled."
        }
    }
}

final class HTTPClient: @unchecked Sendable {
    private let session: URLSession

    init(session: URLSession? = nil) {
        if let session {
            self.session = session
        } else {
            let configuration = URLSessionConfiguration.default
            configuration.timeoutIntervalForRequest = 60
            configuration.timeoutIntervalForResource = 120
            configuration.waitsForConnectivity = false
            configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
            self.session = URLSession(configuration: configuration)
        }
    }

    func makeURLRequest(from draft: HTTPRequestDraft) throws -> URLRequest {
        guard var components = URLComponents(string: draft.urlString) else {
            throw HTTPClientError.invalidURL
        }

        var queryItems = components.queryItems ?? []
        queryItems.append(contentsOf: draft.queryItems
            .filter { $0.isEnabled && !$0.name.isEmpty }
            .map { URLQueryItem(name: $0.name, value: $0.value) })
        components.queryItems = queryItems.isEmpty ? nil : queryItems

        guard let url = components.url else { throw HTTPClientError.invalidComponents }
        var request = URLRequest(url: url)
        request.httpMethod = draft.method.rawValue
        request.timeoutInterval = 60

        for header in draft.headers where header.isEnabled && !header.name.isEmpty {
            request.setValue(header.value, forHTTPHeaderField: header.name)
        }

        if draft.bodyKind != .none, !draft.body.isEmpty {
            request.httpBody = draft.body.data(using: .utf8)
            if draft.bodyKind == .json,
               request.value(forHTTPHeaderField: "Content-Type") == nil {
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            }
        }

        switch draft.authentication.kind {
        case .none:
            break
        case .bearer:
            if !draft.authentication.secret.isEmpty {
                request.setValue("Bearer \(draft.authentication.secret)", forHTTPHeaderField: "Authorization")
            }
        case .basic:
            let value = "\(draft.authentication.username):\(draft.authentication.secret)"
            if let data = value.data(using: .utf8) {
                request.setValue("Basic \(data.base64EncodedString())", forHTTPHeaderField: "Authorization")
            }
        }
        return request
    }

    func execute(_ draft: HTTPRequestDraft) async throws -> HTTPResponseSnapshot {
        let request = try makeURLRequest(from: draft)
        let startedAt = Date()
        let (data, response) = try await session.data(for: request)
        let duration = Date().timeIntervalSince(startedAt)
        guard let httpResponse = response as? HTTPURLResponse else {
            return HTTPResponseSnapshot(
                statusCode: nil,
                reasonPhrase: "",
                headers: [:],
                body: data,
                mimeType: response.mimeType,
                duration: duration,
                receivedByteCount: data.count,
                errorDescription: "The server returned a non-HTTP response."
            )
        }

        let headers = httpResponse.allHeaderFields.reduce(into: [String: String]()) { result, item in
            result[String(describing: item.key)] = String(describing: item.value)
        }
        return HTTPResponseSnapshot(
            statusCode: httpResponse.statusCode,
            reasonPhrase: HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode).capitalized,
            headers: headers,
            body: data,
            mimeType: response.mimeType,
            duration: duration,
            receivedByteCount: data.count,
            errorDescription: nil
        )
    }
}

