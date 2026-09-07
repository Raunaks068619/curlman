import AppKit
import SwiftUI

enum CodeLanguage: Sendable {
    case plainText
    case json
}

struct CodeTextView: View {
    @Binding var text: String
    var isEditable = true
    var placeholder = ""
    var language: CodeLanguage = .plainText
    var allowsSearch = true
    var contextID = "default"
    @State private var findRequest = 0

    var body: some View {
        ZStack(alignment: .topTrailing) {
            SyntaxTextEditor(
                text: $text,
                isEditable: isEditable,
                language: language,
                contextID: contextID,
                findRequest: findRequest
            )

            if text.isEmpty, !placeholder.isEmpty {
                Text(placeholder)
                    .font(.system(size: 12.5, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .padding(.leading, 60)
                    .padding(.top, 14)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .allowsHitTesting(false)
            }

            if allowsSearch {
                Button {
                    findRequest += 1
                } label: {
                    Image(systemName: "magnifyingglass")
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.borderless)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                .keyboardShortcut("f", modifiers: .command)
                .padding(8)
                .help("Find in content (Command-F)")
                .accessibilityLabel("Find in content")
            }
        }
        .background(Color(nsColor: .textBackgroundColor))
    }
}

private struct SyntaxTextEditor: NSViewRepresentable {
    @Binding var text: String
    let isEditable: Bool
    let language: CodeLanguage
    let contextID: String
    let findRequest: Int

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> CodeEditorContainerView {
        let storage = NSTextStorage()
        let layoutManager = FoldingLayoutManager()
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
        editor.usesFindBar = true
        editor.isIncrementalSearchingEnabled = true
        editor.string = text

        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.findBarPosition = .aboveHorizontalRuler
        scrollView.documentView = editor

        let gutter = LineNumberGutterView(textView: editor, scrollView: scrollView)
        let editorContainer = CodeEditorContainerView(scrollView: scrollView, editor: editor, gutter: gutter)

        context.coordinator.editor = editor
        context.coordinator.gutter = gutter
        context.coordinator.layoutManager = layoutManager
        context.coordinator.lastContextID = contextID
        gutter.toggleFold = { [weak coordinator = context.coordinator] offset in
            coordinator?.toggleFold(at: offset)
        }
        context.coordinator.refreshPresentation(resetFolds: true)
        context.coordinator.highlight(editor)
        return editorContainer
    }

    func updateNSView(_ editorContainer: CodeEditorContainerView, context: Context) {
        context.coordinator.parent = self
        let editor = editorContainer.editor
        editor.isEditable = isEditable

        let contextChanged = context.coordinator.lastContextID != contextID
        if contextChanged {
            context.coordinator.lastContextID = contextID
        }
        if editor.string != text {
            editor.string = text
            context.coordinator.refreshPresentation(resetFolds: true)
            context.coordinator.highlight(editor)
        } else if contextChanged {
            context.coordinator.refreshPresentation(resetFolds: true)
        }

        if context.coordinator.lastFindRequest != findRequest {
            context.coordinator.lastFindRequest = findRequest
            context.coordinator.showFindInterface()
        }
    }

    @MainActor
    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: SyntaxTextEditor
        weak var editor: NSTextView?
        weak var gutter: LineNumberGutterView?
        weak var layoutManager: FoldingLayoutManager?
        var lastContextID = ""
        var lastFindRequest = 0
        private var regions: [JSONFoldRegion] = []
        private var collapsedOffsets: Set<Int> = []
        private var isHighlighting = false
        private let scanner = JSONStructureScanner()

        init(parent: SyntaxTextEditor) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard !isHighlighting, let editor = notification.object as? NSTextView else { return }
            parent.text = editor.string
            refreshPresentation(resetFolds: true)
            highlight(editor)
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard let editor = notification.object as? NSTextView,
                  !collapsedOffsets.isEmpty else { return }
            let selections = editor.selectedRanges.compactMap { $0.rangeValue }
            let offsetsToExpand = regions.compactMap { region -> Int? in
                guard collapsedOffsets.contains(region.openingOffset) else { return nil }
                return selections.contains(where: { selectionIntersects($0, region.hiddenRange) })
                    ? region.openingOffset
                    : nil
            }
            guard !offsetsToExpand.isEmpty else { return }
            collapsedOffsets.subtract(offsetsToExpand)
            applyFoldState()
        }

        func toggleFold(at openingOffset: Int) {
            if collapsedOffsets.contains(openingOffset) {
                collapsedOffsets.remove(openingOffset)
            } else {
                collapsedOffsets.insert(openingOffset)
            }
            applyFoldState()
        }

        func showFindInterface() {
            guard let editor else { return }
            editor.window?.makeFirstResponder(editor)
            let sender = NSMenuItem()
            sender.tag = NSTextFinder.Action.showFindInterface.rawValue
            editor.performTextFinderAction(sender)
        }

        func refreshPresentation(resetFolds: Bool) {
            guard let editor else { return }
            if resetFolds { collapsedOffsets.removeAll() }
            regions = parent.language == .json ? scanner.regions(in: editor.string) : []
            collapsedOffsets.formIntersection(Set(regions.map(\.openingOffset)))
            applyFoldState()
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

            if parent.language == .json {
                apply(#""(?:\\.|[^"\\])*""#, color: .systemOrange, source: source, storage: storage)
                apply(#""(?:\\.|[^"\\])*"(?=\s*:)"#, color: .systemBlue, source: source, storage: storage)
                apply(#"(?<![\w.])-?\d+(?:\.\d+)?(?:[eE][+-]?\d+)?"#, color: .systemPurple, source: source, storage: storage)
                apply(#"\b(?:true|false|null)\b"#, color: .systemPink, source: source, storage: storage)
            }

            storage.endEditing()
            editor.typingAttributes = base
            editor.selectedRanges = selection
            isHighlighting = false
        }

        private func applyFoldState() {
            let collapsed = regions.filter { collapsedOffsets.contains($0.openingOffset) }
            layoutManager?.setCollapsedRegions(collapsed)
            gutter?.update(regions: regions, collapsedOffsets: collapsedOffsets)
        }

        private func selectionIntersects(_ selection: NSRange, _ hiddenRange: NSRange) -> Bool {
            if selection.length == 0 {
                return NSLocationInRange(selection.location, hiddenRange)
            }
            return NSIntersectionRange(selection, hiddenRange).length > 0
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

private final class FoldingLayoutManager: NSLayoutManager, NSLayoutManagerDelegate {
    private var collapsedRegions: [JSONFoldRegion] = []

    override init() {
        super.init()
        delegate = self
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        delegate = self
    }

    func setCollapsedRegions(_ regions: [JSONFoldRegion]) {
        collapsedRegions = regions
        guard let textStorage else { return }
        let range = NSRange(location: 0, length: textStorage.length)
        invalidateGlyphs(forCharacterRange: range, changeInLength: 0, actualCharacterRange: nil)
        invalidateLayout(forCharacterRange: range, actualCharacterRange: nil)
    }

    func layoutManager(
        _ layoutManager: NSLayoutManager,
        shouldGenerateGlyphs glyphs: UnsafePointer<CGGlyph>,
        properties: UnsafePointer<NSLayoutManager.GlyphProperty>,
        characterIndexes: UnsafePointer<Int>,
        font: NSFont,
        forGlyphRange glyphRange: NSRange
    ) -> Int {
        guard !collapsedRegions.isEmpty else { return 0 }

        let updatedGlyphs = Array(UnsafeBufferPointer(start: glyphs, count: glyphRange.length))
        var updatedProperties = Array(UnsafeBufferPointer(start: properties, count: glyphRange.length))
        let indexes = Array(UnsafeBufferPointer(start: characterIndexes, count: glyphRange.length))
        for index in updatedGlyphs.indices {
            let characterIndex = indexes[index]
            guard collapsedRegions.contains(where: { NSLocationInRange(characterIndex, $0.hiddenRange) }) else {
                continue
            }
            updatedProperties[index] = .null
        }

        updatedGlyphs.withUnsafeBufferPointer { glyphBuffer in
            updatedProperties.withUnsafeBufferPointer { propertyBuffer in
                indexes.withUnsafeBufferPointer { indexBuffer in
                    guard let glyphBase = glyphBuffer.baseAddress,
                          let propertyBase = propertyBuffer.baseAddress,
                          let indexBase = indexBuffer.baseAddress else { return }
                    layoutManager.setGlyphs(
                        glyphBase,
                        properties: propertyBase,
                        characterIndexes: indexBase,
                        font: font,
                        forGlyphRange: glyphRange
                    )
                }
            }
        }
        return glyphRange.length
    }

    override func drawGlyphs(forGlyphRange glyphsToShow: NSRange, at origin: NSPoint) {
        super.drawGlyphs(forGlyphRange: glyphsToShow, at: origin)
        guard let textContainer = textContainers.first else { return }

        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 11.5, weight: .regular),
            .foregroundColor: NSColor.secondaryLabelColor
        ]
        for region in collapsedRegions where region.openingOffset < (textStorage?.length ?? 0) {
            let openingGlyph = glyphIndexForCharacter(at: region.openingOffset)
            guard NSLocationInRange(openingGlyph, glyphsToShow) else { continue }
            let braceRect = boundingRect(
                forGlyphRange: NSRange(location: openingGlyph, length: 1),
                in: textContainer
            )
            let summary = " … \(region.itemCount) \(region.kind.itemLabel)" as NSString
            summary.draw(
                at: NSPoint(x: origin.x + braceRect.maxX + 3, y: origin.y + braceRect.minY),
                withAttributes: attributes
            )
        }
    }
}

private final class CodeEditorContainerView: NSView {
    let scrollView: NSScrollView
    let editor: NSTextView
    let gutter: LineNumberGutterView

    init(scrollView: NSScrollView, editor: NSTextView, gutter: LineNumberGutterView) {
        self.scrollView = scrollView
        self.editor = editor
        self.gutter = gutter
        super.init(frame: .zero)

        wantsLayer = true
        layer?.masksToBounds = true
        gutter.translatesAutoresizingMaskIntoConstraints = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(gutter)
        addSubview(scrollView)

        NSLayoutConstraint.activate([
            gutter.leadingAnchor.constraint(equalTo: leadingAnchor),
            gutter.topAnchor.constraint(equalTo: topAnchor),
            gutter.bottomAnchor.constraint(equalTo: bottomAnchor),
            gutter.widthAnchor.constraint(equalToConstant: 48),
            scrollView.leadingAnchor.constraint(equalTo: gutter.trailingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private final class LineNumberGutterView: NSView {
    private weak var textView: NSTextView?
    private weak var scrollView: NSScrollView?
    private var regions: [JSONFoldRegion] = []
    private var collapsedOffsets: Set<Int> = []
    private var foldButtons: [Int: NSButton] = [:]
    var toggleFold: ((Int) -> Void)?

    init(textView: NSTextView, scrollView: NSScrollView) {
        self.textView = textView
        self.scrollView = scrollView
        super.init(frame: .zero)
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

    override var isFlipped: Bool { true }

    func update(regions: [JSONFoldRegion], collapsedOffsets: Set<Int>) {
        self.regions = regions
        self.collapsedOffsets = collapsedOffsets
        rebuildFoldButtons()
        needsDisplay = true
    }

    @objc private func refresh() {
        positionFoldButtons()
        needsDisplay = true
    }

    @objc private func foldButtonPressed(_ sender: NSButton) {
        toggleFold?(sender.tag)
    }

    override func layout() {
        super.layout()
        positionFoldButtons()
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let textView,
              let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer,
              let scrollView else { return }

        NSColor.underPageBackgroundColor.setFill()
        bounds.fill()
        NSColor.separatorColor.withAlphaComponent(0.7).setFill()
        NSRect(x: bounds.maxX - 0.5, y: bounds.minY, width: 0.5, height: bounds.height).fill()

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
            drawLineNumber(1, y: textView.textContainerInset.height + 1, attributes: attributes)
            return
        }
        var index = characterRange.location
        let end = min(NSMaxRange(characterRange), source.length)

        while index <= end {
            if !isHidden(characterOffset: index) {
                let glyphIndex = layoutManager.glyphIndexForCharacter(at: min(index, max(source.length - 1, 0)))
                let fragment = layoutManager.lineFragmentRect(forGlyphAt: glyphIndex, effectiveRange: nil)
                let y = fragment.minY + textView.textContainerInset.height - visibleRect.minY
                drawLineNumber(line, y: y + 1, attributes: attributes)
            }

            if index >= source.length { break }
            let range = source.lineRange(for: NSRange(location: index, length: 0))
            let next = NSMaxRange(range)
            if next <= index { break }
            index = next
            line += 1
        }
    }

    private func drawLineNumber(_ line: Int, y: CGFloat, attributes: [NSAttributedString.Key: Any]) {
        let label = "\(line)" as NSString
        let size = label.size(withAttributes: attributes)
        label.draw(at: NSPoint(x: bounds.width - size.width - 8, y: y), withAttributes: attributes)
    }

    private func rebuildFoldButtons() {
        let activeOffsets = Set(regions.map(\.openingOffset))
        let staleOffsets = foldButtons.keys.filter { !activeOffsets.contains($0) }
        for offset in staleOffsets {
            foldButtons.removeValue(forKey: offset)?.removeFromSuperview()
        }
        for region in regions where foldButtons[region.openingOffset] == nil {
            let button = NSButton()
            button.isBordered = false
            button.focusRingType = .none
            button.imagePosition = .imageOnly
            button.target = self
            button.action = #selector(foldButtonPressed(_:))
            button.tag = region.openingOffset
            addSubview(button)
            foldButtons[region.openingOffset] = button
        }
        positionFoldButtons()
    }

    private func positionFoldButtons() {
        guard let textView,
              let layoutManager = textView.layoutManager,
              let scrollView else { return }
        let visibleRect = scrollView.contentView.bounds

        for region in regions {
            guard let button = foldButtons[region.openingOffset] else { continue }
            let hiddenByParent = regions.contains { parent in
                parent.openingOffset != region.openingOffset &&
                    collapsedOffsets.contains(parent.openingOffset) &&
                    NSLocationInRange(region.openingOffset, parent.hiddenRange)
            }
            guard !hiddenByParent, region.openingOffset < textView.string.utf16.count else {
                button.isHidden = true
                continue
            }
            let glyphIndex = layoutManager.glyphIndexForCharacter(at: region.openingOffset)
            let fragment = layoutManager.lineFragmentRect(forGlyphAt: glyphIndex, effectiveRange: nil)
            let y = fragment.minY + textView.textContainerInset.height - visibleRect.minY - 1
            button.frame = NSRect(x: 2, y: y, width: 16, height: 16)
            button.isHidden = y < -16 || y > bounds.height
            let collapsed = collapsedOffsets.contains(region.openingOffset)
            button.image = NSImage(
                systemSymbolName: collapsed ? "chevron.right" : "chevron.down",
                accessibilityDescription: nil
            )
            button.contentTintColor = .secondaryLabelColor
            button.toolTip = "\(collapsed ? "Expand" : "Collapse") \(region.kind.rawValue), \(region.itemCount) \(region.kind.itemLabel)"
            button.setAccessibilityLabel("\(collapsed ? "Expand" : "Collapse") \(region.kind.rawValue) on line \(region.openingLine)")
        }
    }

    private func isHidden(characterOffset: Int) -> Bool {
        regions.contains {
            collapsedOffsets.contains($0.openingOffset) && NSLocationInRange(characterOffset, $0.hiddenRange)
        }
    }
}
