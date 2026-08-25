import AppKit
import SwiftUI

struct CurlTextField: NSViewRepresentable {
    let value: String
    let placeholder: String
    let onChange: (String) -> Void
    let onCurlPaste: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> PasteAwareTextField {
        let field = PasteAwareTextField()
        field.delegate = context.coordinator
        field.placeholderString = placeholder
        field.font = .monospacedSystemFont(ofSize: 12.5, weight: .regular)
        field.focusRingType = .default
        field.isBezeled = true
        field.bezelStyle = .roundedBezel
        field.lineBreakMode = .byTruncatingMiddle
        field.maximumNumberOfLines = 1
        field.onPaste = { pasted in
            guard context.coordinator.parent.isCurl(pasted) else { return false }
            context.coordinator.parent.onCurlPaste(pasted)
            return true
        }
        field.stringValue = value
        return field
    }

    func updateNSView(_ field: PasteAwareTextField, context: Context) {
        context.coordinator.parent = self
        field.onPaste = { pasted in
            guard context.coordinator.parent.isCurl(pasted) else { return false }
            context.coordinator.parent.onCurlPaste(pasted)
            return true
        }
        if field.stringValue != value {
            field.stringValue = value
        }
    }

    private func isCurl(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.hasPrefix("curl ") ||
            trimmed.hasPrefix("/usr/bin/curl ") ||
            trimmed.hasPrefix("$ curl ") ||
            trimmed.hasPrefix("$ /usr/bin/curl ")
    }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: CurlTextField

        init(parent: CurlTextField) {
            self.parent = parent
        }

        func controlTextDidChange(_ notification: Notification) {
            guard let field = notification.object as? NSTextField else { return }
            parent.onChange(field.stringValue)
        }
    }
}

final class PasteAwareTextField: NSTextField {
    var onPaste: ((String) -> Bool)?

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        let isPaste = event.modifierFlags.intersection(.deviceIndependentFlagsMask) == .command &&
            event.charactersIgnoringModifiers?.lowercased() == "v"
        if isPaste,
           let pasted = NSPasteboard.general.string(forType: .string),
           onPaste?(pasted) == true {
            return true
        }
        return super.performKeyEquivalent(with: event)
    }
}
