import SwiftUI

struct FindBarView: View {
    let scrollProxy: ScrollProxy
    let onDismiss: () -> Void

    @State private var searchText = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .font(.system(size: 12))

            TextField("Find in page", text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .focused($isFocused)
                .onSubmit { findNext() }
                .frame(width: 180)

            Button(action: findPrevious) {
                Image(systemName: "chevron.up")
                    .font(.system(size: 11, weight: .medium))
            }
            .buttonStyle(.plain)
            .help("Previous match (Shift Enter)")

            Button(action: findNext) {
                Image(systemName: "chevron.down")
                    .font(.system(size: 11, weight: .medium))
            }
            .buttonStyle(.plain)
            .help("Next match (Enter)")

            Button(action: dismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Close (Esc)")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
        .onAppear { isFocused = true }
        .onKeyPress(.escape) {
            dismiss()
            return .handled
        }
    }

    private func findNext() {
        guard !searchText.isEmpty else { return }
        let escaped = searchText.replacingOccurrences(of: "'", with: "\\'")
        scrollProxy.webView?.evaluateJavaScript(
            "window.find('\(escaped)', false, false, true);"
        )
    }

    private func findPrevious() {
        guard !searchText.isEmpty else { return }
        let escaped = searchText.replacingOccurrences(of: "'", with: "\\'")
        scrollProxy.webView?.evaluateJavaScript(
            "window.find('\(escaped)', false, true, true);"
        )
    }

    private func dismiss() {
        // Clear selection highlight
        scrollProxy.webView?.evaluateJavaScript(
            "window.getSelection().removeAllRanges();"
        )
        onDismiss()
    }
}
