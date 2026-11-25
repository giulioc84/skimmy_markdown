import SwiftUI

struct ContentView: View {
    @Binding var document: MarkdownDocument
    let fileURL: URL?
    let isEditable: Bool
    @EnvironmentObject private var fontSizeManager: FontSizeManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.undoManager) private var undoManager
    @SceneStorage("sidebarVisible") private var isSidebarVisible = UserDefaults.standard.bool(forKey: "sidebarVisible")

    @State private var mode = DocumentMode.read
    @State private var modeRequest = 0
    @State private var scrollProxy = ScrollProxy()
    @State private var sourceEditor = SourceEditorProxy()
    @State private var parser = DocumentParser()
    @State private var documentMenuTarget = DocumentMenuTarget()
    @State private var showFindBar = false
    @State private var findRequest = 0
    @State private var searchText = ""
    @State private var replacementText = ""
    @State private var replacementStatus: String?
    @State private var isReplacing = false
    @State private var matchRequest = 0
    @State private var matchFound: Bool?
    @State private var hasFindSelection = false

    private var showsWelcome: Bool {
        fileURL == nil && document.text.isEmpty && mode == .read
    }

    private var sidebarVisibility: Binding<NavigationSplitViewVisibility> {
        Binding {
            isSidebarVisible ? .all : .detailOnly
        } set: { visibility in
            setSidebarVisible(visibility != .detailOnly)
        }
    }

    private var menuAvailability: DocumentMenuTarget.Availability {
        .init(
            canEdit: isEditable,
            canFind: !showsWelcome,
            canNavigateMatches: !showsWelcome && (mode == .source || !searchText.isEmpty),
            isSidebarVisible: isSidebarVisible
        )
    }

    var body: some View {
        Group {
            if showsWelcome {
                WelcomeOverlay(onStartEditing: { selectMode(.edit) })
                    .background(Color(nsColor: .textBackgroundColor))
            } else {
                NavigationSplitView(columnVisibility: sidebarVisibility) {
                    DocumentSidebar(parser: parser, scrollProxy: scrollProxy, canJumpToHeading: mode != .source)
                        .navigationSplitViewColumnWidth(min: 175, ideal: 220, max: 300)
                } detail: {
                    documentPane
                        .background(Color(nsColor: .textBackgroundColor))
                }
                .navigationSplitViewStyle(.balanced)
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Picker("Document view", selection: Binding(get: { mode }, set: selectMode)) {
                    Text("Read").tag(DocumentMode.read)
                    Text("Edit").tag(DocumentMode.edit)
                        .disabled(!isEditable)
                    Text("Source").tag(DocumentMode.source)
                }
                .pickerStyle(.segmented)
                .fixedSize()
                .help("Read, edit formatted Markdown, or view Markdown source")
            }

            if mode == .edit && isEditable {
                ToolbarItem(placement: .primaryAction) {
                    FormattingToolbar(onFormat: scrollProxy.applyFormat, loadLinkContext: scrollProxy.loadLinkContext)
                }
            }

            if mode != .read && isEditable {
                ToolbarItemGroup {
                    Button("Undo", systemImage: "arrow.uturn.backward") { undoManager?.undo() }
                        .disabled(undoManager?.canUndo != true)
                        .help("Undo (⌘Z)")

                    Button("Redo", systemImage: "arrow.uturn.forward") { undoManager?.redo() }
                        .disabled(undoManager?.canRedo != true)
                        .help("Redo (⇧⌘Z)")
                }
            }

            ToolbarItemGroup {
                Button("Decrease Text Size", systemImage: "textformat.size.smaller") {
                    fontSizeManager.decrease()
                }
                .disabled(!fontSizeManager.canDecrease)
                .help("Decrease Text Size (⌘−)")

                Button("Increase Text Size", systemImage: "textformat.size.larger") {
                    fontSizeManager.increase()
                }
                .disabled(!fontSizeManager.canIncrease)
                .help("Increase Text Size (⌘=)")
            }

            ToolbarItem {
                Button("Find", systemImage: "magnifyingglass", action: find)
                    .disabled(showsWelcome)
                    .help("Find (⌘F)")
            }
        }
        .onAppear {
            parseSidebarIfVisible()
            configureMenu()
        }
        .onDisappear { documentMenuTarget.clear() }
        .onChange(of: isSidebarVisible) {
            parseSidebarIfVisible()
        }
        .onChange(of: document.text) {
            parseSidebarIfVisible()
        }
        .onChange(of: menuAvailability) { configureMenu() }
        .onChange(of: fileURL) { configureMenu() }
        .onChange(of: reduceMotion) { configureMenu() }
        .onChange(of: searchText) {
            matchRequest += 1
            matchFound = nil
            replacementStatus = nil
        }
        .onChange(of: mode) { replacementStatus = nil }
        .focusedSceneValue(documentMenuTarget)
        .frame(minWidth: 620, minHeight: 380)
    }

    private func configureMenu() {
        documentMenuTarget.configure(menuAvailability) { action in
            switch action {
            case .toggleEditing: toggleEditMode()
            case .showFind: find()
            case .nextMatch: findMatch(backwards: false)
            case .previousMatch: findMatch(backwards: true)
            case .setSidebarVisible(let isVisible): setSidebarVisible(isVisible)
            }
        }
    }

    private func setSidebarVisible(_ isVisible: Bool) {
        guard isSidebarVisible != isVisible else { return }
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) {
            isSidebarVisible = isVisible
        }
    }

    private func parseSidebarIfVisible() {
        if isSidebarVisible {
            parser.textDidChange(document.text)
        }
    }

    private var documentPane: some View {
        VStack(spacing: 0) {
            if showFindBar && mode != .source {
                FindBarView(
                    searchText: $searchText,
                    replacementText: $replacementText,
                    focusRequest: findRequest,
                    matchFound: matchFound,
                    replacementStatus: replacementStatus,
                    isReplacing: isReplacing,
                    onFind: findMatch,
                    onReplace: mode == .edit && isEditable ? replaceMatches : nil,
                    onDismiss: dismissFind
                )
            }

            if mode == .source {
                MarkdownTextView(
                    text: $document.text,
                    fontSize: fontSizeManager.fontSize,
                    isEditable: isEditable,
                    proxy: sourceEditor
                )
            } else {
                MarkdownWebView(
                    text: $document.text,
                    fontSize: fontSizeManager.fontSize,
                    scrollProxy: scrollProxy,
                    isEditing: mode == .edit,
                    onUndo: { undoManager?.undo() },
                    onRedo: { undoManager?.redo() }
                )
            }

            HStack(spacing: 8) {
                if !isEditable {
                    Label("Read-Only", systemImage: "lock")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.leading, 14)
                        .accessibilityLabel("Read-only document")
                }
                WordCountView(text: document.text)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func selectMode(_ newMode: DocumentMode) {
        modeRequest += 1
        guard newMode != mode, newMode != .edit || isEditable else { return }

        if mode == .edit && newMode == .source {
            let request = modeRequest
            scrollProxy.finishEditing {
                guard modeRequest == request else { return }
                hideFindBar()
                mode = .source
            }
            return
        }

        if mode == .source {
            sourceEditor.finishComposition()
        }
        if newMode == .source {
            hideFindBar()
        }
        mode = newMode
    }

    private func toggleEditMode() {
        selectMode(mode == .edit ? .read : .edit)
    }

    private func find() {
        guard !showsWelcome else { return }
        if mode == .source {
            sourceEditor.find()
        } else {
            findRequest += 1
            showFindBar = true
        }
    }

    private func findMatch(backwards: Bool) {
        guard !showsWelcome, !isReplacing else { return }
        if mode == .source {
            sourceEditor.find(backwards ? .previousMatch : .nextMatch)
            return
        }
        guard !searchText.isEmpty else { return }
        replacementStatus = nil
        matchRequest += 1
        let request = matchRequest
        scrollProxy.find(searchText, backwards: backwards) { found in
            guard matchRequest == request else { return }
            if found == false && matchFound != false {
                AccessibilityNotification.Announcement("No matches").post()
            }
            matchFound = found
            hasFindSelection = hasFindSelection || found == true
            if found == false && !showFindBar { find() }
        }
    }

    private func replaceMatches(all: Bool) {
        guard mode == .edit, isEditable, !searchText.isEmpty, !isReplacing else { return }
        isReplacing = true
        matchFound = nil
        replacementStatus = nil
        matchRequest += 1
        let request = matchRequest
        scrollProxy.replace(searchText, with: replacementText, all: all) { count in
            isReplacing = false
            guard matchRequest == request, mode == .edit else { return }

            let message: String
            switch count {
            case 0:
                matchFound = false
                message = "No matches"
            case 1:
                message = "Replaced 1 match"
            case let count?:
                message = "Replaced \(count.formatted()) matches"
            case nil:
                message = "Couldn’t replace text."
            }
            replacementStatus = message
            AccessibilityNotification.Announcement(message).post()
        }
    }

    private func dismissFind() {
        scrollProxy.endFind(clearingSelection: hasFindSelection)
        hideFindBar()
    }

    private func hideFindBar() {
        showFindBar = false
        matchRequest += 1
        matchFound = nil
        replacementStatus = nil
        hasFindSelection = false
    }
}

private enum DocumentMode: Hashable {
    case read, edit, source
}

private struct DocumentSidebar: View {
    @ObservedObject var parser: DocumentParser
    let scrollProxy: ScrollProxy
    let canJumpToHeading: Bool

    var body: some View {
        SidebarView(
            headings: parser.outline.headings,
            links: parser.outline.links,
            canJumpToHeading: canJumpToHeading,
            onHeading: scrollProxy.scrollTo,
            onLink: scrollProxy.follow
        )
    }
}
