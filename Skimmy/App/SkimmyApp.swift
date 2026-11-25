import SwiftUI

@main
struct SkimmyApp: App {
    @NSApplicationDelegateAdaptor(SkimmyAppDelegate.self) private var appDelegate

    var body: some Scene {
        DocumentGroup(newDocument: MarkdownDocument()) { file in
            ContentView(document: file.$document, fileURL: file.fileURL, isEditable: file.isEditable)
                .environmentObject(FontSizeManager.shared)
        }
        .commands {
            SkimmyFindCommands()
            SkimmyViewCommands()
        }

        Settings {
            SkimmySettingsView()
        }
    }
}

private struct SkimmyFindCommands: Commands {
    @FocusedValue(DocumentMenuTarget.self) private var target

    var body: some Commands {
        CommandGroup(after: .textEditing) {
            Menu("Find") {
                Button("Find…") {
                    target?.perform(.showFind)
                }
                .keyboardShortcut("f")
                .disabled(target?.canFind != true)

                Button("Find Next") {
                    target?.perform(.nextMatch)
                }
                .keyboardShortcut("g")
                .disabled(target?.canNavigateMatches != true)

                Button("Find Previous") {
                    target?.perform(.previousMatch)
                }
                .keyboardShortcut("g", modifiers: [.command, .shift])
                .disabled(target?.canNavigateMatches != true)
            }
        }
    }
}

private struct SkimmyViewCommands: Commands {
    @FocusedValue(DocumentMenuTarget.self) private var target
    @ObservedObject private var fontSizeManager = FontSizeManager.shared

    private var sidebarVisibility: Binding<Bool> {
        Binding {
            target?.isSidebarVisible ?? false
        } set: { isVisible in
            target?.perform(.setSidebarVisible(isVisible))
        }
    }

    var body: some Commands {
        CommandGroup(replacing: .sidebar) {
            Toggle("Show Sidebar", isOn: sidebarVisibility)
                .keyboardShortcut("l", modifiers: [.command, .shift])
                .disabled(target?.canFind != true)

            Divider()

            Button("Toggle Formatted Editing") {
                target?.perform(.toggleEditing)
            }
            .keyboardShortcut("e")
            .disabled(target?.canEdit != true)

            Divider()

            Button("Increase Text Size") {
                fontSizeManager.increase()
            }
            .keyboardShortcut("=")
            .disabled(target?.canFind != true || !fontSizeManager.canIncrease)

            Button("Decrease Text Size") {
                fontSizeManager.decrease()
            }
            .keyboardShortcut("-")
            .disabled(target?.canFind != true || !fontSizeManager.canDecrease)

            Button("Reset Text Size") {
                fontSizeManager.reset()
            }
            .keyboardShortcut("0")
            .disabled(target?.canFind != true || !fontSizeManager.canReset)
        }
    }
}
