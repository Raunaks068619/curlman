import Foundation

struct CurlImportResult: Sendable {
    var request: HTTPRequestDraft
    var warnings: [String]
}

enum CurlImportError: LocalizedError, Equatable {
    case notCurl
    case unterminatedQuote
    case missingValue(String)
    case missingURL

    var errorDescription: String? {
        switch self {
        case .notCurl:
            return "The pasted text is not a curl command."
        case .unterminatedQuote:
            return "The curl command contains an unterminated quote."
        case .missingValue(let option):
            return "The curl option \(option) is missing its value."
        case .missingURL:
            return "The curl command does not contain a URL."
        }
    }
}

struct CurlParser: Sendable {
    func parse(_ command: String) throws -> CurlImportResult {
        let tokens = try tokenize(command)
        guard let first = tokens.first,
              first == "curl" || first.hasSuffix("/curl") else {
            throw CurlImportError.notCurl
        }

        var request = HTTPRequestDraft.empty
        request.queryItems = []
        request.headers = []
        request.bodyKind = .none
        var warnings: [String] = []
        var explicitMethod: HTTPMethod?
        var inferredPost = false
        var forceGet = false
        var index = 1

        func value(after option: String) throws -> String {
            guard index + 1 < tokens.count else { throw CurlImportError.missingValue(option) }
            index += 1
            return tokens[index]
        }

        while index < tokens.count {
            let token = tokens[index]

            if token == "-X" || token == "--request" {
                let raw = try value(after: token).uppercased()
                if let method = HTTPMethod(rawValue: raw) {
                    explicitMethod = method
                } else {
                    warnings.append("Unsupported HTTP method: \(raw)")
                }
            } else if token.hasPrefix("--request=") {
                let raw = String(token.dropFirst("--request=".count)).uppercased()
                if let method = HTTPMethod(rawValue: raw) {
                    explicitMethod = method
                } else {
                    warnings.append("Unsupported HTTP method: \(raw)")
                }
            } else if token == "-H" || token == "--header" {
                applyHeader(try value(after: token), to: &request, warnings: &warnings)
            } else if token.hasPrefix("--header=") {
                applyHeader(String(token.dropFirst("--header=".count)), to: &request, warnings: &warnings)
            } else if ["-d", "--data", "--data-raw", "--data-binary"].contains(token) {
                applyBody(try value(after: token), to: &request)
                inferredPost = true
            } else if let prefix = ["--data=", "--data-raw=", "--data-binary="].first(where: token.hasPrefix) {
                applyBody(String(token.dropFirst(prefix.count)), to: &request)
                inferredPost = true
            } else if token == "--data-urlencode" {
                applyURLEncodedBody(try value(after: token), to: &request, warnings: &warnings)
                inferredPost = true
            } else if token.hasPrefix("--data-urlencode=") {
                applyURLEncodedBody(String(token.dropFirst("--data-urlencode=".count)), to: &request, warnings: &warnings)
                inferredPost = true
            } else if token == "-F" || token == "--form" {
                applyMultipartPart(try value(after: token), to: &request, warnings: &warnings)
                inferredPost = true
            } else if token.hasPrefix("--form=") {
                applyMultipartPart(String(token.dropFirst("--form=".count)), to: &request, warnings: &warnings)
                inferredPost = true
            } else if token == "-u" || token == "--user" {
                applyBasicAuth(try value(after: token), to: &request)
            } else if token.hasPrefix("--user=") {
                applyBasicAuth(String(token.dropFirst("--user=".count)), to: &request)
            } else if token == "--url" {
                request.urlString = try value(after: token)
            } else if token.hasPrefix("--url=") {
                request.urlString = String(token.dropFirst("--url=".count))
            } else if token == "-G" || token == "--get" {
                forceGet = true
            } else if ["-L", "--location", "--location-trusted"].contains(token) {
                // Redirect following is URLSession's default behavior.
            } else if ["--proxy", "-x", "--connect-timeout", "--max-time", "--cacert", "--cert", "--key", "--cookie", "-b", "--cookie-jar", "-c", "--output", "-o"].contains(token) {
                _ = try value(after: token)
                warnings.append("Ignored unsupported curl option: \(token)")
            } else if token.hasPrefix("-") {
                warnings.append("Ignored unsupported curl option: \(token)")
            } else if request.urlString.isEmpty {
                request.urlString = token
            } else {
                warnings.append("Ignored extra argument: \(token)")
            }
            index += 1
        }

        guard !request.urlString.isEmpty else { throw CurlImportError.missingURL }
        splitQueryItems(in: &request)
        formatJSONBody(in: &request)

        if forceGet {
            request.method = .get
            if !request.formItems.isEmpty {
                request.queryItems.append(contentsOf: request.formItems)
                request.formItems = []
                request.bodyKind = .none
            } else if !request.body.isEmpty {
                appendBodyAsQueryItems(to: &request)
                request.body = ""
                request.bodyKind = .none
            }
        } else if let explicitMethod {
            request.method = explicitMethod
        } else if inferredPost {
            request.method = .post
        }

        if request.headers.isEmpty { request.headers = [KeyValueItem()] }
        if request.queryItems.isEmpty { request.queryItems = [KeyValueItem()] }
        return CurlImportResult(request: request, warnings: warnings)
    }

    func tokenize(_ command: String) throws -> [String] {
        let normalized = command.replacingOccurrences(of: "\\\r\n", with: " ")
            .replacingOccurrences(of: "\\\n", with: " ")
        var tokens: [String] = []
        var current = ""
        var quote: Character?
        var escaping = false
        var tokenStarted = false

        for character in normalized {
            if escaping {
                current.append(character)
                escaping = false
                tokenStarted = true
                continue
            }

            if character == "\\" && quote != "'" {
                escaping = true
                tokenStarted = true
                continue
            }

            if let activeQuote = quote {
                if character == activeQuote {
                    quote = nil
                } else {
                    current.append(character)
                }
                tokenStarted = true
                continue
            }

            if character == "'" || character == "\"" {
                quote = character
                tokenStarted = true
            } else if character.isWhitespace {
                if tokenStarted {
                    tokens.append(current)
                    current = ""
                    tokenStarted = false
                }
            } else {
                current.append(character)
                tokenStarted = true
            }
        }

        if escaping { current.append("\\") }
        guard quote == nil else { throw CurlImportError.unterminatedQuote }
        if tokenStarted { tokens.append(current) }
        return tokens
    }

    private func applyHeader(_ raw: String, to request: inout HTTPRequestDraft, warnings: inout [String]) {
        guard let separator = raw.firstIndex(of: ":") else {
            warnings.append("Ignored malformed header: \(raw)")
            return
        }
        let name = String(raw[..<separator]).trimmingCharacters(in: .whitespaces)
        let value = String(raw[raw.index(after: separator)...]).trimmingCharacters(in: .whitespaces)

        if name.caseInsensitiveCompare("Authorization") == .orderedSame {
            if value.lowercased().hasPrefix("bearer ") {
                request.authentication.kind = .bearer
                request.authentication.secret = String(value.dropFirst(7))
                request.authentication.credentialID = request.authentication.credentialID ?? UUID()
                return
            }
            if value.lowercased().hasPrefix("basic ") {
                warnings.append("Imported an encoded Basic Authorization header as a normal header. Use the Auth section to edit it safely.")
            }
        }
        request.headers.append(KeyValueItem(name: name, value: value))
    }

    private func applyBody(_ value: String, to request: inout HTTPRequestDraft) {
        if request.body.isEmpty {
            request.body = value
        } else {
            request.body += "&" + value
        }
        request.bodyKind = request.headers.contains {
            $0.name.caseInsensitiveCompare("Content-Type") == .orderedSame &&
            $0.value.lowercased().contains("application/json")
        } || value.trimmingCharacters(in: .whitespacesAndNewlines).first.map({ $0 == "{" || $0 == "[" }) == true ? .json : .raw
    }

    private func applyURLEncodedBody(_ value: String, to request: inout HTTPRequestDraft, warnings: inout [String]) {
        let separator = value.firstIndex(of: "=")
        if let fileMarker = value.firstIndex(of: "@") {
            let usesFileInput = separator.map { fileMarker < $0 } ?? true
            if usesFileInput {
                warnings.append("Ignored file-based --data-urlencode input for safety. Paste the value directly instead.")
                return
            }
        }

        if let separator {
            let name = String(value[..<separator])
            let content = String(value[value.index(after: separator)...])
            request.formItems.append(KeyValueItem(name: name, value: content))
        } else {
            request.formItems.append(KeyValueItem(name: value, value: ""))
        }
        request.bodyKind = .formURLEncoded
    }

    private func applyMultipartPart(_ value: String, to request: inout HTTPRequestDraft, warnings: inout [String]) {
        guard let separator = value.firstIndex(of: "=") else {
            warnings.append("Ignored malformed multipart field: \(value)")
            return
        }
        let name = String(value[..<separator])
        let content = String(value[value.index(after: separator)...])
        if content.hasPrefix("@") {
            request.multipartParts.append(MultipartPart(
                name: name,
                kind: .file,
                filePath: String(content.dropFirst()),
                isFileAccessApproved: false
            ))
            warnings.append("File field \(name) needs approval before Curlman can read it.")
        } else {
            request.multipartParts.append(MultipartPart(name: name, value: content))
        }
        request.bodyKind = .multipart
    }

    private func applyBasicAuth(_ value: String, to request: inout HTTPRequestDraft) {
        let parts = value.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
        request.authentication.kind = .basic
        request.authentication.username = parts.first.map(String.init) ?? ""
        request.authentication.secret = parts.count > 1 ? String(parts[1]) : ""
        request.authentication.credentialID = request.authentication.credentialID ?? UUID()
    }

    private func splitQueryItems(in request: inout HTTPRequestDraft) {
        guard var components = URLComponents(string: request.urlString) else { return }
        let items = components.queryItems ?? []
        request.queryItems.append(contentsOf: items.map {
            KeyValueItem(name: $0.name, value: $0.value ?? "")
        })
        components.query = nil
        request.urlString = components.string ?? request.urlString
    }

    private func appendBodyAsQueryItems(to request: inout HTTPRequestDraft) {
        var components = URLComponents()
        components.query = request.body
        request.queryItems.append(contentsOf: (components.queryItems ?? []).map {
            KeyValueItem(name: $0.name, value: $0.value ?? "")
        })
    }

    private func formatJSONBody(in request: inout HTTPRequestDraft) {
        guard request.bodyKind == .json,
              let data = request.body.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]),
              let formatted = try? JSONSerialization.data(
                  withJSONObject: object,
                  options: [.prettyPrinted, .withoutEscapingSlashes, .fragmentsAllowed]
              ),
              let text = String(data: formatted, encoding: .utf8) else { return }
        request.body = text
    }
}
