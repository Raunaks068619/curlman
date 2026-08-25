import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var panelController: PanelController?
    private var hotKey: GlobalHotKey?
    private(set) var model: AppModel?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        do {
            let history = try HistoryStore()
            let model = AppModel(historyStore: history)
            self.model = model
            panelController = PanelController(model: model)
            configureStatusItem()
            hotKey = GlobalHotKey { [weak self] in self?.panelController?.toggle() }
            if hotKey?.register() == false {
                notifyShortcutConflict()
            }
            panelController?.showPanel()
        } catch {
            let alert = NSAlert(error: error)
            alert.messageText = "API Panel could not start"
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

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    private func configureStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "network", accessibilityDescription: "API Panel")
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Open API Panel", action: #selector(togglePanel), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "New Request", action: #selector(newRequest), keyEquivalent: "n"))
        menu.addItem(NSMenuItem(title: "History", action: #selector(showHistory), keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit API Panel", action: #selector(quit), keyEquivalent: "q"))
        menu.items.forEach { $0.target = self }
        item.menu = menu
        statusItem = item
    }

    private func notifyShortcutConflict() {
        statusItem?.button?.toolTip = "API Panel (Command-Shift-C is used by another app)"
        NSSound.beep()
    }
}
