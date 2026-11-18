import SwiftUI

/// Floating word count. Reads numbers the parser already computed in the
/// background, so it costs nothing while typing.
struct StatusPill: View {
    @ObservedObject var outline: DocumentParser

    private var summary: String {
        let stats = outline.stats
        var parts = [
            "\(stats.words.formatted()) \(stats.words == 1 ? "word" : "words")",
            "\(stats.characters.formatted()) \(stats.characters == 1 ? "character" : "characters")",
        ]
        if stats.readingMinutes > 0 {
            parts.append("\(stats.readingMinutes) min read")
        }
        return parts.joined(separator: "  ·  ")
    }

    var body: some View {
        Text(summary)
            .font(.system(size: 11.5))
            .monospacedDigit()
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .glassEffect(.regular, in: .capsule)
            .accessibilityLabel("Document statistics: \(summary)")
    }
}
