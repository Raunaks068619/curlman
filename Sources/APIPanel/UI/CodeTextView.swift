import AppKit
import SwiftUI

struct CodeTextView: View {
    @Binding var text: String
    var isEditable = true
    var placeholder = ""

    var body: some View {
        ZStack(alignment: .topLeading) {
            SyntaxTextEditor(text: $text, isEditable: isEditable)

            if text.isEmpty, !placeholder.isEmpty {
                Text(placeholder)
                    .font(.system(size: 12.5, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .padding(.leading, 54)
                    .padding(.top, 14)
                    .allowsHitTesting(false)
            }
        }
        .background(Color(nsColor: .textBackgroundColor))
        .accessibilityLabel(isEditable ? "Request body editor" : "Response viewer")
    }
}

private struct SyntaxTextEditor: NSViewRepresentable {
    @Binding var text: String
    let isEditable: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let storage = NSTextStorage()
        let layoutManager = NSLayoutManager()
        let container = NSTextContainer(size: NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude))
        container.widthTracksTextView = true
        storage.addLayoutManager(layoutManager)
        layoutManager.addTextContainer(container)

        let editor = NSTextView(frame: .zero, textContainer: container)
        editor.delegate = context.coordinator
        editor.isRichText = false
        editor.importsGraphics = false
        editor.allowsUndo = true
        editor.isAutomaticQuoteSubstitutionEnabled = false
        editor.isAutomaticDashSubstitutionEnabled = false
        editor.isAutomaticTextReplacementEnabled = false
        editor.isAutomaticSpellingCorrectionEnabled = false
        editor.font = NSFont.monospacedSystemFont(ofSize: 12.5, weight: .regular)
        editor.textContainerInset = NSSize(width: 12, height: 12)
        editor.drawsBackground = false
        editor.isVerticallyResizable = true
        editor.isHorizontallyResizable = false
        editor.autoresizingMask = NSView.AutoresizingMask.width
        editor.minSize = NSSize.zero
        editor.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        editor.isEditable = isEditable
        editor.isSelectable = true
        editor.string = text

        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.documentView = editor
        scrollView.hasVerticalRuler = true
        scrollView.rulersVisible = true
        scrollView.verticalRulerView = LineNumberRulerView(textView: editor, scrollView: scrollView)

        context.coordinator.editor = editor
        context.coordinator.highlight(editor)
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        context.coordinator.parent = self
        guard let editor = scrollView.documentView as? NSTextView else { return }
        editor.isEditable = isEditable
        if editor.string != text {
            editor.string = text
            context.coordinator.highlight(editor)
            (scrollView.verticalRulerView as? LineNumberRulerView)?.needsDisplay = true
        }
    }

    @MainActor
    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: SyntaxTextEditor
        weak var editor: NSTextView?
        private var isHighlighting = false

        init(parent: SyntaxTextEditor) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard !isHighlighting, let editor = notification.object as? NSTextView else { return }
            parent.text = editor.string
            highlight(editor)
            (editor.enclosingScrollView?.verticalRulerView as? LineNumberRulerView)?.needsDisplay = true
        }

        func highlight(_ editor: NSTextView) {
            let storage = editor.textStorage ?? NSTextStorage()
            let source = editor.string
            let fullRange = NSRange(location: 0, length: (source as NSString).length)
            let selection = editor.selectedRanges
            let font = NSFont.monospacedSystemFont(ofSize: 12.5, weight: .regular)
            let base: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: NSColor.textColor
            ]

            isHighlighting = true
            storage.beginEditing()
            storage.setAttributes(base, range: fullRange)

            apply(#""(?:\\.|[^"\\])*""#, color: .systemOrange, source: source, storage: storage)
            apply(#""(?:\\.|[^"\\])*"(?=\s*:)"#, color: .systemBlue, source: source, storage: storage)
            apply(#"(?<![\w.])-?\d+(?:\.\d+)?(?:[eE][+-]?\d+)?"#, color: .systemPurple, source: source, storage: storage)
            apply(#"\b(?:true|false|null)\b"#, color: .systemPink, source: source, storage: storage)

            storage.endEditing()
            editor.typingAttributes = base
            editor.selectedRanges = selection
            isHighlighting = false
        }

        private func apply(
            _ pattern: String,
            color: NSColor,
            source: String,
            storage: NSTextStorage
        ) {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { return }
            let range = NSRange(location: 0, length: (source as NSString).length)
            for match in regex.matches(in: source, range: range) {
                storage.addAttribute(.foregroundColor, value: color, range: match.range)
            }
        }
    }
}

private final class LineNumberRulerView: NSRulerView {
    private weak var textView: NSTextView?

    init(textView: NSTextView, scrollView: NSScrollView) {
        self.textView = textView
        super.init(scrollView: scrollView, orientation: .verticalRuler)
        clientView = textView
        ruleThickness = 42
        scrollView.contentView.postsBoundsChangedNotifications = true
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(refresh),
            name: NSView.boundsDidChangeNotification,
            object: scrollView.contentView
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(refresh),
            name: NSText.didChangeNotification,
            object: textView
        )
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func refresh() {
        needsDisplay = true
    }

    override func drawHashMarksAndLabels(in rect: NSRect) {
        guard let textView,
              let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer,
              let scrollView else { return }

        NSColor.controlBackgroundColor.withAlphaComponent(0.55).setFill()
        bounds.fill()

        let visibleRect = scrollView.contentView.bounds
        let glyphRange = layoutManager.glyphRange(forBoundingRect: visibleRect, in: textContainer)
        let characterRange = layoutManager.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)
        let source = textView.string as NSString
        var line = 1
        if characterRange.location > 0 {
            line += source.substring(to: characterRange.location).reduce(0) { $1 == "\n" ? $0 + 1 : $0 }
        }

        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 10.5, weight: .regular),
            .foregroundColor: NSColor.tertiaryLabelColor
        ]
        if source.length == 0 {
            let label = "1" as NSString
            let size = label.size(withAttributes: attributes)
            label.draw(
                at: NSPoint(x: ruleThickness - size.width - 10, y: textView.textContainerInset.height + 1),
                withAttributes: attributes
            )
            return
        }
        var index = characterRange.location
        let end = min(NSMaxRange(characterRange), source.length)

        while index <= end {
            let glyphIndex = layoutManager.glyphIndexForCharacter(at: min(index, max(source.length - 1, 0)))
            let fragment = layoutManager.lineFragmentRect(forGlyphAt: glyphIndex, effectiveRange: nil)
            let y = fragment.minY + textView.textContainerInset.height - visibleRect.minY
            let label = "\(line)" as NSString
            let size = label.size(withAttributes: attributes)
            label.draw(at: NSPoint(x: ruleThickness - size.width - 10, y: y + 1), withAttributes: attributes)

            if index >= source.length { break }
            let range = source.lineRange(for: NSRange(location: index, length: 0))
            let next = NSMaxRange(range)
            if next <= index { break }
            index = next
            line += 1
        }

        NSColor.separatorColor.setFill()
        NSRect(x: ruleThickness - 0.5, y: 0, width: 0.5, height: bounds.height).fill()
    }
}
