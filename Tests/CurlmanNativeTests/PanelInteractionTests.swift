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

    func testOnboardingKeepsIntentionalWindowHeight() throws {
        let defaults = UserDefaults.standard
        let keys = ["hasPositionedPanel", "panelFrame", "expandedFrame", "isCompact"]
        let originals = Dictionary(uniqueKeysWithValues: keys.map { ($0, defaults.object(forKey: $0)) })
        defer {
            for key in keys {
                if let value = originals[key] ?? nil { defaults.set(value, forKey: key) }
                else { defaults.removeObject(forKey: key) }
            }
        }
        defaults.set(true, forKey: "hasPositionedPanel")
        defaults.set(NSStringFromRect(NSRect(x: 100, y: 100, width: 780, height: 2_088)), forKey: "panelFrame")
        defaults.set(false, forKey: "isCompact")

        let suiteName = "PanelInteractionTests.\(UUID().uuidString)"
        let onboardingDefaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        onboardingDefaults.removePersistentDomain(forName: suiteName)
        let onboarding = OnboardingState(defaults: onboardingDefaults)
        let history = try HistoryStore(inMemory: true, configurationName: suiteName)
        let model = AppModel(historyStore: history)
        let controller = PanelController(
            model: model,
            onboardingState: onboarding,
            shortcutPreferences: ShortcutPreferences(),
            registerShortcut: { _ in true }
        )

        controller.showPanel()
        RunLoop.current.run(until: Date().addingTimeInterval(0.3))

        XCTAssertEqual(try XCTUnwrap(controller.window).frame.height, 520, accuracy: 0.5)
        controller.window?.orderOut(nil)
    }
}
