import Foundation

struct DocumentLink: Identifiable, Equatable {
    struct Target: Hashable {
        let text: String
        let url: String
        let isImage: Bool
    }

    struct ID: Hashable {
        let target: Target
        let occurrence: Int
    }

    let id: ID
    var text: String { id.target.text }
    var url: String { id.target.url }
    var isImage: Bool { id.target.isImage }
}

struct LinkParser {
    private static let inlineLink = try! NSRegularExpression(pattern: #"(!?)\[([^\]]*)\]\(([^)]*)\)"#)
    private static let autoLink = try! NSRegularExpression(pattern: #"<(https?://[^>]+)>"#)

    private(set) var links: [DocumentLink] = []
    private var occurrences: [DocumentLink.Target: Int] = [:]

    mutating func read(_ line: String) {
        let hasInlineLink = line.utf8.contains(91) && line.utf8.contains(41) // [ and )
        let hasAutoLink = line.utf8.contains(60) && line.utf8.contains(62) // < and >
        guard hasInlineLink || hasAutoLink else { return }
        let range = NSRange(location: 0, length: line.utf16.count)

        if hasInlineLink {
            for match in Self.inlineLink.matches(in: line, range: range) {
                append(
                    text: capture(2, of: match, in: line),
                    url: capture(3, of: match, in: line),
                    isImage: match.range(at: 1).length == 1
                )
            }
        }
        if hasAutoLink {
            for match in Self.autoLink.matches(in: line, range: range) {
                let url = capture(1, of: match, in: line)
                append(text: url, url: url, isImage: false)
            }
        }
    }

    private func capture(_ index: Int, of match: NSTextCheckingResult, in line: String) -> String {
        Range(match.range(at: index), in: line).map { String(line[$0]) } ?? ""
    }

    private mutating func append(text: String, url: String, isImage: Bool) {
        let target = DocumentLink.Target(text: text, url: url, isImage: isImage)
        let occurrence = occurrences[target, default: 0]
        occurrences[target] = occurrence + 1
        links.append(DocumentLink(id: .init(target: target, occurrence: occurrence)))
    }
}
