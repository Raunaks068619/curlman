import Carbon.HIToolbox
import Foundation

struct GlobalShortcut: Codable, Equatable, Sendable {
    let keyCode: UInt32
    let modifiers: UInt32
    let key: String

    static let defaultShortcut = GlobalShortcut(
        keyCode: UInt32(kVK_ANSI_C),
        modifiers: UInt32(cmdKey | shiftKey),
        key: "C"
    )

    var displayName: String {
        modifierGlyphs + key.uppercased()
    }

    private var modifierGlyphs: String {
        var glyphs = ""
        if modifiers & UInt32(controlKey) != 0 { glyphs += "⌃" }
        if modifiers & UInt32(optionKey) != 0 { glyphs += "⌥" }
        if modifiers & UInt32(shiftKey) != 0 { glyphs += "⇧" }
        if modifiers & UInt32(cmdKey) != 0 { glyphs += "⌘" }
        return glyphs
    }
}

@MainActor
final class ShortcutPreferences: ObservableObject {
    @Published private(set) var shortcut: GlobalShortcut

    private static let storageKey = "globalShortcutV1"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.storageKey),
           let stored = try? JSONDecoder().decode(GlobalShortcut.self, from: data) {
            shortcut = stored
        } else {
            shortcut = .defaultShortcut
        }
    }

    func save(_ shortcut: GlobalShortcut) {
        self.shortcut = shortcut
        if let data = try? JSONEncoder().encode(shortcut) {
            defaults.set(data, forKey: Self.storageKey)
        }
    }
}
