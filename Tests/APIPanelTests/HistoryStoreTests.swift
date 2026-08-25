import XCTest
@testable import APIPanel

@MainActor
final class HistoryStoreTests: XCTestCase {
    func testStoresEveryRequestAndFinalizesResponse() throws {
        let store = try HistoryStore(inMemory: true, responseBodyLimit: 4)
        var draft = HTTPRequestDraft.empty
        draft.urlString = "https://example.com"
        let id = try store.begin(request: draft)

        XCTAssertEqual(store.records.count, 1)
        XCTAssertEqual(store.records.first?.outcome, .pending)

        let response = HTTPResponseSnapshot(
            statusCode: 200,
            reasonPhrase: "OK",
            headers: ["Content-Type": "application/json"],
            body: Data("123456".utf8),
            mimeType: "application/json",
            duration: 0.1,
            receivedByteCount: 6,
            errorDescription: nil
        )
        try store.finalize(id: id, response: response)

        XCTAssertEqual(store.records.first?.outcome, .success)
        XCTAssertEqual(store.records.first?.response?.body.count, 4)
        XCTAssertEqual(store.records.first?.bodyTruncated, true)
    }
}

