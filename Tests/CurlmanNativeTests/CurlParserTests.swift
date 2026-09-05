import XCTest
@testable import CurlmanNative

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

    func testParsesTemporalWorkflowCurlWithURLFlagAndFormattedBody() throws {
        let command = #"""
        curl --request POST \
          --url 'https://asia-south1.api.boltic.io/service/webhook/temporal/v1.0/97b7ac1b-a7e6-4be7-9278-df4e99d5d353/workflows/execute/ab2ceff2-66e5-4ef6-8384-6ccd2037eeb7' \
          --header 'content-type: application/json' \
          --data-raw '{
            "target": "sales-channel-live-products",
            "run_time": "2026-08-25 05:29:00+00",
            "calls": [["sales-channel-live-products", "2026-08-25 05:29:00+00"]],
            "caller": "manual-test",
            "user_defined_context": null
          }'
        """#

        let result = try parser.parse(command)

        XCTAssertEqual(
            result.request.urlString,
            "https://asia-south1.api.boltic.io/service/webhook/temporal/v1.0/97b7ac1b-a7e6-4be7-9278-df4e99d5d353/workflows/execute/ab2ceff2-66e5-4ef6-8384-6ccd2037eeb7"
        )
        XCTAssertEqual(result.request.method, .post)
        XCTAssertEqual(result.request.bodyKind, .json)
        XCTAssertNotNil(result.request.parsedJSONBody)
        XCTAssertTrue(result.request.body.contains("\n"))
    }

    func testGetMovesDataIntoQueryItems() throws {
        let result = try parser.parse("curl -G https://example.com/search --data 'q=swift&limit=5'")

        XCTAssertEqual(result.request.method, .get)
        XCTAssertEqual(result.request.bodyKind, .none)
        XCTAssertEqual(result.request.queryItems.filter(\.isEnabled).count, 2)
    }

    func testGetMovesDataURLEncodeFieldsIntoQueryItems() throws {
        let command = #"""
        curl --get \
          'https://coach.co.za/ext/reco-extension/reco' \
          --data-urlencode 'recommendation_slug=similar-products' \
          --data-urlencode 'slug=tabby-bag-charm-198685064919' \
          --data-urlencode 'currency_code=ZAR' \
          -H 'Accept: application/json'
        """#

        let result = try parser.parse(command)

        XCTAssertEqual(result.request.method, .get)
        XCTAssertEqual(result.request.urlString, "https://coach.co.za/ext/reco-extension/reco")
        XCTAssertEqual(result.request.queryItems.first { $0.name == "recommendation_slug" }?.value, "similar-products")
        XCTAssertEqual(result.request.queryItems.first { $0.name == "slug" }?.value, "tabby-bag-charm-198685064919")
        XCTAssertEqual(result.request.queryItems.first { $0.name == "currency_code" }?.value, "ZAR")
        XCTAssertEqual(result.request.headers.first?.name, "Accept")
        XCTAssertEqual(result.request.bodyKind, .none)
        XCTAssertTrue(result.warnings.isEmpty)
    }

    func testPostDataURLEncodeCreatesEditableFormFields() throws {
        let result = try parser.parse("curl https://example.com/token --data-urlencode 'grant_type=client credentials'")

        XCTAssertEqual(result.request.method, .post)
        XCTAssertEqual(result.request.bodyKind, .formURLEncoded)
        XCTAssertEqual(result.request.formItems.first?.name, "grant_type")
        XCTAssertEqual(result.request.formItems.first?.value, "client credentials")
    }

    func testMultipartFileImportRequiresApproval() throws {
        let result = try parser.parse("curl https://example.com/upload -F 'title=Report' -F 'document=@/tmp/report.pdf'")

        XCTAssertEqual(result.request.bodyKind, .multipart)
        XCTAssertEqual(result.request.multipartParts.count, 2)
        XCTAssertEqual(result.request.multipartParts[1].kind, .file)
        XCTAssertFalse(result.request.multipartParts[1].isFileAccessApproved)
        XCTAssertTrue(result.warnings.contains { $0.contains("needs approval") })
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
