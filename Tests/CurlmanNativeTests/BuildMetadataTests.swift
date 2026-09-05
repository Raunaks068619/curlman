import XCTest
@testable import CurlmanNative

final class BuildMetadataTests: XCTestCase {
    func testGitHubStarCopyHandlesZeroSingularAndPlural() {
        XCTAssertEqual(GitHubStarCopy.count(0), "0 stars")
        XCTAssertEqual(GitHubStarCopy.supporting(0), "Be the first star")
        XCTAssertEqual(GitHubStarCopy.count(1), "1 star")
        XCTAssertEqual(GitHubStarCopy.count(42), "42 stars")
        XCTAssertEqual(GitHubStarCopy.supporting(42), "Open source on GitHub")
    }
}
