import Foundation

struct DocumentStats: Equatable, Sendable {
    var words = 0
    var characters = 0

    /// Reading time at 230 words per minute, rounded up.
    var readingMinutes: Int {
        words == 0 ? 0 : max(1, Int((Double(words) / 230).rounded(.up)))
    }

    init() {}

    init(_ text: String) {
        characters = text.count

        // One pass over the UTF-8 bytes; avoids allocating a substring per word.
        var count = 0
        var inWord = false
        for byte in text.utf8 {
            let isSpace = byte == 0x20 || (byte >= 0x09 && byte <= 0x0D)
            if isSpace {
                inWord = false
            } else if !inWord {
                inWord = true
                count += 1
            }
        }
        words = count
    }
}

/// Everything the sidebar and status pill need, computed off the main thread in one go.
struct DocumentAnalysis: Sendable {
    let headings: [DocumentHeading]
    let links: [DocumentLink]
    let stats: DocumentStats

    init(_ text: String) {
        headings = HeadingParser.parse(text)
        links = LinkParser.parse(text)
        stats = DocumentStats(text)
    }
}
