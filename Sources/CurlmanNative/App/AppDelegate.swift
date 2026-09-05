import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let shortcutPreferences = ShortcutPreferences()
    let onboardingState = OnboardingState()

    private var statusItem: NSStatusItem?
    private var panelController: PanelController?
    private var hotKey: GlobalHotKey?
    private(set) var model: AppModel?
    private let updateChecker = UpdateChecker()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        do {
            let history = try HistoryStore()
            let credentialStore = KeychainCredentialStore()
            try LegacyDataMigrator(curlmanCredentials: credentialStore).migrateIfNeeded(into: history)
            onboardingState.prepareForLaunch(
                isExistingInstallation: UserDefaults.standard.bool(forKey: "hasPositionedPanel") || !history.records.isEmpty
            )
            let model = AppModel(
                historyStore: history,
                credentialStore: credentialStore,
                draftStore: UserDefaultsDraftStore()
            )
            self.model = model
            panelController = PanelController(
                model: model,
                onboardingState: onboardingState,
                shortcutPreferences: shortcutPreferences,
                registerShortcut: { [weak self] shortcut in self?.registerShortcut(shortcut) ?? false }
            )
            configureStatusItem()
            hotKey = GlobalHotKey { [weak self] in self?.handleGlobalShortcut() }
            if hotKey?.register(shortcutPreferences.shortcut) == false {
                notifyShortcutConflict()
            }
            panelController?.showPanel()
        } catch {
            let alert = NSAlert(error: error)
            alert.messageText = "Curlman could not start"
            alert.runModal()
            NSApp.terminate(nil)
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotKey?.unregister()
    }

    @objc private func togglePanel() {
        panelController?.toggle()
    }

    @objc private func newRequest() {
        model?.newRequest()
        panelController?.showPanel()
    }

    @objc private func showHistory() {
        model?.showHistory()
        panelController?.showPanel()
    }

    @objc private func showSettings() {
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func showAbout() {
        NSApp.orderFrontStandardAboutPanel(options: [
            .applicationName: "Curlman",
            .applicationVersion: appVersion,
            .credits: NSAttributedString(string: "A fast, local-first API client."),
        ])
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func showHelp() {
        openWebPage(URL(string: "https://github.com/Raunaks068619/curlman#the-workflow")!)
    }

    @objc private func showPrivacy() {
        openWebPage(URL(string: "https://github.com/Raunaks068619/curlman#privacy-and-security")!)
    }

    @objc private func showWelcome() {
        onboardingState.startOver()
        panelController?.showOnboarding()
    }

    @objc private func checkForUpdates() {
        Task { [weak self] in
            guard let self else { return }
            do {
                switch try await updateChecker.check(currentVersion: appVersion) {
                case let .updateAvailable(release):
                    let alert = NSAlert()
                    alert.messageText = "Curlman (release.version) is available"
                    alert.informativeText = "Download the signed release from GitHub."
                    alert.addButton(withTitle: "View Release")
                    alert.addButton(withTitle: "Later")
                    NSApp.activate(ignoringOtherApps: true)
                    if alert.runModal() == .alertFirstButtonReturn {
                        openWebPage(release.pageURL)
                    }
                case .current:
                    showInformationAlert(
                        title: "Curlman is up to date",
                        message: "You are using version \(appVersion)."
                    )
                }
            } catch {
                let alert = NSAlert(error: error)
                alert.messageText = "Could not check for updates"
                NSApp.activate(ignoringOtherApps: true)
                alert.runModal()
            }
        }
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    private func configureStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "network", accessibilityDescription: "Curlman")
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Open Curlman", action: #selector(togglePanel), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "New Request", action: #selector(newRequest), keyEquivalent: "n"))
        menu.addItem(NSMenuItem(title: "History", action: #selector(showHistory), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Settings…", action: #selector(showSettings), keyEquivalent: ","))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Check for Updates…", action: #selector(checkForUpdates), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Curlman Help", action: #selector(showHelp), keyEquivalent: "?"))
        menu.addItem(NSMenuItem(title: "Show Welcome", action: #selector(showWelcome), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Privacy", action: #selector(showPrivacy), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "About Curlman", action: #selector(showAbout), keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit Curlman", action: #selector(quit), keyEquivalent: "q"))
        menu.items.forEach { $0.target = self }
        item.menu = menu
        statusItem = item
    }

    private func notifyShortcutConflict() {
        statusItem?.button?.toolTip = "Curlman (\(shortcutPreferences.shortcut.displayName) is used by another app)"
        NSSound.beep()
    }

    func registerShortcut(_ shortcut: GlobalShortcut) -> Bool {
        guard hotKey?.register(shortcut) == true else {
            notifyShortcutConflict()
            return false
        }
        statusItem?.button?.toolTip = "Curlman · \(shortcut.displayName)"
        return true
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Development"
    }

    private func openWebPage(_ url: URL) {
        NSWorkspace.shared.open(url)
    }

    private func showInformationAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }

    private func handleGlobalShortcut() {
        let wasVisible = panelController?.isPanelVisible ?? false
        onboardingState.recordShortcutInvocation(panelWasVisible: wasVisible)
        panelController?.toggle()
    }
}
