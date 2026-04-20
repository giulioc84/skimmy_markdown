import Foundation
import Combine

final class DocumentParser: ObservableObject {
    @Published var headings: [DocumentHeading] = []
    @Published var links: [DocumentLink] = []

    private let textSubject = PassthroughSubject<String, Never>()
    private var cancellable: AnyCancellable?

    init() {
        cancellable = textSubject
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.global(qos: .userInitiated))
            .removeDuplicates()
            .receive(on: DispatchQueue.global(qos: .userInitiated))
            .map { text in
                (HeadingParser.parse(text), LinkParser.parse(text))
            }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] headings, links in
                guard let self else { return }
                if self.headings != headings {
                    self.headings = headings
                }
                if self.links != links {
                    self.links = links
                }
            }
    }

    func textDidChange(_ text: String) {
        textSubject.send(text)
    }
}
