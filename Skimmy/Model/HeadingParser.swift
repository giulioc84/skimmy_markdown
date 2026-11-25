import Foundation

struct DocumentHeading: Identifiable, Equatable {
    struct ID: Hashable {
        let anchor: String
        let occurrence: Int
    }

    var id: ID { ID(anchor: anchor, occurrence: occurrence) }
    let anchor: String
    let occurrence: Int
    let level: Int
    let text: String
}

struct HeadingParser {
    private static let trailingHashes = try! NSRegularExpression(pattern: #"\s+#*\s*$"#)
    private static let inlineLinks = try! NSRegularExpression(pattern: #"!?\[([^\]]*)\]\([^\)]*\)"#)
    private static let inlineMarkers = try! NSRegularExpression(pattern: #"[*_`]+|~~"#)

    private(set) var headings: [DocumentHeading] = []
    private var occurrences: [String: Int] = [:]

    mutating func read(_ line: Substring) {
        guard line.first == "#" else { return }
        let level = line.prefix(while: { $0 == "#" }).count
        guard level <= 6 else { return }

        let afterHashes = line.dropFirst(level)
        guard afterHashes.first == " " || afterHashes.first == "\t" else { return }
        let source = afterHashes.trimmingCharacters(in: .whitespaces)
        let raw = Self.replacing(in: source, regex: Self.trailingHashes)
        guard !raw.isEmpty, !raw.allSatisfy({ $0 == "#" }) else { return }

        let linksStripped = raw.utf8.contains(91) ? Self.replacing(in: raw, regex: Self.inlineLinks, with: "$1") : raw
        let text = Self.replacing(in: linksStripped, regex: Self.inlineMarkers)
        let anchor = text.components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .map { $0.lowercased() }
            .joined(separator: "-")
        let occurrence = occurrences[anchor, default: 0]
        occurrences[anchor] = occurrence + 1
        headings.append(DocumentHeading(anchor: anchor, occurrence: occurrence, level: level, text: text))
    }

    private static func replacing(in text: String, regex: NSRegularExpression, with replacement: String = "") -> String {
        regex.stringByReplacingMatches(in: text, range: NSRange(location: 0, length: text.utf16.count), withTemplate: replacement)
    }
}
