import XCTest
@testable import APIPanel

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

        let data = try JSONEncoder().encode(draft.sanitizedForPersistence)
        let text = try XCTUnwrap(String(data: data, encoding: .utf8))

        XCTAssertFalse(text.contains("top-secret"))
        XCTAssertFalse(text.contains("another-secret"))
        XCTAssertTrue(text.contains("stored securely"))
    }
}

