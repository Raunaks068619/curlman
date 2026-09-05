import Foundation

enum HTTPClientError: LocalizedError, Equatable {
    case invalidURL
    case invalidComponents
    case fileAccessNotApproved(String)
    case unreadableFile(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "The URL is invalid."
        case .invalidComponents: return "The request URL could not be assembled."
        case .fileAccessNotApproved(let name): return "Approve access to the file for multipart field \(name)."
        case .unreadableFile(let path): return "The multipart file could not be read: \(path)"
        }
    }
}

final class HTTPClient: @unchecked Sendable {
    private let injectedSession: URLSession?

    init(session: URLSession? = nil) {
        injectedSession = session
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
        request.timeoutInterval = min(max(draft.timeoutInterval, 1), 600)
        request.httpShouldHandleCookies = draft.cookiePolicy != .disabled

        for header in draft.headers where header.isEnabled && !header.name.isEmpty {
            request.setValue(header.value, forHTTPHeaderField: header.name)
        }

        if draft.bodyKind == .formURLEncoded {
            let encoded = draft.formItems
                .filter { $0.isEnabled && !$0.name.isEmpty }
                .map { "\(formEncode($0.name))=\(formEncode($0.value))" }
                .joined(separator: "&")
            request.httpBody = encoded.data(using: .utf8)
            if request.value(forHTTPHeaderField: "Content-Type") == nil {
                request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            }
        } else if draft.bodyKind == .multipart {
            let boundary = "Curlman-\(UUID().uuidString)"
            request.httpBody = try multipartBody(parts: draft.multipartParts, boundary: boundary)
            if request.value(forHTTPHeaderField: "Content-Type") == nil {
                request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
            }
        } else if draft.bodyKind != .none, !draft.body.isEmpty {
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
        case .apiKey:
            guard !draft.authentication.secret.isEmpty else { break }
            switch draft.authentication.apiKeyPlacement {
            case .header:
                request.setValue(draft.authentication.secret, forHTTPHeaderField: draft.authentication.apiKeyName)
            case .query:
                guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
                    throw HTTPClientError.invalidComponents
                }
                var items = components.queryItems ?? []
                items.append(URLQueryItem(name: draft.authentication.apiKeyName, value: draft.authentication.secret))
                components.queryItems = items
                guard let authenticatedURL = components.url else { throw HTTPClientError.invalidComponents }
                request.url = authenticatedURL
            }
        }
        return request
    }

    private func formEncode(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-._* "))
        return (value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value)
            .replacingOccurrences(of: " ", with: "+")
    }

    private func multipartBody(parts: [MultipartPart], boundary: String) throws -> Data {
        var data = Data()
        for part in parts where part.isEnabled && !part.name.isEmpty {
            data.append("--\(boundary)\r\n".data(using: .utf8)!)
            switch part.kind {
            case .text:
                data.append("Content-Disposition: form-data; name=\"\(part.name)\"\r\n\r\n".data(using: .utf8)!)
                data.append(part.value.data(using: .utf8) ?? Data())
            case .file:
                guard part.isFileAccessApproved else {
                    throw HTTPClientError.fileAccessNotApproved(part.name)
                }
                let fileURL = URL(fileURLWithPath: part.filePath)
                guard let fileData = try? Data(contentsOf: fileURL, options: .mappedIfSafe) else {
                    throw HTTPClientError.unreadableFile(part.filePath)
                }
                let filename = fileURL.lastPathComponent.replacingOccurrences(of: "\"", with: "")
                data.append("Content-Disposition: form-data; name=\"\(part.name)\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
                data.append("Content-Type: \(part.mimeType)\r\n\r\n".data(using: .utf8)!)
                data.append(fileData)
            }
            data.append("\r\n".data(using: .utf8)!)
        }
        data.append("--\(boundary)--\r\n".data(using: .utf8)!)
        return data
    }

    func execute(_ draft: HTTPRequestDraft) async throws -> HTTPResponseSnapshot {
        let request = try makeURLRequest(from: draft)
        let startedAt = Date()
        let session = injectedSession ?? makeSession(for: draft)
        let redirectDelegate = RedirectDelegate(policy: draft.redirectPolicy)
        let (data, response) = try await session.data(for: request, delegate: redirectDelegate)
        if injectedSession == nil { session.finishTasksAndInvalidate() }
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

    private func makeSession(for draft: HTTPRequestDraft) -> URLSession {
        let configuration: URLSessionConfiguration = draft.cookiePolicy == .persistent ? .default : .ephemeral
        configuration.timeoutIntervalForRequest = min(max(draft.timeoutInterval, 1), 600)
        configuration.timeoutIntervalForResource = min(max(draft.timeoutInterval * 2, 2), 1_200)
        configuration.waitsForConnectivity = false
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        if draft.cookiePolicy == .disabled {
            configuration.httpShouldSetCookies = false
            configuration.httpCookieAcceptPolicy = .never
            configuration.httpCookieStorage = nil
        }
        return URLSession(configuration: configuration)
    }
}

private final class RedirectDelegate: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    let policy: RedirectPolicy

    init(policy: RedirectPolicy) {
        self.policy = policy
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        completionHandler(policy == .follow ? request : nil)
    }
}
