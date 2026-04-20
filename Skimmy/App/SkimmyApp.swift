import SwiftUI

@main
struct SkimmyApp: App {
    @StateObject private var fontSizeManager = FontSizeManager.shared
    @StateObject private var sidebarStateManager = SidebarStateManager.shared
    @FocusedValue(\.toggleEditMode) var toggleEditMode
    @FocusedValue(\.toggleFindBar) var toggleFindBar
    @FocusedValue(\.saveDocument) var saveDocument

    var body: some Scene {
        DocumentGroup(newDocument: MarkdownDocument()) { file in
            ContentView(document: file.$document, fileURL: file.fileURL)
                .environmentObject(fontSizeManager)
                .environmentObject(sidebarStateManager)
        }
        .commands {
            CommandGroup(replacing: .saveItem) {
                Button("Save") {
                    // Delegated to ContentView so the "unsaved changes" baseline
                    // is updated after a save — otherwise toggling out of edit
                    // mode after Cmd+S would re-prompt the save dialog.
                    saveDocument?()
                }
                .keyboardShortcut("s", modifiers: .command)
            }

            CommandGroup(replacing: .textEditing) {
                Button("Find") {
                    toggleFindBar?()
                }
                .keyboardShortcut("f", modifiers: .command)
            }

            // Merge our view commands INTO the built-in View menu instead of
            // adding a second "View" menu. `.sidebar` places items near the
            // existing "Show/Hide Sidebar" entries, which is the natural home
            // for our edit/preview, sidebar, and zoom controls.
            CommandGroup(after: .sidebar) {
                Divider()

                Button("Toggle Edit/Preview") {
                    toggleEditMode?()
                }
                .keyboardShortcut("e", modifiers: .command)

                Button("Toggle Sidebar") {
                    sidebarStateManager.toggle()
                }
                .keyboardShortcut("l", modifiers: [.command, .shift])

                Divider()

                Button("Increase Font Size") {
                    fontSizeManager.increase()
                }
                .keyboardShortcut("=", modifiers: .command)

                Button("Decrease Font Size") {
                    fontSizeManager.decrease()
                }
                .keyboardShortcut("-", modifiers: .command)

                Button("Reset Font Size") {
                    fontSizeManager.reset()
                }
                .keyboardShortcut("0", modifiers: .command)
            }
        }
    }
}
