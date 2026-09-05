import XCTest
@testable import CurlmanNative

final class CurlExporterTests: XCTestCase {
    func testExportsMethodAndFinalURLWithEnabledQueryItems() throws {
        var draft = HTTPRequestDraft.empty
        draft.method = .get
        draft.urlString = "https://api.example.com/items?existing=1"
        draft.queryItems = [
            KeyValueItem(isEnabled: true, name: "search", value: "two words"),
            KeyValueItem(isEnabled: false, name: "ignored", value: "value")
        ]

        let command = try CurlExporter().export(draft)

        XCTAssertEqual(
            command,
            """
            curl --request GET \\
              --url 'https://api.example.com/items?existing=1&search=two%20words'
            """
        )
    }

    func testExportsEnabledHeadersBearerAuthAndJSONBodyWithShellSafeQuotes() throws {
        var draft = HTTPRequestDraft.empty
        draft.method = .post
        draft.urlString = "https://api.example.com/messages"
        draft.headers = [
            KeyValueItem(isEnabled: true, name: "Accept", value: "application/json"),
            KeyValueItem(isEnabled: true, name: "X-Note", value: "Raunak's Mac"),
            KeyValueItem(isEnabled: false, name: "X-Ignored", value: "no")
        ]
        draft.authentication = Authentication(kind: .bearer, secret: "secret-token")
        draft.bodyKind = .json
        draft.body = #"{"message":"it's ready"}"#

        let command = try CurlExporter().export(draft)

        XCTAssertTrue(command.contains("--header 'Accept: application/json'"))
        XCTAssertTrue(command.contains("--header 'Authorization: Bearer secret-token'"))
        XCTAssertTrue(command.contains("--header 'Content-Type: application/json'"))
        XCTAssertTrue(command.contains("--header 'X-Note: Raunak'\\''s Mac'"))
        XCTAssertFalse(command.contains("X-Ignored"))
        XCTAssertTrue(command.contains(#"--data-raw '{"message":"it'\''s ready"}'"#))
    }

    func testExportsEditableFormAndMultipartFields() throws {
        var form = HTTPRequestDraft.empty
        form.method = .post
        form.urlString = "https://example.com/token"
        form.bodyKind = .formURLEncoded
        form.formItems = [KeyValueItem(name: "grant_type", value: "client credentials")]

        let formCommand = try CurlExporter().export(form)
        XCTAssertTrue(formCommand.contains("--data-urlencode 'grant_type=client credentials'"))

        var multipart = HTTPRequestDraft.empty
        multipart.method = .post
        multipart.urlString = "https://example.com/upload"
        multipart.bodyKind = .multipart
        multipart.multipartParts = [
            MultipartPart(name: "title", value: "Report"),
            MultipartPart(name: "document", kind: .file, filePath: "/tmp/report.pdf")
        ]

        let multipartCommand = try CurlExporter().export(multipart)
        XCTAssertTrue(multipartCommand.contains("--form 'title=Report'"))
        XCTAssertTrue(multipartCommand.contains("--form 'document=@/tmp/report.pdf'"))
    }
}
