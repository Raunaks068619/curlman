import XCTest
@testable import APIPanel

final class CurlParserTests: XCTestCase {
    private let parser = CurlParser()

    func testParsesJSONPostWithBearerToken() throws {
        let result = try parser.parse(#"curl 'https://api.example.com/messages?limit=10' -H 'Content-Type: application/json' -H 'Authorization: Bearer secret-token' --data-raw '{"message":"hello"}'"#)

        XCTAssertEqual(result.request.method, .post)
        XCTAssertEqual(result.request.urlString, "https://api.example.com/messages")
        XCTAssertEqual(result.request.queryItems.first?.name, "limit")
        XCTAssertEqual(result.request.queryItems.first?.value, "10")
        XCTAssertEqual(result.request.bodyKind, .json)
        XCTAssertEqual(result.request.authentication.kind, .bearer)
        XCTAssertEqual(result.request.authentication.secret, "secret-token")
        XCTAssertFalse(result.request.headers.contains { $0.name.caseInsensitiveCompare("Authorization") == .orderedSame })
    }

    func testParsesMultilineCommandAndBasicAuthentication() throws {
        let command = """
        curl --request PUT \\
          --url https://api.example.com/profile \\
          --user 'raunak:p@ss word' \\
          --header 'Accept: application/json'
        """
        let result = try parser.parse(command)

        XCTAssertEqual(result.request.method, .put)
        XCTAssertEqual(result.request.authentication.kind, .basic)
        XCTAssertEqual(result.request.authentication.username, "raunak")
        XCTAssertEqual(result.request.authentication.secret, "p@ss word")
        XCTAssertEqual(result.request.headers.first?.name, "Accept")
    }

    func testParsesPostmanStyleMultilineCurlWithURLLast() throws {
        let command = #"""
        curl --location --request POST \
          --header 'content-type: application/json' \
          --data-raw '{"target":"sales-channel-live-products","calls":[["sales-channel-live-products","2026-08-25 05:29:00+00"]],"caller":"manual-test","user_defined_context":null}' \
          'https://asia-south1.api.boltic.io/service/webhook/test'
        """#

        let result = try parser.parse(command)

        XCTAssertEqual(result.request.urlString, "https://asia-south1.api.boltic.io/service/webhook/test")
        XCTAssertEqual(result.request.method, .post)
        XCTAssertEqual(result.request.headers.first?.name, "content-type")
        XCTAssertTrue(result.request.body.contains("\n"), "Imported JSON should be automatically pretty printed")
        XCTAssertTrue(result.request.body.contains("  \"target\""))
        XCTAssertFalse(result.warnings.contains { $0.contains("--location") })
    }

    func testGetMovesDataIntoQueryItems() throws {
        let result = try parser.parse("curl -G https://example.com/search --data 'q=swift&limit=5'")

        XCTAssertEqual(result.request.method, .get)
        XCTAssertEqual(result.request.bodyKind, .none)
        XCTAssertEqual(result.request.queryItems.filter(\.isEnabled).count, 2)
    }

    func testUnsupportedOptionsBecomeWarnings() throws {
        let result = try parser.parse("curl --compressed --proxy http://localhost:8080 https://example.com")

        XCTAssertEqual(result.request.urlString, "https://example.com")
        XCTAssertFalse(result.warnings.isEmpty)
    }

    func testRejectsUnterminatedQuote() {
        XCTAssertThrowsError(try parser.parse("curl 'https://example.com")) { error in
            XCTAssertEqual(error as? CurlImportError, .unterminatedQuote)
        }
    }
}
