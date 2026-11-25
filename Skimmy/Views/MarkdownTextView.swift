import SwiftUI
import AppKit

final class SourceEditorProxy {
    weak var textView: NSTextView?
    var commit: (() -> Void)?

    func find(_ action: NSTextFinder.Action = .showFindInterface) {
        guard let textView else { return }
        if action == .showFindInterface {
            textView.window?.makeFirstResponder(textView)
        }
        let item = NSMenuItem()
        item.tag = action.rawValue
        textView.performTextFinderAction(item)
    }

    func finishComposition() {
        guard let textView, textView.hasMarkedText() else { return }
        textView.unmarkText()
        commit?()
    }
}

struct MarkdownTextView: NSViewRepresentable {
    @Binding var text: String
    var fontSize: Double
    let isEditable: Bool
    let proxy: SourceEditorProxy

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        guard let textView = scrollView.documentView as? NSTextView else { return scrollView }

        textView.isRichText = false
        // FileDocument registers the binding changes in the window's undo manager.
        textView.allowsUndo = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isAutomaticLinkDetectionEnabled = false
        textView.usesFindBar = true
        textView.isEditable = isEditable
        textView.isSelectable = true

        textView.textContainerInset = NSSize(width: 24, height: 24)
        textView.font = .monospacedSystemFont(ofSize: fontSize, weight: .regular)
        textView.string = text
        textView.setAccessibilityLabel("Markdown source")
        textView.delegate = context.coordinator

        proxy.textView = textView
        proxy.commit = { [weak coordinator = context.coordinator, weak textView] in
            guard let textView else { return }
            coordinator?.commit(textView)
        }

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }

        let coordinator = context.coordinator
        coordinator.text = $text
        if textView.isEditable != isEditable {
            textView.isEditable = isEditable
        }
        coordinator.updateText(in: textView, scrollView: scrollView)

        if textView.font?.pointSize != CGFloat(fontSize) {
            textView.font = .monospacedSystemFont(ofSize: fontSize, weight: .regular)
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var text: Binding<String>
        private var displayedText: String

        init(text: Binding<String>) {
            self.text = text
            displayedText = text.wrappedValue
        }

        func updateText(in textView: NSTextView, scrollView: NSScrollView) {
            let snapshot = text.wrappedValue
            guard displayedText != snapshot, !textView.hasMarkedText() else { return }

            let selection = textView.selectedRange()
            let clipView = scrollView.contentView
            let previousBounds = clipView.bounds
            displayedText = snapshot
            textView.string = snapshot
            let length = snapshot.utf16.count
            let location = min(selection.location, length)
            textView.setSelectedRange(NSRange(location: location, length: min(selection.length, length - location)))
            clipView.scroll(to: clipView.constrainBoundsRect(previousBounds).origin)
            scrollView.reflectScrolledClipView(clipView)
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView, !textView.hasMarkedText() else { return }
            commit(textView)
        }

        func commit(_ textView: NSTextView) {
            let newText = textView.string
            displayedText = newText
            if text.wrappedValue != newText {
                text.wrappedValue = newText
            }
        }
    }
}
