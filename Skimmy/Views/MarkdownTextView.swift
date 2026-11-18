import SwiftUI
import AppKit

/// SwiftUI wrapper around the editor. The text view itself lives in `EditorController`
/// so it survives switching between Read, Split and Edit (undo history, selection and
/// scroll position are kept).
struct MarkdownTextView: NSViewRepresentable {
    @Binding var text: String
    var fontSize: Double
    let controller: EditorController

    func makeNSView(context: Context) -> NSScrollView {
        controller.onTextChange = { [binding = $text] in binding.wrappedValue = $0 }
        return controller.makeScrollView(text: text, fontSize: fontSize)
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        controller.onTextChange = { [binding = $text] in binding.wrappedValue = $0 }
        controller.update(text: text, fontSize: fontSize)
    }
}

@MainActor
final class EditorController: NSObject, NSTextViewDelegate {
    struct ScrollPosition {
        let line: Int
        let atEnd: Bool
    }

    var onTextChange: ((String) -> Void)?
    var onScroll: ((ScrollPosition) -> Void)?

    private var scrollView: NSScrollView?
    private weak var textView: NSTextView?
    private var lastSyncedText = ""
    private var fontSize: Double = 0
    private var scrollReportQueued = false

    private static let maxLineWidth: CGFloat = 860
    private static let minHorizontalInset: CGFloat = 22
    private static let verticalInset: CGFloat = 14

    // MARK: - View lifecycle

    func makeScrollView(text: String, fontSize: Double) -> NSScrollView {
        if let existing = self.scrollView {
            update(text: text, fontSize: fontSize)
            return existing
        }

        let scrollView = NSTextView.scrollableTextView()
        scrollView.drawsBackground = false
        scrollView.autohidesScrollers = true
        self.scrollView = scrollView

        guard let textView = scrollView.documentView as? NSTextView else {
            // scrollableTextView() is documented to always return an NSScrollView
            // containing an NSTextView; this path should be unreachable in practice.
            return scrollView
        }
        self.textView = textView

        textView.isRichText = false
        textView.allowsUndo = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isAutomaticLinkDetectionEnabled = false
        textView.usesFindBar = true
        textView.isIncrementalSearchingEnabled = true
        textView.drawsBackground = false
        textView.insertionPointColor = .controlAccentColor
        textView.textContainerInset = NSSize(width: Self.minHorizontalInset, height: Self.verticalInset)
        textView.delegate = self

        textView.string = text
        lastSyncedText = text
        self.fontSize = fontSize
        applyFont()

        let clipView = scrollView.contentView
        clipView.postsBoundsChangedNotifications = true
        clipView.postsFrameChangedNotifications = true
        NotificationCenter.default.addObserver(
            self, selector: #selector(clipViewBoundsDidChange(_:)),
            name: NSView.boundsDidChangeNotification, object: clipView
        )
        NotificationCenter.default.addObserver(
            self, selector: #selector(clipViewFrameDidChange(_:)),
            name: NSView.frameDidChangeNotification, object: clipView
        )

        return scrollView
    }

    func update(text: String, fontSize: Double) {
        guard let textView else { return }

        // `lastSyncedText` shares storage with the string we last handed to SwiftUI,
        // so this comparison is O(1) while typing; it only walks the text when the
        // document changed from outside the editor (revert, external edit).
        if text != lastSyncedText {
            lastSyncedText = text
            let caret = textView.selectedRange().location
            textView.string = text
            applyParagraphStyle()
            textView.setSelectedRange(NSRange(location: min(caret, (text as NSString).length), length: 0))
        }

        if fontSize != self.fontSize {
            self.fontSize = fontSize
            applyFont()
        }
    }

    func focus() {
        guard let textView, let window = textView.window else { return }
        window.makeFirstResponder(textView)
    }

    // MARK: - Appearance

    private var paragraphStyle: NSParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.lineSpacing = (fontSize * 0.3).rounded()
        return style
    }

    private func applyFont() {
        guard let textView else { return }
        // Monospaced type reads larger than proportional type at the same point size;
        // scale it down so the editor and the preview look the same size side by side.
        let font = NSFont.monospacedSystemFont(ofSize: (fontSize * 0.875).rounded(), weight: .regular)
        textView.font = font
        textView.typingAttributes = [
            .font: font,
            .foregroundColor: NSColor.textColor,
            .paragraphStyle: paragraphStyle,
        ]
        applyParagraphStyle()
    }

    private func applyParagraphStyle() {
        guard let textView, let storage = textView.textStorage else { return }
        let style = paragraphStyle
        textView.defaultParagraphStyle = style
        storage.addAttribute(.paragraphStyle, value: style, range: NSRange(location: 0, length: storage.length))
    }

    /// Keeps lines at a comfortable length by centring the text column in wide windows.
    private func updateInsets() {
        guard let scrollView, let textView else { return }
        let width = scrollView.contentView.bounds.width
        let horizontal = max(Self.minHorizontalInset, ((width - Self.maxLineWidth) / 2).rounded(.down))
        if textView.textContainerInset.width != horizontal {
            textView.textContainerInset = NSSize(width: horizontal, height: Self.verticalInset)
        }
    }

    @objc private func clipViewFrameDidChange(_ notification: Notification) {
        updateInsets()
    }

    // MARK: - Scrolling by source line

    var scrollPosition: ScrollPosition? {
        guard let scrollView, let textView, let storage = textView.textStorage else { return nil }
        let visible = scrollView.contentView.bounds
        let documentHeight = textView.frame.height
        let atEnd = documentHeight > visible.height + 1 && visible.maxY >= documentHeight - 2
        if visible.minY <= 1 {
            return ScrollPosition(line: 0, atEnd: atEnd)
        }
        let point = NSPoint(x: textView.textContainerOrigin.x + 2, y: visible.minY + 2)
        let index = textView.characterIndexForInsertion(at: point)
        return ScrollPosition(line: Self.lineIndex(in: storage.mutableString, at: index), atEnd: atEnd)
    }

    @objc private func clipViewBoundsDidChange(_ notification: Notification) {
        // Scroll events arrive many times per frame; report at most once per main-loop turn.
        guard !scrollReportQueued else { return }
        scrollReportQueued = true
        Task { [weak self] in
            guard let self else { return }
            self.scrollReportQueued = false
            guard self.textView?.window != nil, let position = self.scrollPosition else { return }
            self.onScroll?(position)
        }
    }

    /// Puts the caret at the start of `line` and scrolls it to the top of the editor.
    func scrollToLine(_ line: Int) {
        guard let scrollView, let textView, let storage = textView.textStorage else { return }
        let location = Self.location(ofLine: line, in: storage.mutableString)
        let range = NSRange(location: location, length: 0)
        textView.setSelectedRange(range)
        textView.scrollRangeToVisible(range)

        guard let window = textView.window else { return }
        let onScreen = textView.firstRect(forCharacterRange: range, actualRange: nil)
        guard onScreen != .zero else { return }
        let inView = textView.convert(window.convertFromScreen(onScreen), from: nil)
        let clipView = scrollView.contentView
        let maxY = max(0, textView.frame.height - clipView.bounds.height)
        let y = min(maxY, max(0, inView.minY - Self.verticalInset))
        clipView.scroll(to: NSPoint(x: clipView.bounds.minX, y: y))
        scrollView.reflectScrolledClipView(clipView)
    }

    /// Number of line breaks before `location`. `\r\n` counts once.
    private static func lineIndex(in string: NSString, at location: Int) -> Int {
        let end = min(location, string.length)
        var buffer = [unichar](repeating: 0, count: 4096)
        var position = 0
        var line = 0
        var previousWasCR = false
        while position < end {
            let length = min(buffer.count, end - position)
            string.getCharacters(&buffer, range: NSRange(location: position, length: length))
            for i in 0..<length {
                let character = buffer[i]
                if character == 0x0A {
                    if !previousWasCR { line += 1 }
                    previousWasCR = false
                } else if character == 0x0D {
                    line += 1
                    previousWasCR = true
                } else {
                    previousWasCR = false
                }
            }
            position += length
        }
        return line
    }

    /// UTF-16 offset of the first character of `line`.
    private static func location(ofLine line: Int, in string: NSString) -> Int {
        guard line > 0 else { return 0 }
        let total = string.length
        var buffer = [unichar](repeating: 0, count: 4096)
        var position = 0
        var current = 0
        var previousWasCR = false
        while position < total {
            let length = min(buffer.count, total - position)
            string.getCharacters(&buffer, range: NSRange(location: position, length: length))
            for i in 0..<length {
                let character = buffer[i]
                if previousWasCR {
                    previousWasCR = false
                    if character == 0x0A {
                        // Second half of a \r\n pair: the line starts after it.
                        if current == line { return position + i + 1 }
                        continue
                    }
                    if current == line { return position + i }
                }
                if character == 0x0A {
                    current += 1
                    if current == line { return position + i + 1 }
                } else if character == 0x0D {
                    current += 1
                    previousWasCR = true
                }
            }
            position += length
        }
        return total
    }

    // MARK: - Find

    func performFind(_ action: NSTextFinder.Action) {
        guard let textView else { return }
        if action == .showFindInterface || action == .showReplaceInterface {
            textView.window?.makeFirstResponder(textView)
        }
        let sender = NSMenuItem()
        sender.tag = action.rawValue
        textView.performTextFinderAction(sender)
    }

    // MARK: - Formatting

    /// Wraps the selection in `marker` (for example `**`), or removes the markers
    /// if the selection is already wrapped. With nothing selected, inserts a placeholder.
    func toggleWrap(_ marker: String, placeholder: String) {
        guard let textView, let storage = textView.textStorage else { return }
        let string = storage.mutableString
        let selection = textView.selectedRange()
        let markerLength = (marker as NSString).length
        let selected = string.substring(with: selection)

        let before = NSRange(location: selection.location - markerLength, length: markerLength)
        let after = NSRange(location: NSMaxRange(selection), length: markerLength)
        if before.location >= 0, NSMaxRange(after) <= string.length,
           string.substring(with: before) == marker, string.substring(with: after) == marker {
            let outer = NSRange(location: before.location, length: selection.length + 2 * markerLength)
            textView.insertText(selected, replacementRange: outer)
            textView.setSelectedRange(NSRange(location: outer.location, length: selection.length))
            return
        }

        let inner = selected.isEmpty ? placeholder : selected
        textView.insertText(marker + inner + marker, replacementRange: selection)
        textView.setSelectedRange(NSRange(location: selection.location + markerLength, length: (inner as NSString).length))
    }

    func insertLink() {
        guard let textView, let storage = textView.textStorage else { return }
        let selection = textView.selectedRange()
        let selected = storage.mutableString.substring(with: selection)
        let isURL = selected.hasPrefix("http://") || selected.hasPrefix("https://")

        let label = (selected.isEmpty || isURL) ? "link text" : selected
        let destination = isURL ? selected : "https://"
        textView.insertText("[\(label)](\(destination))", replacementRange: selection)

        // Select the part the user still has to fill in.
        let labelLength = (label as NSString).length
        if selected.isEmpty || isURL {
            textView.setSelectedRange(NSRange(location: selection.location + 1, length: labelLength))
        } else {
            textView.setSelectedRange(NSRange(
                location: selection.location + labelLength + 3,
                length: (destination as NSString).length
            ))
        }
    }

    // MARK: - NSTextViewDelegate

    func textDidChange(_ notification: Notification) {
        guard let textView = notification.object as? NSTextView else { return }
        let text = textView.string
        lastSyncedText = text
        onTextChange?(text)
    }

    func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        guard commandSelector == #selector(NSResponder.insertNewline(_:)) else { return false }
        return continueList(in: textView)
    }

    private static let listItemRegex = try? NSRegularExpression(
        pattern: #"^([ \t]*)(?:([-*+])|(\d{1,9})([.)]))([ \t]+)(\[[ xX]\][ \t]+)?"#
    )

    /// Return inside a list item starts the next item (bullets, numbers and task boxes).
    /// Return on an empty item ends the list.
    private func continueList(in textView: NSTextView) -> Bool {
        guard !textView.hasMarkedText(),
              let storage = textView.textStorage,
              let regex = Self.listItemRegex else { return false }
        let selection = textView.selectedRange()
        guard selection.length == 0 else { return false }

        let string = storage.mutableString
        var lineStart = 0
        var lineEnd = 0
        var contentsEnd = 0
        string.getLineStart(&lineStart, end: &lineEnd, contentsEnd: &contentsEnd,
                            for: NSRange(location: selection.location, length: 0))

        let head = string.substring(with: NSRange(location: lineStart, length: selection.location - lineStart)) as NSString
        guard let match = regex.firstMatch(in: head as String, range: NSRange(location: 0, length: head.length)) else {
            return false
        }

        if match.range.length == head.length && selection.location == contentsEnd {
            textView.insertText("", replacementRange: NSRange(location: lineStart, length: contentsEnd - lineStart))
            return true
        }

        let indent = head.substring(with: match.range(at: 1))
        let marker: String
        if match.range(at: 2).location != NSNotFound {
            marker = head.substring(with: match.range(at: 2))
        } else {
            let number = Int(head.substring(with: match.range(at: 3))) ?? 0
            marker = "\(number + 1)" + head.substring(with: match.range(at: 4))
        }
        let spacing = head.substring(with: match.range(at: 5))
        let taskBox = match.range(at: 6).location != NSNotFound ? "[ ] " : ""
        textView.insertText("\n" + indent + marker + spacing + taskBox, replacementRange: selection)
        return true
    }
}
