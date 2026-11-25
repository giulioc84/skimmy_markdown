import Foundation
import Combine

struct DocumentOutline: Equatable {
    let headings: [DocumentHeading]
    let links: [DocumentLink]

    static func parse(_ markdown: String) -> Self {
        var headings = HeadingParser()
        var links = LinkParser()
        var fence: (marker: Character, length: Int)?

        markdown.enumerateLines { line, _ in
            let trimmed = line.drop(while: \.isWhitespace)
            if let marker = trimmed.first, marker == "`" || marker == "~" {
                let opening = trimmed.prefix(while: { $0 == marker })
                if opening.count >= 3 {
                    let rest = trimmed.dropFirst(opening.count)
                    if let current = fence {
                        if marker == current.marker, opening.count >= current.length,
                           rest.allSatisfy(\.isWhitespace) {
                            fence = nil
                        }
                        return
                    }
                    if marker == "~" || !rest.contains("`") {
                        fence = (marker, opening.count)
                        return
                    }
                }
            }
            guard fence == nil else { return }
            headings.read(trimmed)
            links.read(line)
        }
        return Self(headings: headings.headings, links: links.links)
    }
}

final class DocumentParser: ObservableObject {
    @Published private(set) var outline = DocumentOutline(headings: [], links: [])

    private let textSubject = PassthroughSubject<String, Never>()
    private let queue = DispatchQueue(label: "Skimmy.document-outline", qos: .userInitiated)
    private var cancellable: AnyCancellable?

    init() {
        cancellable = textSubject
            .debounce(for: .milliseconds(300), scheduler: queue)
            .map(DocumentOutline.parse)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] outline in
                guard let self, self.outline != outline else { return }
                self.outline = outline
            }
    }

    func textDidChange(_ text: String) {
        textSubject.send(text)
    }
}
