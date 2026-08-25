import XCTest
@testable import CurlmanNative

@MainActor
final class AppModelCopyTests: XCTestCase {
    func testCopiesTheCurrentEditedRequestAsCurl() throws {
        let clipboard = ClipboardSpy()
        let model = AppModel(
            historyStore: try HistoryStore(inMemory: true),
            clipboard: clipboard
        )
        model.draft.method = .put
        model.draft.urlString = "https://api.example.com/items"
        model.draft.headers = [KeyValueItem(name: "X-Version", value: "2")]

        model.copyAsCurl()

        XCTAssertEqual(
            clipboard.string,
            """
            curl --request PUT \\
              --url 'https://api.example.com/items' \\
              --header 'X-Version: 2'
            """
        )
        XCTAssertTrue(model.didCopyCurl)
        XCTAssertNil(model.inlineError)
    }
}

@MainActor
private final class ClipboardSpy: ClipboardWriting {
    private(set) var string: String?

    func write(_ string: String) -> Bool {
        self.string = string
        return true
    }
}
