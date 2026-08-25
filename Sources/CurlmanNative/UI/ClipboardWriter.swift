import AppKit

@MainActor
protocol ClipboardWriting {
    @discardableResult
    func write(_ string: String) -> Bool
}

@MainActor
struct SystemClipboardWriter: ClipboardWriting {
    func write(_ string: String) -> Bool {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        return pasteboard.setString(string, forType: .string)
    }
}
