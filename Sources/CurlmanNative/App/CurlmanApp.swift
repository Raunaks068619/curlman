import SwiftUI

@main
struct CurlmanApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            ShortcutSettingsView(
                preferences: appDelegate.shortcutPreferences,
                register: appDelegate.registerShortcut
            )
        }
    }
}
