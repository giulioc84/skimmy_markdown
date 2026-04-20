import SwiftUI

struct VerticalToolbarView: View {
    @Binding var isEditing: Bool
    let onToggleEditMode: () -> Void
    @EnvironmentObject var fontSizeManager: FontSizeManager
    @EnvironmentObject var sidebarStateManager: SidebarStateManager
    @Environment(\.undoManager) private var undoManager

    @Namespace private var toolbarNamespace
    @State private var isHovering = false

    var body: some View {
        GlassEffectContainer {
            VStack(spacing: 6) {
                // Sidebar toggle
                toolbarButton(
                    id: "sidebar",
                    systemImage: "sidebar.left",
                    help: "Toggle sidebar (Cmd Shift L)"
                ) {
                    sidebarStateManager.toggle()
                }

                toolbarDivider

                // Undo/redo (edit mode only)
                if isEditing {
                    toolbarButton(
                        id: "undo",
                        systemImage: "arrow.uturn.backward",
                        help: "Undo (Cmd Z)",
                        disabled: !(undoManager?.canUndo ?? false)
                    ) {
                        undoManager?.undo()
                    }

                    toolbarButton(
                        id: "redo",
                        systemImage: "arrow.uturn.forward",
                        help: "Redo (Cmd Shift Z)",
                        disabled: !(undoManager?.canRedo ?? false)
                    ) {
                        undoManager?.redo()
                    }

                    toolbarDivider
                }

                // Font size controls
                toolbarButton(
                    id: "fontDecrease",
                    systemImage: "minus",
                    help: "Decrease font size (Cmd -)"
                ) {
                    fontSizeManager.decrease()
                }

                toolbarButton(
                    id: "fontIncrease",
                    systemImage: "plus",
                    help: "Increase font size (Cmd +)"
                ) {
                    fontSizeManager.increase()
                }

                toolbarDivider

                // Edit/preview toggle
                toolbarButton(
                    id: "editToggle",
                    systemImage: isEditing ? "eye" : "pencil",
                    help: isEditing ? "Switch to reader (Cmd E)" : "Switch to editor (Cmd E)"
                ) {
                    onToggleEditMode()
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 4)
            .glassEffect(.regular, in: .capsule)
            .animation(.bouncy, value: isEditing)
        }
        .fixedSize()
        .opacity(isHovering ? 1.0 : 0.7)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
    }

    private func toolbarButton(
        id: String,
        systemImage: String,
        help: String,
        disabled: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 14))
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.3 : 1.0)
        .help(help)
        .glassEffectID(id, in: toolbarNamespace)
    }

    private var toolbarDivider: some View {
        Divider()
            .frame(width: 20)
            .padding(.vertical, 2)
    }
}
