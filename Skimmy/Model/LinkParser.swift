import Foundation

struct DocumentLink: Identifiable, Equatable, Sendable {
    /// "line:column" of the match, unique within a document.
    let id: String
    let text: String
    let url: String
    let lineIndex: Int
    let isImage: Bool
}

enum LinkParser {
    private static func makeRegex(_ pattern: String) -> NSRegularExpression {
        // Patterns are compile-time constants; if one fails to compile it is a
        // programmer error, so we surface it with a clear message rather than an
        // anonymous `try!` trap.
        do {
            return try NSRegularExpression(pattern: pattern)
        } catch {
            preconditionFailure("LinkParser: invalid regex '\(pattern)': \(error)")
        }
    }

    private static let inlineLinkRegex = makeRegex(#"(!?)\[([^\]]*)\]\(([^)]*)\)"#)
    private static let autolinkRegex = makeRegex(#"<(https?://[^>\s]+)>"#)

    static func parse(_ markdown: String) -> [DocumentLink] {
        var links: [DocumentLink] = []
        var inFencedBlock = false

        for (index, rawLine) in MarkdownLines.split(markdown).enumerated() {
            let trimmed = rawLine.drop(while: { $0 == " " || $0 == "\t" })

            if MarkdownLines.isFence(trimmed) {
                inFencedBlock.toggle()
                continue
            }
            if inFencedBlock { continue }
            // Most lines hold no link at all; skip the regex work for them.
            guard rawLine.contains("](") || rawLine.contains("<http") else { continue }

            let line = String(rawLine) as NSString
            let range = NSRange(location: 0, length: line.length)

            for match in inlineLinkRegex.matches(in: line as String, range: range) {
                let isImage = match.range(at: 1).length > 0
                let text = line.substring(with: match.range(at: 2))
                let url = destination(from: line.substring(with: match.range(at: 3)))
                guard !url.isEmpty else { continue }

                links.append(DocumentLink(
                    id: "\(index):\(match.range.location)",
                    text: text,
                    url: url,
                    lineIndex: index,
                    isImage: isImage
                ))
            }

            for match in autolinkRegex.matches(in: line as String, range: range) {
                let url = line.substring(with: match.range(at: 1))
                links.append(DocumentLink(
                    id: "\(index):\(match.range.location)",
                    text: "",
                    url: url,
                    lineIndex: index,
                    isImage: false
                ))
            }
        }

        return links
    }

    /// `(url "Optional title")` → `url`, with the `<...>` wrapper removed if present.
    private static func destination(from raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("<"), let close = trimmed.firstIndex(of: ">") {
            return String(trimmed[trimmed.index(after: trimmed.startIndex)..<close])
        }
        return trimmed.split(whereSeparator: { $0 == " " || $0 == "\t" }).first.map(String.init) ?? ""
    }
}
