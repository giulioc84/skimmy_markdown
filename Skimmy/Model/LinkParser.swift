import Foundation

struct DocumentLink: Identifiable, Equatable {
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
    private static let autolinkRegex = makeRegex(#"<(https?://[^>]+)>"#)

    static func parse(_ markdown: String) -> [DocumentLink] {
        let lines = markdown.components(separatedBy: .newlines)
        var links: [DocumentLink] = []
        var inFencedBlock = false
        var occurrences: [String: Int] = [:]

        for (index, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.hasPrefix("```") || trimmed.hasPrefix("~~~") {
                inFencedBlock.toggle()
                continue
            }
            if inFencedBlock { continue }

            let range = NSRange(line.startIndex..., in: line)

            let inlineMatches = inlineLinkRegex.matches(in: line, range: range)
            for match in inlineMatches {
                let bang = Range(match.range(at: 1), in: line).map { String(line[$0]) } ?? ""
                let text = Range(match.range(at: 2), in: line).map { String(line[$0]) } ?? ""
                let url = Range(match.range(at: 3), in: line).map { String(line[$0]) } ?? ""
                let isImage = bang == "!"

                let key = "\(url)-\(text)-\(isImage)"
                let occurrence = occurrences[key, default: 0]
                occurrences[key] = occurrence + 1

                links.append(DocumentLink(
                    id: "\(url)-\(text)-\(isImage)-\(occurrence)",
                    text: text,
                    url: url,
                    lineIndex: index,
                    isImage: isImage
                ))
            }

            let autoMatches = autolinkRegex.matches(in: line, range: range)
            for match in autoMatches {
                let url = Range(match.range(at: 1), in: line).map { String(line[$0]) } ?? ""

                let key = "\(url)-\(url)-false"
                let occurrence = occurrences[key, default: 0]
                occurrences[key] = occurrence + 1

                links.append(DocumentLink(
                    id: "\(url)-\(url)-false-\(occurrence)",
                    text: url,
                    url: url,
                    lineIndex: index,
                    isImage: false
                ))
            }
        }

        return links
    }
}
