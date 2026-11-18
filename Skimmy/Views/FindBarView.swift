import SwiftUI

/// Find bar for Read mode. Matches are highlighted in the page as you type.
struct FindBarView: View {
    @ObservedObject var session: DocumentSession
    @ObservedObject var finder: PreviewFinder
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .font(.system(size: 12))

            TextField("Find in document", text: $finder.query)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .focused($isFocused)
                .onSubmit { finder.step(1) }
                .frame(width: 170)

            Text(finder.summary)
                .font(.system(size: 11.5))
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(minWidth: 56, alignment: .trailing)

            Button { finder.step(-1) } label: {
                Image(systemName: "chevron.up")
            }
            .help("Previous match (⇧⌘G)")
            .accessibilityLabel("Previous match")
            .disabled(finder.count == 0)

            Button { finder.step(1) } label: {
                Image(systemName: "chevron.down")
            }
            .help("Next match (⌘G)")
            .accessibilityLabel("Next match")
            .disabled(finder.count == 0)

            Button { session.closeFindBar() } label: {
                Image(systemName: "xmark")
            }
            .help("Close (Esc)")
            .accessibilityLabel("Close find")
        }
        .buttonStyle(.plain)
        .font(.system(size: 11, weight: .semibold))
        .padding(.leading, 13)
        .padding(.trailing, 12)
        .padding(.vertical, 8)
        .glassEffect(.regular, in: .capsule)
        .onAppear { isFocused = true }
        .onChange(of: session.findFocusRequest) { _, _ in isFocused = true }
        .onExitCommand { session.closeFindBar() }
    }
}
