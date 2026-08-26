import AppKit
import XCTest
@testable import CurlmanNative

@MainActor
final class PanelInteractionTests: XCTestCase {
    func testCompactPanelCanBecomeKey() {
        let panel = InteractivePanel(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 52),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        XCTAssertTrue(panel.canBecomeKey)
    }
}
