import AppKit
import SwiftUI
import XCTest
@testable import CurlmanNative

final class CodeTextViewLayoutTests: XCTestCase {
    @MainActor
    func testLargeResponseShowsFoldControlsAtVisibleOpeningLines() throws {
        _ = NSApplication.shared
        let items = (0..<100).map { ["id": String($0), "description": String(repeating: "Long product description. ", count: 5)] }
        let data = try JSONSerialization.data(withJSONObject: ["items": items], options: [.prettyPrinted])
        let json = String(decoding: data, as: UTF8.self)
        let host = NSHostingView(rootView: CodeTextView(text: .constant(json), isEditable: false, language: .json))
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 775, height: 450), styleMask: [.titled, .resizable], backing: .buffered, defer: false)
        window.contentView = host
        window.orderFront(nil)
        defer { window.orderOut(nil) }
        host.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.15))
        host.layoutSubtreeIfNeeded()
        let views = descendants(host)
        let editor = try XCTUnwrap(views.compactMap { $0 as? NSTextView }.first)
        let scroll = try XCTUnwrap(editor.enclosingScrollView)
        let buttons = views.compactMap { $0 as? NSButton }.filter { $0.toolTip?.hasPrefix("Collapse") == true }
        XCTAssertGreaterThan(buttons.count, 2)
        let rootButton = try XCTUnwrap(buttons.first { $0.tag == 0 })
        XCTAssertFalse(rootButton.isHidden, "Root fold hidden: frame=\(rootButton.frame), gutter=\(rootButton.superview!.bounds), scroll=\(scroll.contentView.bounds), editor=\(editor.frame)")
        XCTAssertLessThan(abs(rootButton.frame.minY - 11), 3, "Root fold must align with the first visible JSON line")
        XCTAssertGreaterThan(rootButton.superview!.bounds.height, 100)
        let manager = try XCTUnwrap(editor.layoutManager)
        let container = try XCTUnwrap(editor.textContainer)
        manager.ensureLayout(for: container)
        let expandedHeight = manager.usedRect(for: container).height
        rootButton.performClick(nil)
        manager.ensureLayout(for: container)
        XCTAssertLessThan(manager.usedRect(for: container).height, 50, "Collapsed root must occupy a single line")
        XCTAssertTrue(rootButton.toolTip?.hasPrefix("Expand") == true)
        XCTAssertEqual(editor.string, json, "Folding must preserve the original document")
        rootButton.performClick(nil)
        manager.ensureLayout(for: container)
        XCTAssertEqual(manager.usedRect(for: container).height, expandedHeight, accuracy: 1)

        editor.scrollRangeToVisible(NSRange(location: (json as NSString).length - 1, length: 0))
        host.layoutSubtreeIfNeeded()
        XCTAssertTrue(rootButton.isHidden, "Root arrow must leave the gutter when scrolled offscreen")
        XCTAssertTrue(buttons.contains { !$0.isHidden }, "Visible nested JSON must retain folding controls")
        editor.scrollRangeToVisible(NSRange(location: 0, length: 0))
        window.setContentSize(NSSize(width: 600, height: 350))
        host.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))
        host.layoutSubtreeIfNeeded()
        XCTAssertFalse(rootButton.isHidden, "Root arrow must return after scrolling and resizing")
        let firstLine = manager.lineFragmentRect(forGlyphAt: 0, effectiveRange: nil)
        let firstLinePoint = editor.convert(NSPoint(x: 0, y: firstLine.minY + editor.textContainerOrigin.y), to: host)
        let arrowPoint = rootButton.convert(NSPoint(x: 0, y: 1), to: host)
        XCTAssertEqual(arrowPoint.y, firstLinePoint.y, accuracy: 1, "Arrow must stay aligned to its JSON line after scrolling and resizing")
    }

    @MainActor
    private func descendants(_ view: NSView) -> [NSView] {
        [view] + view.subviews.flatMap { descendants($0) }
    }
}
