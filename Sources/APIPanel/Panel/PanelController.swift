import AppKit
import SwiftUI

@MainActor
final class PanelController: NSWindowController, NSWindowDelegate {
    private let model: AppModel
    private let defaults = UserDefaults.standard
    private var expandedFrame: NSRect?

    init(model: AppModel) {
        self.model = model
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 780, height: 520),
            styleMask: [.titled, .fullSizeContentView, .resizable],
            backing: .buffered,
            defer: false
        )
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isReleasedWhenClosed = false
        panel.minSize = NSSize(width: 600, height: 400)
        panel.standardWindowButton(.closeButton)?.isHidden = true
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true
        super.init(window: panel)
        panel.delegate = self
        let materialView = NSVisualEffectView()
        materialView.material = .underWindowBackground
        materialView.blendingMode = .behindWindow
        materialView.state = .active
        materialView.translatesAutoresizingMaskIntoConstraints = false
        let hostingView = NSHostingView(
            rootView: RootView(
                model: model,
                closeAction: { [weak self] in self?.hidePanel() },
                minimizeAction: { [weak self] in self?.toggleCompact() },
                dragAction: { [weak panel] event in panel?.performDrag(with: event) }
            )
        )
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        let containerView = NSView()
        containerView.addSubview(materialView)
        containerView.addSubview(hostingView, positioned: .above, relativeTo: materialView)
        NSLayoutConstraint.activate([
            materialView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            materialView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            materialView.topAnchor.constraint(equalTo: containerView.topAnchor),
            materialView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            hostingView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            hostingView.topAnchor.constraint(equalTo: containerView.topAnchor),
            hostingView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])
        panel.contentView = containerView
        restoreFrameOrPlaceTopRight()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func toggle() {
        guard let window else { return }
        if window.isVisible {
            hidePanel()
        } else {
            showPanel()
        }
    }

    func showPanel() {
        guard let window else { return }
        if !defaults.bool(forKey: "hasPositionedPanel") {
            placeTopRight(window)
        } else {
            recoverToVisibleScreen(window)
        }
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        animateAppearance(window)
    }

    func hidePanel() {
        saveFrame()
        window?.orderOut(nil)
    }

    func toggleCompact() {
        guard let window else { return }
        if model.isCompact {
            restoreExpanded()
        } else {
            expandedFrame = window.frame
            defaults.set(NSStringFromRect(window.frame), forKey: "expandedFrame")
            model.isCompact = true
            window.minSize = NSSize(width: 360, height: 46)
            let compact = NSRect(
                x: window.frame.maxX - 360,
                y: window.frame.maxY - 52,
                width: 360,
                height: 52
            )
            animateFrame(window, to: compact)
        }
        defaults.set(model.isCompact, forKey: "isCompact")
    }

    func windowDidMove(_ notification: Notification) { saveFrame() }
    func windowDidResize(_ notification: Notification) { if !model.isCompact { saveFrame() } }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        hidePanel()
        return false
    }

    private func restoreExpanded() {
        guard let window else { return }
        model.isCompact = false
        window.minSize = NSSize(width: 600, height: 400)
        let stored = defaults.string(forKey: "expandedFrame").map(NSRectFromString)
        let target = expandedFrame ?? stored ?? NSRect(x: window.frame.minX, y: window.frame.minY, width: 780, height: 520)
        animateFrame(window, to: target)
    }

    private func restoreFrameOrPlaceTopRight() {
        guard let window else { return }
        if let stored = defaults.string(forKey: "panelFrame") {
            window.setFrame(NSRectFromString(stored), display: false)
            model.isCompact = defaults.bool(forKey: "isCompact")
            if model.isCompact {
                window.minSize = NSSize(width: 360, height: 46)
            }
            recoverToVisibleScreen(window)
        } else {
            placeTopRight(window)
        }
    }

    private func placeTopRight(_ window: NSWindow) {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }
        let visible = screen.visibleFrame
        let origin = NSPoint(x: visible.maxX - window.frame.width - 12, y: visible.maxY - window.frame.height - 10)
        window.setFrameOrigin(origin)
        defaults.set(true, forKey: "hasPositionedPanel")
        saveFrame()
    }

    private func recoverToVisibleScreen(_ window: NSWindow) {
        let intersects = NSScreen.screens.contains { $0.visibleFrame.intersects(window.frame) }
        if !intersects { placeTopRight(window) }
    }

    private func saveFrame() {
        guard let window else { return }
        defaults.set(NSStringFromRect(window.frame), forKey: "panelFrame")
        if !model.isCompact {
            defaults.set(NSStringFromRect(window.frame), forKey: "expandedFrame")
        }
    }

    private func animateAppearance(_ window: NSWindow) {
        guard !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else {
            window.alphaValue = 1
            return
        }
        let finalFrame = window.frame
        var startFrame = finalFrame
        startFrame.origin.x += 8
        startFrame.origin.y += 10
        startFrame.size.width *= 0.985
        startFrame.size.height *= 0.985
        window.setFrame(startFrame, display: false)
        window.alphaValue = 0
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            window.animator().alphaValue = 1
            window.animator().setFrame(finalFrame, display: true)
        }
    }

    private func animateFrame(_ window: NSWindow, to frame: NSRect) {
        if NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            window.setFrame(frame, display: true)
            return
        }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            window.animator().setFrame(frame, display: true)
        }
    }
}
