import SwiftUI
import AppKit

enum ViewMode: String, CaseIterable, Identifiable {
    case reader
    case split
    case editor

    var id: String { rawValue }

    var title: String {
        switch self {
        case .reader: "Read"
        case .split: "Split"
        case .editor: "Edit"
        }
    }

    var showsEditor: Bool { self != .reader }
    var showsPreview: Bool { self != .editor }
}

/// Per-window state: which mode the window is in, plus the long-lived editor and
/// preview that the views attach to. Menu commands reach the frontmost window's
/// session through `@FocusedObject`.
@MainActor
final class DocumentSession: ObservableObject {
    private static let modeKey = "viewMode"

    @Published var mode: ViewMode {
        didSet {
            guard mode != oldValue else { return }
            UserDefaults.standard.set(mode.rawValue, forKey: Self.modeKey)
            modeDidChange(from: oldValue)
        }
    }
    @Published var showsWelcome = false
    @Published var isFindBarVisible = false
    /// Bumped each time Find is invoked, so the find field can take focus again.
    @Published private(set) var findFocusRequest = 0

    let outline = DocumentParser()
    let editor = EditorController()
    let preview: PreviewController
    let finder: PreviewFinder

    var fileURL: URL? {
        didSet { preview.documentURL = fileURL }
    }

    private var lastEditingMode: ViewMode = .split
    private var didStart = false

    init() {
        // New windows open in the mode you last used; Split the first time.
        let stored = UserDefaults.standard.string(forKey: Self.modeKey).flatMap(ViewMode.init(rawValue:))
        let preview = PreviewController()
        self.preview = preview
        finder = PreviewFinder(preview: preview)
        mode = stored ?? .split
        if let stored, stored.showsEditor { lastEditingMode = stored }

        editor.onScroll = { [weak self] position in
            guard let self else { return }
            self.outline.setTopLine(position.line)
            if self.mode == .split {
                self.preview.sync(toLine: position.line, atEnd: position.atEnd)
            }
        }
        preview.onTopLineChange = { [weak self] line in
            // In Split the editor decides where we are; the preview only follows.
            guard let self, self.mode == .reader else { return }
            self.outline.setTopLine(line)
        }
        preview.onDidRender = { [weak self] in
            guard let self, self.mode == .split else { return }
            self.alignPreviewWithEditor()
        }
        preview.onOpenLink = { [weak self] href in
            LinkOpener.open(href, relativeTo: self?.fileURL)
        }
    }

    func start(text: String, fileURL: URL?) {
        self.fileURL = fileURL
        guard !didStart else { return }
        didStart = true
        showsWelcome = text.isEmpty
        outline.textDidChange(text, immediately: true)
        if mode.showsEditor && !showsWelcome {
            focusEditorSoon()
        }
    }

    // MARK: - Modes

    /// ⌘E: flip between reading and whichever editing layout was used last.
    func toggleEditing() {
        mode = mode == .reader ? lastEditingMode : .reader
    }

    func startWriting() {
        showsWelcome = false
        if !mode.showsEditor { mode = .split }
        focusEditorSoon()
    }

    private func modeDidChange(from oldMode: ViewMode) {
        if mode.showsEditor {
            lastEditingMode = mode
            closeFindBar()
            focusEditorSoon()
        }
        if oldMode.showsEditor && mode.showsPreview {
            // Line the preview up with wherever the editor was, once it is on screen.
            Task { [weak self] in
                try? await Task.sleep(for: .milliseconds(150))
                self?.alignPreviewWithEditor()
            }
        }
    }

    private func focusEditorSoon() {
        // The editor joins the window on the next layout pass; wait for it.
        Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(80))
            self?.editor.focus()
        }
    }

    private func alignPreviewWithEditor() {
        guard let position = editor.scrollPosition else { return }
        preview.sync(toLine: position.line, atEnd: position.atEnd)
    }

    // MARK: - Navigation

    func jump(toLine line: Int) {
        outline.setTopLine(line)
        if mode.showsEditor {
            editor.scrollToLine(line)
            if mode == .split { preview.scrollToLine(line, animated: false) }
        } else {
            preview.scrollToLine(line, animated: true)
        }
    }

    // MARK: - Find

    /// With the editor on screen, Find uses the system find bar in the source text.
    /// In Read mode it searches the rendered page.
    func find() {
        if mode.showsEditor {
            editor.performFind(.showFindInterface)
        } else {
            withAnimation(.easeOut(duration: 0.18)) { isFindBarVisible = true }
            findFocusRequest += 1
        }
    }

    func findAndReplace() {
        if !mode.showsEditor { mode = lastEditingMode }
        editor.performFind(.showReplaceInterface)
    }

    func findNext() {
        if mode.showsEditor {
            editor.performFind(.nextMatch)
        } else if isFindBarVisible {
            finder.step(1)
        } else {
            find()
        }
    }

    func findPrevious() {
        if mode.showsEditor {
            editor.performFind(.previousMatch)
        } else if isFindBarVisible {
            finder.step(-1)
        } else {
            find()
        }
    }

    func closeFindBar() {
        guard isFindBarVisible else { return }
        withAnimation(.easeOut(duration: 0.18)) { isFindBarVisible = false }
        finder.clear()
    }
}

/// Search state for the Read-mode find bar.
@MainActor
final class PreviewFinder: ObservableObject {
    @Published var query = "" {
        didSet {
            if query != oldValue { search() }
        }
    }
    @Published private(set) var count = 0
    @Published private(set) var index = -1

    private let preview: PreviewController

    init(preview: PreviewController) {
        self.preview = preview
    }

    var summary: String {
        if query.isEmpty { return "" }
        return count == 0 ? "No results" : "\(index + 1) of \(count)"
    }

    func search() {
        preview.find(query) { [weak self] result in self?.apply(result) }
    }

    func step(_ direction: Int) {
        guard count > 0 else { return }
        preview.findStep(direction) { [weak self] result in self?.apply(result) }
    }

    func clear() {
        preview.clearFind()
        count = 0
        index = -1
    }

    private func apply(_ result: PreviewController.FindResult) {
        count = result.count
        index = result.index
    }
}
