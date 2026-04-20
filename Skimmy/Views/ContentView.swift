import SwiftUI

struct ContentView: View {
    @Binding var document: MarkdownDocument
    let fileURL: URL?
    @EnvironmentObject var fontSizeManager: FontSizeManager
    @EnvironmentObject var sidebarStateManager: SidebarStateManager
    @Environment(\.undoManager) private var undoManager
    @State private var isEditing = false
    @State private var originalText = ""
    @State private var showSaveDialog = false
    @State private var scrollProxy = ScrollProxy()
    @State private var parser = DocumentParser()
    @State private var showFindBar = false

    private var showSidebar: Bool {
        sidebarStateManager.isVisible && !(document.text.isEmpty && !isEditing)
    }

    var body: some View {
        HStack(spacing: 0) {
            if showSidebar {
                SidebarContainerView(parser: parser, isEditing: isEditing, scrollProxy: scrollProxy)
            }

            Group {
                if document.text.isEmpty && !isEditing {
                    WelcomeOverlay(onStartEditing: { enterEditMode() })
                } else if isEditing {
                    EditorView(text: $document.text)
                } else {
                    ReaderView(text: document.text, scrollProxy: scrollProxy)
                }
            }
            .background(Color(nsColor: .textBackgroundColor))
            .padding(.leading, 44)
            .overlay(alignment: .topLeading) {
                VerticalToolbarView(isEditing: $isEditing, onToggleEditMode: toggleEditMode)
                    .fixedSize()
                    .padding(.top, 38)
                    .padding(.leading, 6)
            }
            .overlay(alignment: .bottomTrailing) {
                if !document.text.isEmpty || isEditing {
                    WordCountView(text: document.text)
                        .padding(8)
                }
            }
            .overlay(alignment: .topTrailing) {
                if showFindBar && !isEditing {
                    FindBarView(scrollProxy: scrollProxy) {
                        showFindBar = false
                    }
                    .padding(.top, 8)
                    .padding(.trailing, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(WindowAccessor())
        .onAppear {
            parser.textDidChange(document.text)
        }
        .onChange(of: document.text) { _, newValue in
            parser.textDidChange(newValue)
        }
        .focusedValue(\.toggleEditMode, toggleEditMode)
        .focusedValue(\.toggleFindBar, toggleFindBar)
        .focusedValue(\.saveDocument, saveDocument)
        .confirmationDialog(
            "You have unsaved changes",
            isPresented: $showSaveDialog,
            titleVisibility: .visible
        ) {
            Button("Save to Same File") {
                isEditing = false
            }
            Button("Save as New File") {
                saveAsNewFile()
            }
            Button("Discard Changes", role: .destructive) {
                document.text = originalText
                isEditing = false
            }
            Button("Cancel", role: .cancel) { }
        }
        .frame(minWidth: 500, minHeight: 400)
    }

    private func toggleFindBar() {
        if !isEditing {
            withAnimation(.easeOut(duration: 0.2)) {
                showFindBar.toggle()
            }
        }
    }

    private func enterEditMode() {
        originalText = document.text
        showFindBar = false
        isEditing = true
    }

    private func toggleEditMode() {
        if isEditing {
            if document.text != originalText, fileURL != nil {
                showSaveDialog = true
            } else {
                isEditing = false
            }
        } else {
            enterEditMode()
        }
    }

    /// Trigger the document save through AppKit, then reset `originalText` so that
    /// leaving edit mode after a save does not re-prompt the "unsaved changes" dialog.
    /// Called from the Cmd+S command installed in `SkimmyApp`.
    private func saveDocument() {
        NSApp.sendAction(#selector(NSDocument.save(_:)), to: nil, from: nil)
        originalText = document.text
    }

    private func saveAsNewFile() {
        guard let fileURL = fileURL else { return }
        let dir = fileURL.deletingLastPathComponent()
        let name = fileURL.deletingPathExtension().lastPathComponent
        let formatter = DateFormatter()
        formatter.dateFormat = "yyMMdd_HHmm"
        let stamp = formatter.string(from: Date())
        let newName = "\(name)_edited\(stamp).md"
        let newURL = dir.appendingPathComponent(newName)

        if let data = document.text.data(using: .utf8) {
            try? FileManager.default.createFile(atPath: newURL.path, contents: data)
        }
        document.text = originalText
        isEditing = false
    }
}

private struct SidebarContainerView: View {
    @ObservedObject var parser: DocumentParser
    let isEditing: Bool
    let scrollProxy: ScrollProxy

    var body: some View {
        HStack(spacing: 0) {
            SidebarView(
                headings: parser.headings,
                links: parser.links,
                scrollProxy: scrollProxy,
                isEditing: isEditing
            )
            .equatable()
            Divider()
        }
        .transition(.move(edge: .leading))
    }
}
