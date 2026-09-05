import AppKit
import SwiftUI

@MainActor
final class PanelController: NSWindowController, NSWindowDelegate {
    private static let compactSize = NSSize(width: 420, height: 52)
    private static let expandedMinimumSize = NSSize(width: 600, height: 400)
    private let model: AppModel
    private let onboardingState: OnboardingState
    private let defaults = UserDefaults.standard
    private var expandedFrame: NSRect?

    init(
        model: AppModel,
        onboardingState: OnboardingState,
        shortcutPreferences: ShortcutPreferences,
        registerShortcut: @escaping (GlobalShortcut) -> Bool
    ) {
        self.model = model
        self.onboardingState = onboardingState
        let panel = InteractivePanel(
            contentRect: NSRect(x: 0, y: 0, width: 780, height: 520),
            styleMask: [.titled, .fullSizeContentView, .resizable],
            backing: .buffered,
            defer: false
        )
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.titlebarSeparatorStyle = .none
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isReleasedWhenClosed = false
        panel.minSize = Self.expandedMinimumSize
        Self.hideStandardWindowButtons(on: panel)
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
                onboardingState: onboardingState,
                shortcutPreferences: shortcutPreferences,
                registerShortcut: registerShortcut,
                closeAction: { [weak self] in self?.hidePanel() },
                minimizeAction: { [weak self] in self?.toggleCompact() },
                dragAction: { [weak panel] event in panel?.performDrag(with: event) }
            )
        )
        hostingView.sizingOptions = []
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        let containerView = NSView()
        containerView.wantsLayer = true
        containerView.layer?.cornerRadius = 12
        containerView.layer?.cornerCurve = .continuous
        containerView.layer?.masksToBounds = true
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

    var isPanelVisible: Bool {
        window?.isVisible ?? false
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
        if !onboardingState.isComplete && !model.isCompact {
            configureOnboardingFrame(window)
        }
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

    func showOnboarding() {
        if model.isCompact {
            restoreExpanded()
        }
        showPanel()
    }

    private func configureOnboardingFrame(_ window: NSWindow) {
        let targetSize = NSSize(width: 780, height: 520)
        guard window.frame.size != targetSize else { return }
        let current = window.frame
        let target = NSRect(
            x: current.maxX - targetSize.width,
            y: current.maxY - targetSize.height,
            width: targetSize.width,
            height: targetSize.height
        )
        window.setFrame(target, display: false)
    }

    func toggleCompact() {
        guard let window else { return }
        if model.isCompact {
            restoreExpanded()
        } else {
            expandedFrame = window.frame
            defaults.set(NSStringFromRect(window.frame), forKey: "expandedFrame")
            model.isCompact = true
            configureCompactWindow(window)
            let compact = compactFrame(anchoredTo: window.frame)
            animateFrame(window, to: compact)
        }
        defaults.set(model.isCompact, forKey: "isCompact")
    }

    func windowDidMove(_ notification: Notification) { saveFrame() }
    func windowDidResize(_ notification: Notification) { if !model.isCompact { saveFrame() } }

    func windowWillResize(_ sender: NSWindow, to frameSize: NSSize) -> NSSize {
        model.isCompact ? Self.compactSize : frameSize
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        hidePanel()
        return false
    }

    private func restoreExpanded() {
        guard let window else { return }
        model.isCompact = false
        configureExpandedWindow(window)
        let stored = defaults.string(forKey: "expandedFrame").map(NSRectFromString)
        let target = expandedFrame ?? stored ?? NSRect(x: window.frame.minX, y: window.frame.minY, width: 780, height: 520)
        animateFrame(window, to: target)
    }

    private func restoreFrameOrPlaceTopRight() {
        guard let window else { return }
        model.isCompact = defaults.bool(forKey: "isCompact")
        if model.isCompact {
            let storedExpanded = defaults.string(forKey: "expandedFrame").map(NSRectFromString)
                ?? defaults.string(forKey: "panelFrame").map(NSRectFromString)
                ?? window.frame
            expandedFrame = storedExpanded
            let storedCompact = defaults.string(forKey: "compactFrame").map(NSRectFromString)
            let compact = storedCompact.map(normalizedCompactFrame) ?? compactFrame(anchoredTo: storedExpanded)
            configureCompactWindow(window)
            window.setFrame(compact, display: false)
            recoverToVisibleScreen(window)
        } else if let stored = defaults.string(forKey: "panelFrame") {
            configureExpandedWindow(window)
            window.setFrame(NSRectFromString(stored), display: false)
            recoverToVisibleScreen(window)
        } else {
            configureExpandedWindow(window)
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
        if model.isCompact {
            defaults.set(NSStringFromRect(normalizedCompactFrame(window.frame)), forKey: "compactFrame")
        } else {
            defaults.set(NSStringFromRect(window.frame), forKey: "panelFrame")
            defaults.set(NSStringFromRect(window.frame), forKey: "expandedFrame")
        }
    }

    private func configureCompactWindow(_ window: NSWindow) {
        window.styleMask.remove([.titled, .fullSizeContentView, .resizable])
        window.isMovableByWindowBackground = true
        window.minSize = Self.compactSize
        window.maxSize = Self.compactSize
        window.invalidateShadow()
    }

    private func configureExpandedWindow(_ window: NSWindow) {
        window.styleMask.insert([.titled, .fullSizeContentView, .resizable])
        window.isMovableByWindowBackground = false
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.titlebarSeparatorStyle = .none
        Self.hideStandardWindowButtons(on: window)
        window.minSize = Self.expandedMinimumSize
        window.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        window.invalidateShadow()
    }

    private static func hideStandardWindowButtons(on window: NSWindow) {
        window.standardWindowButton(.closeButton)?.isHidden = true
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isHidden = true
    }

    private func compactFrame(anchoredTo frame: NSRect) -> NSRect {
        NSRect(
            x: frame.maxX - Self.compactSize.width,
            y: frame.maxY - Self.compactSize.height,
            width: Self.compactSize.width,
            height: Self.compactSize.height
        )
    }

    private func normalizedCompactFrame(_ frame: NSRect) -> NSRect {
        NSRect(origin: frame.origin, size: Self.compactSize)
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
        if !model.isCompact {
            startFrame.size.width *= 0.985
            startFrame.size.height *= 0.985
        }
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
