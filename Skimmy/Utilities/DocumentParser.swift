import Foundation
import Combine

/// Keeps the outline, link index and word counts in step with the document.
/// Parsing is debounced and runs off the main thread.
@MainActor
final class DocumentParser: ObservableObject {
    @Published private(set) var headings: [DocumentHeading] = []
    @Published private(set) var links: [DocumentLink] = []
    @Published private(set) var stats = DocumentStats()
    /// The heading the reader is currently inside, for the sidebar highlight.
    @Published private(set) var activeHeadingID: Int?

    private var parseTask: Task<Void, Never>?
    private var topLine = 0

    func textDidChange(_ text: String, immediately: Bool = false) {
        parseTask?.cancel()
        parseTask = Task { [weak self] in
            if !immediately {
                try? await Task.sleep(for: .milliseconds(250))
                if Task.isCancelled { return }
            }
            let analysis = await Task.detached(priority: .userInitiated) {
                DocumentAnalysis(text)
            }.value
            if Task.isCancelled { return }
            self?.apply(analysis)
        }
    }

    /// Report the source line at the top of the visible editor or preview.
    func setTopLine(_ line: Int) {
        topLine = line
        updateActiveHeading()
    }

    private func apply(_ analysis: DocumentAnalysis) {
        if headings != analysis.headings { headings = analysis.headings }
        if links != analysis.links { links = analysis.links }
        if stats != analysis.stats { stats = analysis.stats }
        updateActiveHeading()
    }

    private func updateActiveHeading() {
        // Last heading at or above the top line (plus a little slack so a heading
        // sitting right at the top edge counts). Binary search: headings are in line order.
        let target = topLine + 1
        var low = 0
        var high = headings.count - 1
        var found: Int?
        while low <= high {
            let mid = (low + high) / 2
            if headings[mid].lineIndex <= target {
                found = headings[mid].id
                low = mid + 1
            } else {
                high = mid - 1
            }
        }
        if found != activeHeadingID { activeHeadingID = found }
    }
}
