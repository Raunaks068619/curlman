import Foundation

struct CurlExporter {
    private let httpClient: HTTPClient

    init(httpClient: HTTPClient = HTTPClient()) {
        self.httpClient = httpClient
    }

    func export(_ draft: HTTPRequestDraft) throws -> String {
        var requestDraft = draft
        if draft.bodyKind == .formURLEncoded || draft.bodyKind == .multipart {
            requestDraft.bodyKind = .none
        }
        let request = try httpClient.makeURLRequest(from: requestDraft)
        guard let url = request.url?.absoluteString else {
            throw HTTPClientError.invalidURL
        }
        var arguments = [
            "curl --request \(request.httpMethod ?? draft.method.rawValue)",
            "--url \(shellQuote(url))"
        ]

        let headers = (request.allHTTPHeaderFields ?? [:]).sorted {
            $0.key.localizedCaseInsensitiveCompare($1.key) == .orderedAscending
        }
        arguments.append(contentsOf: headers.map { name, value in
            "--header \(shellQuote("\(name): \(value)"))"
        })

        if draft.bodyKind == .formURLEncoded {
            arguments.append(contentsOf: draft.formItems
                .filter { $0.isEnabled && !$0.name.isEmpty }
                .map { "--data-urlencode \(shellQuote("\($0.name)=\($0.value)"))" })
        } else if draft.bodyKind == .multipart {
            arguments.append(contentsOf: draft.multipartParts
                .filter { $0.isEnabled && !$0.name.isEmpty }
                .map { part in
                    let value = part.kind == .file ? "@\(part.filePath)" : part.value
                    return "--form \(shellQuote("\(part.name)=\(value)"))"
                })
        } else if let body = request.httpBody,
           let bodyText = String(data: body, encoding: .utf8),
           !bodyText.isEmpty {
            arguments.append("--data-raw \(shellQuote(bodyText))")
        }

        return arguments.joined(separator: " \\\n  ")
    }

    private func shellQuote(_ value: String) -> String {
        "'\(value.replacingOccurrences(of: "'", with: "'\\''"))'"
    }
}
