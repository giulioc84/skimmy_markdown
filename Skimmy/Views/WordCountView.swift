import SwiftUI

struct WordCountView: View {
    let text: String

    private var wordCount: Int {
        text.split { $0.isWhitespace || $0.isNewline }.count
    }

    private var charCount: Int {
        text.count
    }

    var body: some View {
        Text("\(wordCount)W  \(charCount)C")
            .font(.system(size: 11, design: .monospaced))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.ultraThinMaterial, in: Capsule())
    }
}
