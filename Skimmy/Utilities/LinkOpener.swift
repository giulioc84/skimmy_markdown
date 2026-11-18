import AppKit

/// Opens links found in a document. Documents can come from anywhere, so this is
/// deliberately narrow: web and mail links open normally, other markdown files open
/// in Skimmy, and any other local file is only revealed in Finder, never launched.
@MainActor
enum LinkOpener {
    private static let webSchemes: Set<String> = ["http", "https", "mailto"]
    private static let textExtensions: Set<String> = ["md", "markdown", "mdown", "txt"]

    static func open(_ href: String, relativeTo documentURL: URL?) {
        let trimmed = href.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        if let url = URL(string: trimmed), let scheme = url.scheme?.lowercased() {
            if webSchemes.contains(scheme) {
                NSWorkspace.shared.open(url)
            } else if scheme == "file" {
                openLocal(url)
            }
            return
        }

        // No scheme: a path, relative to the document or absolute.
        let withoutFragment = trimmed.split(separator: "#", maxSplits: 1, omittingEmptySubsequences: false).first.map(String.init) ?? ""
        guard !withoutFragment.isEmpty else { return }
        let path = withoutFragment.removingPercentEncoding ?? withoutFragment

        if path.hasPrefix("/") {
            openLocal(URL(fileURLWithPath: path))
        } else if let documentURL {
            openLocal(documentURL.deletingLastPathComponent().appendingPathComponent(path))
        }
    }

    private static func openLocal(_ url: URL) {
        let target = url.standardizedFileURL
        guard FileManager.default.fileExists(atPath: target.path) else { return }
        if textExtensions.contains(target.pathExtension.lowercased()) {
            NSWorkspace.shared.open(target)
        } else {
            NSWorkspace.shared.activateFileViewerSelecting([target])
        }
    }
}
