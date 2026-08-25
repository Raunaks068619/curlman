import Carbon.HIToolbox
import Foundation
import Testing
@testable import CurlmanNative

@MainActor
struct ShortcutPreferencesTests {
    @Test
    func shortcutPersistsAndDisplaysMacModifiers() {
        let suiteName = UUID().uuidString
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        let shortcut = GlobalShortcut(
            keyCode: UInt32(kVK_ANSI_E),
            modifiers: UInt32(controlKey | optionKey | shiftKey | cmdKey),
            key: "e"
        )

        ShortcutPreferences(defaults: defaults).save(shortcut)
        let restored = ShortcutPreferences(defaults: defaults)

        #expect(restored.shortcut == shortcut)
        #expect(restored.shortcut.displayName == "⌃⌥⇧⌘E")
    }
}
