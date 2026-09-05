import XCTest
@testable import CurlmanNative

final class UpdateCheckerTests: XCTestCase {
    func testParsesTaggedSemanticVersions() throws {
        XCTAssertEqual(ReleaseVersion("v1.2.3"), ReleaseVersion("1.2.3"))
        XCTAssertNil(ReleaseVersion("latest"))
    }

    func testComparesDifferentLengthVersions() throws {
        XCTAssertLessThan(try XCTUnwrap(ReleaseVersion("0.2.7")), try XCTUnwrap(ReleaseVersion("1.0.0")))
        XCTAssertEqual(ReleaseVersion("1.0"), ReleaseVersion("1.0.0"))
        XCTAssertGreaterThan(try XCTUnwrap(ReleaseVersion("1.10.0")), try XCTUnwrap(ReleaseVersion("1.9.9")))
    }

    func testIgnoresPrereleaseSuffixForUpdateComparison() throws {
        XCTAssertEqual(ReleaseVersion("v1.2.0-beta.1"), ReleaseVersion("1.2.0"))
    }

    func testEvaluatesGitHubReleasePayload() throws {
        let data = Data(#"{"tag_name":"v1.0.0","html_url":"https://github.com/Raunaks068619/curlman/releases/tag/v1.0.0"}"#.utf8)

        XCTAssertEqual(
            try UpdateChecker.evaluate(data: data, currentVersion: "0.2.7"),
            .updateAvailable(
                AvailableRelease(
                    version: "v1.0.0",
                    pageURL: try XCTUnwrap(URL(string: "https://github.com/Raunaks068619/curlman/releases/tag/v1.0.0"))
                )
            )
        )
        XCTAssertEqual(try UpdateChecker.evaluate(data: data, currentVersion: "1.0.0"), .current)
    }
}
