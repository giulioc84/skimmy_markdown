import Foundation

struct DocumentHeading: Identifiable, Equatable, Sendable {
    /// Zero-based source line. Unique per heading, so it doubles as the identity.
    let lineIndex: Int
    let level: Int
    let text: String

    var id: Int { lineIndex }
}

enum MarkdownLines {
    /// Splits on `\n`, `\r\n` and `\r` only, matching how the preview counts lines,
    /// so a line index means the same thing in the editor, the outline and the preview.
    static func split(_ markdown: String) -> [Substring] {
        markdown.split(omittingEmptySubsequences: false) { $0 == "\n" || $0 == "\r\n" || $0 == "\r" }
    }

    static func isFence(_ trimmedLine: Substring) -> Bool {
        trimmedLine.hasPrefix("```") || trimmedLine.hasPrefix("~~~")
    }
}

enum HeadingParser {
    static func parse(_ markdown: String) -> [DocumentHeading] {
        var headings: [DocumentHeading] = []
        var inFencedBlock = false

        for (index, line) in MarkdownLines.split(markdown).enumerated() {
            let trimmed = line.drop(while: { $0 == " " || $0 == "\t" })

            if MarkdownLines.isFence(trimmed) {
                inFencedBlock.toggle()
                continue
            }
            if inFencedBlock || !trimmed.hasPrefix("#") { continue }

            let hashCount = trimmed.prefix(while: { $0 == "#" }).count
            guard hashCount <= 6 else { continue }

            let afterHashes = trimmed.dropFirst(hashCount)
            guard afterHashes.isEmpty || afterHashes.hasPrefix(" ") || afterHashes.hasPrefix("\t") else { continue }

            let rawText = String(afterHashes)
                .trimmingCharacters(in: .whitespaces)
                .replacingOccurrences(of: #"\s+#+$"#, with: "", options: .regularExpression)
            if rawText.isEmpty || rawText.allSatisfy({ $0 == "#" }) { continue }

            headings.append(DocumentHeading(
                lineIndex: index,
                level: hashCount,
                text: stripInlineMarkdown(rawText)
            ))
        }

        return headings
    }

    private static func stripInlineMarkdown(_ text: String) -> String {
        var result = text

        // Images first, so the leading "!" goes with them: ![alt](url) → alt
        result = result.replacingOccurrences(
            of: #"!\[([^\]]*)\]\([^\)]*\)"#,
            with: "$1",
            options: .regularExpression
        )
        // Links: [text](url) → text
        result = result.replacingOccurrences(
            of: #"\[([^\]]*)\]\([^\)]*\)"#,
            with: "$1",
            options: .regularExpression
        )
        // Bold/italic: *** ** * ___ __ _
        result = result.replacingOccurrences(
            of: #"\*{1,3}|_{1,3}"#,
            with: "",
            options: .regularExpression
        )
        // Strikethrough and inline code markers
        result = result.replacingOccurrences(of: "~~", with: "")
        result = result.replacingOccurrences(of: "`", with: "")

        return result
    }
}
