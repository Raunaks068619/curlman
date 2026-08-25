import Foundation

struct CurlExporter {
    private let httpClient: HTTPClient

    init(httpClient: HTTPClient = HTTPClient()) {
        self.httpClient = httpClient
    }

    func export(_ draft: HTTPRequestDraft) throws -> String {
        let request = try httpClient.makeURLRequest(from: draft)
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

        if let body = request.httpBody,
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
