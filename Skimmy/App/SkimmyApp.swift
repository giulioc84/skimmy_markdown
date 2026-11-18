import SwiftUI

@main
struct SkimmyApp: App {
    @StateObject private var fontSizeManager = FontSizeManager.shared
    @StateObject private var sidebarStateManager = SidebarStateManager.shared
    /// The frontmost document window's state; nil when no document window is key.
    @FocusedObject private var session: DocumentSession?

    var body: some Scene {
        DocumentGroup(newDocument: MarkdownDocument()) { file in
            ContentView(document: file.$document, fileURL: file.fileURL)
                .environmentObject(fontSizeManager)
                .environmentObject(sidebarStateManager)
        }
        .commands {
            // Find routes to the editor's find bar or the Read-mode find bar,
            // depending on what the window is showing.
            CommandGroup(replacing: .textEditing) {
                Button("Find…") { session?.find() }
                    .keyboardShortcut("f", modifiers: .command)
                Button("Find and Replace…") { session?.findAndReplace() }
                    .keyboardShortcut("f", modifiers: [.command, .option])
                Button("Find Next") { session?.findNext() }
                    .keyboardShortcut("g", modifiers: .command)
                Button("Find Previous") { session?.findPrevious() }
                    .keyboardShortcut("g", modifiers: [.command, .shift])
            }

            // Merge our view commands INTO the built-in View menu instead of
            // adding a second "View" menu.
            CommandGroup(after: .sidebar) {
                Divider()

                Button("Read") { session?.mode = .reader }
                    .keyboardShortcut("1", modifiers: .command)
                Button("Split") { session?.mode = .split }
                    .keyboardShortcut("2", modifiers: .command)
                Button("Edit") { session?.mode = .editor }
                    .keyboardShortcut("3", modifiers: .command)
                Button("Toggle Read / Edit") { session?.toggleEditing() }
                    .keyboardShortcut("e", modifiers: .command)

                Divider()

                Button("Toggle Sidebar") { sidebarStateManager.toggle() }
                    .keyboardShortcut("l", modifiers: [.command, .shift])

                Divider()

                Button("Increase Font Size") { fontSizeManager.increase() }
                    .keyboardShortcut("=", modifiers: .command)
                Button("Decrease Font Size") { fontSizeManager.decrease() }
                    .keyboardShortcut("-", modifiers: .command)
                Button("Reset Font Size") { fontSizeManager.reset() }
                    .keyboardShortcut("0", modifiers: .command)
            }

            CommandMenu("Format") {
                Group {
                    Button("Bold") { session?.editor.toggleWrap("**", placeholder: "bold text") }
                        .keyboardShortcut("b", modifiers: .command)
                    Button("Italic") { session?.editor.toggleWrap("_", placeholder: "italic text") }
                        .keyboardShortcut("i", modifiers: .command)
                    Button("Code") { session?.editor.toggleWrap("`", placeholder: "code") }
                        .keyboardShortcut("k", modifiers: [.command, .shift])
                    Button("Link") { session?.editor.insertLink() }
                        .keyboardShortcut("k", modifiers: .command)
                }
                .disabled(session?.mode.showsEditor != true || session?.showsWelcome == true)
            }
        }
    }
}
