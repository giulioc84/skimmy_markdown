import SwiftUI

struct FindBarView: View {
    @Binding var searchText: String
    @Binding var replacementText: String
    let focusRequest: Int
    let matchFound: Bool?
    let replacementStatus: String?
    let isReplacing: Bool
    let onFind: (Bool) -> Void
    let onReplace: ((Bool) -> Void)?
    let onDismiss: () -> Void

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled
    @FocusState private var isFocused: Bool
    @AccessibilityFocusState(for: .voiceOver) private var isVoiceOverFocused: Bool

    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            controls

            if let onReplace {
                replacementControls(onReplace)
            }

            if let feedback {
                Text(feedback)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Document Find")
        .controlSize(.small)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background {
            if reduceTransparency {
                Color(nsColor: .windowBackgroundColor)
            } else {
                Rectangle().fill(.bar)
            }
        }
        .overlay(alignment: .bottom) { Divider() }
        .onChange(of: focusRequest, initial: true) { _, _ in
            isFocused = true
            if voiceOverEnabled { isVoiceOverFocused = true }
        }
        .onExitCommand(perform: onDismiss)
    }

    private var controls: some View {
        HStack(spacing: 8) {
            Spacer()

            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            TextField("Find in Document", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .accessibilityLabel("Find in Document")
                .focused($isFocused)
                .accessibilityFocused($isVoiceOverFocused)
                .onSubmit { onFind(false) }
                .onKeyPress(keys: [.return]) { press in
                    guard press.modifiers.contains(.shift) else { return .ignored }
                    onFind(true)
                    return .handled
                }
                .frame(maxWidth: 230)

            ControlGroup {
                Button("Previous Match", systemImage: "chevron.up") { onFind(true) }
                    .help("Previous Match (⇧⌘G)")

                Button("Next Match", systemImage: "chevron.down") { onFind(false) }
                    .help("Next Match (⌘G)")
            }
            .labelStyle(.iconOnly)
            .disabled(searchText.isEmpty || isReplacing)

            Button("Done", action: onDismiss)
                .accessibilityLabel("Close Find")
                .help("Close Find (Esc)")
        }
    }

    private var feedback: String? {
        if matchFound == false { return "No matches" }
        return onReplace == nil ? nil : replacementStatus
    }

    private func replacementControls(_ replace: @escaping (Bool) -> Void) -> some View {
        HStack(spacing: 8) {
            Spacer()

            TextField("Replace With", text: $replacementText)
                .textFieldStyle(.roundedBorder)
                .accessibilityLabel("Replace With")
                .onSubmit {
                    if !searchText.isEmpty && !isReplacing { replace(false) }
                }
                .frame(maxWidth: 230)

            ControlGroup {
                Button("Replace") { replace(false) }
                Button("Replace All") { replace(true) }
            }
            .disabled(searchText.isEmpty || isReplacing)
        }
    }
}
