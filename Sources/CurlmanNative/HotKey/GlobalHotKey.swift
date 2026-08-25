import Carbon.HIToolbox
import Foundation

final class GlobalHotKey: @unchecked Sendable {
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
    private let action: @MainActor @Sendable () -> Void

    init(action: @escaping @MainActor @Sendable () -> Void) {
        self.action = action
    }

    deinit {
        unregister()
    }

    @discardableResult
    func register(_ shortcut: GlobalShortcut = .defaultShortcut) -> Bool {
        guard installEventHandlerIfNeeded() else { return false }
        if hotKeyRef != nil, registeredShortcut == shortcut { return true }

        var candidateRef: EventHotKeyRef?
        let identifier = EventHotKeyID(signature: OSType(0x4355524C), id: 1) // CURL
        let status = RegisterEventHotKey(
            shortcut.keyCode,
            shortcut.modifiers,
            identifier,
            GetApplicationEventTarget(),
            0,
            &candidateRef
        )
        guard status == noErr, let candidateRef else { return false }

        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        hotKeyRef = candidateRef
        registeredShortcut = shortcut
        return true
    }

    private var registeredShortcut: GlobalShortcut?

    private func installEventHandlerIfNeeded() -> Bool {
        guard eventHandlerRef == nil else { return true }
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let pointer = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        let handlerStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            { _, _, userData in
                guard let userData else { return OSStatus(eventNotHandledErr) }
                let hotKey = Unmanaged<GlobalHotKey>.fromOpaque(userData).takeUnretainedValue()
                Task { @MainActor in hotKey.action() }
                return noErr
            },
            1,
            &eventType,
            pointer,
            &eventHandlerRef
        )
        return handlerStatus == noErr
    }

    func unregister() {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        if let eventHandlerRef { RemoveEventHandler(eventHandlerRef) }
        hotKeyRef = nil
        eventHandlerRef = nil
        registeredShortcut = nil
    }
}
