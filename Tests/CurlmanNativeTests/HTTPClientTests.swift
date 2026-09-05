import XCTest
@testable import CurlmanNative

final class HTTPClientTests: XCTestCase {
    func testBuildsURLRequestWithQueryHeadersBodyAndBearerAuth() throws {
        var draft = HTTPRequestDraft.empty
        draft.method = .post
        draft.urlString = "https://example.com/messages"
        draft.queryItems = [KeyValueItem(name: "limit", value: "10")]
        draft.headers = [KeyValueItem(name: "Accept", value: "application/json")]
        draft.bodyKind = .json
        draft.body = #"{"message":"hello"}"#
        draft.authentication = Authentication(kind: .bearer, secret: "top-secret")

        let request = try HTTPClient().makeURLRequest(from: draft)

        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(URLComponents(url: try XCTUnwrap(request.url), resolvingAgainstBaseURL: false)?.queryItems?.first?.value, "10")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Accept"), "application/json")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer top-secret")
        XCTAssertEqual(request.httpBody, draft.body.data(using: .utf8))
    }

    func testSanitizedDraftRemovesSecrets() throws {
        var draft = HTTPRequestDraft.empty
        draft.authentication = Authentication(kind: .bearer, secret: "top-secret", credentialID: UUID())
        draft.headers = [KeyValueItem(name: "Authorization", value: "Bearer another-secret")]
        draft.multipartParts = [MultipartPart(name: "file", kind: .file, filePath: "/tmp/report.pdf", isFileAccessApproved: true)]

        let sanitized = draft.sanitizedForPersistence
        let data = try JSONEncoder().encode(sanitized)
        let text = try XCTUnwrap(String(data: data, encoding: .utf8))

        XCTAssertFalse(text.contains("top-secret"))
        XCTAssertFalse(text.contains("another-secret"))
        XCTAssertTrue(text.contains("stored securely"))
        XCTAssertFalse(sanitized.multipartParts[0].isFileAccessApproved)
    }

    func testBuildsFormURLEncodedBody() throws {
        var draft = HTTPRequestDraft.empty
        draft.method = .post
        draft.urlString = "https://example.com/search"
        draft.bodyKind = .formURLEncoded
        draft.formItems = [
            KeyValueItem(name: "query", value: "swift ui"),
            KeyValueItem(name: "symbol", value: "a&b")
        ]

        let request = try HTTPClient().makeURLRequest(from: draft)

        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/x-www-form-urlencoded")
        XCTAssertEqual(String(data: try XCTUnwrap(request.httpBody), encoding: .utf8), "query=swift+ui&symbol=a%26b")
    }

    func testAddsAPIKeyToHeaderOrQuery() throws {
        var draft = HTTPRequestDraft.empty
        draft.urlString = "https://example.com/items"
        draft.authentication = Authentication(
            kind: .apiKey,
            secret: "secret value",
            apiKeyName: "X-Service-Key",
            apiKeyPlacement: .header
        )

        var request = try HTTPClient().makeURLRequest(from: draft)
        XCTAssertEqual(request.value(forHTTPHeaderField: "X-Service-Key"), "secret value")

        draft.authentication.apiKeyPlacement = .query
        request = try HTTPClient().makeURLRequest(from: draft)
        let items = URLComponents(url: try XCTUnwrap(request.url), resolvingAgainstBaseURL: false)?.queryItems
        XCTAssertEqual(items?.first { $0.name == "X-Service-Key" }?.value, "secret value")
    }

    func testMultipartFilesRequireExplicitApproval() throws {
        var draft = HTTPRequestDraft.empty
        draft.method = .post
        draft.urlString = "https://example.com/upload"
        draft.bodyKind = .multipart
        draft.multipartParts = [
            MultipartPart(name: "document", kind: .file, filePath: "/tmp/private.txt")
        ]

        XCTAssertThrowsError(try HTTPClient().makeURLRequest(from: draft)) { error in
            XCTAssertEqual(error as? HTTPClientError, .fileAccessNotApproved("document"))
        }
        XCTAssertEqual(draft.validationError(), "Approve each multipart file before sending it.")
    }

    func testBuildsApprovedMultipartTextAndFileParts() throws {
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try Data("hello".utf8).write(to: fileURL)
        defer { try? FileManager.default.removeItem(at: fileURL) }

        var draft = HTTPRequestDraft.empty
        draft.method = .post
        draft.urlString = "https://example.com/upload"
        draft.bodyKind = .multipart
        draft.multipartParts = [
            MultipartPart(name: "title", value: "Report"),
            MultipartPart(name: "document", kind: .file, filePath: fileURL.path, mimeType: "text/plain", isFileAccessApproved: true)
        ]

        let request = try HTTPClient().makeURLRequest(from: draft)
        let body = try XCTUnwrap(String(data: try XCTUnwrap(request.httpBody), encoding: .utf8))

        XCTAssertTrue(request.value(forHTTPHeaderField: "Content-Type")?.hasPrefix("multipart/form-data; boundary=Curlman-") == true)
        XCTAssertTrue(body.contains("name=\"title\""))
        XCTAssertTrue(body.contains("Report"))
        XCTAssertTrue(body.contains("filename=\"\(fileURL.lastPathComponent)\""))
        XCTAssertTrue(body.contains("hello"))
    }

    func testAppliesTimeoutAndDisablesCookiesByDefault() throws {
        var draft = HTTPRequestDraft.empty
        draft.urlString = "https://example.com"
        draft.timeoutInterval = 12

        let request = try HTTPClient().makeURLRequest(from: draft)

        XCTAssertEqual(request.timeoutInterval, 12)
        XCTAssertFalse(request.httpShouldHandleCookies)
    }

    func testOldDraftDecodesWithNewPolicyDefaults() throws {
        let legacy = #"{"method":"GET","urlString":"https://example.com","queryItems":[],"headers":[],"bodyKind":"None","body":"","authentication":{"kind":"None","username":"","secret":""}}"#

        let draft = try JSONDecoder().decode(HTTPRequestDraft.self, from: Data(legacy.utf8))

        XCTAssertEqual(draft.timeoutInterval, 60)
        XCTAssertEqual(draft.redirectPolicy, .follow)
        XCTAssertEqual(draft.cookiePolicy, .disabled)
        XCTAssertEqual(draft.authentication.apiKeyName, "X-API-Key")
    }
}
