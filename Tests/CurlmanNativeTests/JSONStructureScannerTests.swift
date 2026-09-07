import XCTest
@testable import CurlmanNative

final class JSONStructureScannerTests: XCTestCase {
    private let scanner = JSONStructureScanner()

    func testDiscoversNestedMultilineObjectsAndArraysWithCounts() throws {
        let source = """
        {
          "items": [
            {"id": 1},
            {"id": 2}
          ],
          "meta": {"count": 2}
        }
        """

        let regions = scanner.regions(in: source)

        XCTAssertEqual(regions.map(\.kind), [.object, .array])
        XCTAssertEqual(regions.map(\.openingLine), [1, 2])
        XCTAssertEqual(regions.map(\.itemCount), [2, 2])
        XCTAssertEqual(regions.map(\.summary), ["… 2 keys", "… 2 items"])
    }

    func testIgnoresStructuralCharactersInsideStrings() throws {
        let source = """
        {
          "message": "escaped quote: \\\" and braces: { [ ] }",
          "ok": true
        }
        """

        let regions = scanner.regions(in: source)

        XCTAssertEqual(regions.count, 1)
        XCTAssertEqual(regions.first?.kind, .object)
        XCTAssertEqual(regions.first?.itemCount, 2)
    }

    func testExcludesSingleLineStructures() {
        XCTAssertTrue(scanner.regions(in: #"{"value":[1,2,3]}"#).isEmpty)
    }

    func testInvalidJSONHasNoFoldRegions() {
        XCTAssertTrue(scanner.regions(in: "{\n  \\\"value\\\": true\n").isEmpty)
    }
}
