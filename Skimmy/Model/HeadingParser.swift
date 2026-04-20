import Foundation

struct DocumentHeading: Identifiable, Equatable {
    let id: String
    let level: Int
    let text: String
    let lineIndex: Int
}

enum HeadingParser {
    static func parse(_ markdown: String) -> [DocumentHeading] {
        let lines = markdown.components(separatedBy: .newlines)
        var headings: [DocumentHeading] = []
        var inFencedBlock = false

        for (index, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.hasPrefix("```") || trimmed.hasPrefix("~~~") {
                inFencedBlock.toggle()
                continue
            }
            if inFencedBlock { continue }

            guard trimmed.hasPrefix("#") else { continue }

            let hashCount = trimmed.prefix(while: { $0 == "#" }).count
            guard hashCount >= 1, hashCount <= 6 else { continue }

            let afterHashes = trimmed.dropFirst(hashCount)
            guard afterHashes.isEmpty || afterHashes.hasPrefix(" ") else { continue }

            let rawText = String(afterHashes.drop(while: { $0 == " " }))
                .replacingOccurrences(of: #"\s+#*\s*$"#, with: "", options: .regularExpression)

            if rawText.isEmpty { continue }

            let plainText = stripInlineMarkdown(rawText)
            let id = kebabCased(plainText)

            headings.append(DocumentHeading(
                id: id,
                level: hashCount,
                text: plainText,
                lineIndex: index
            ))
        }

        return headings
    }

    private static func stripInlineMarkdown(_ text: String) -> String {
        var result = text

        // Links: [text](url) → text
        result = result.replacingOccurrences(
            of: #"\[([^\]]*)\]\([^\)]*\)"#,
            with: "$1",
            options: .regularExpression
        )
        // Images: ![alt](url) → alt
        result = result.replacingOccurrences(
            of: #"!\[([^\]]*)\]\([^\)]*\)"#,
            with: "$1",
            options: .regularExpression
        )
        // Bold/italic: *** ** * ___ __ _
        result = result.replacingOccurrences(
            of: #"\*{1,3}|_{1,3}"#,
            with: "",
            options: .regularExpression
        )
        // Strikethrough: ~~text~~ → text
        result = result.replacingOccurrences(
            of: "~~",
            with: ""
        )
        // Inline code: `code` → code
        result = result.replacingOccurrences(
            of: "`",
            with: ""
        )

        return result
    }

    /// Split by runs of non-alphanumerics, lowercase each component, join with "-"
    /// Matches the JS kebabCase: str.split(/[^a-zA-Z0-9]+/).filter(…).join('-')
    private static func kebabCased(_ string: String) -> String {
        string
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .map { $0.lowercased() }
            .joined(separator: "-")
    }
}
