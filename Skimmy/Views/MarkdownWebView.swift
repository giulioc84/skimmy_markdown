import SwiftUI
import WebKit
import UniformTypeIdentifiers

/// SwiftUI wrapper around the preview. The web view lives in `PreviewController`,
/// so switching modes never has to rebuild it or reload the page.
struct MarkdownWebView: NSViewRepresentable {
    let text: String
    var fontSize: Double
    let controller: PreviewController

    func makeNSView(context: Context) -> WKWebView {
        controller.makeWebView()
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        controller.update(text: text, fontSize: fontSize)
    }
}

@MainActor
final class PreviewController: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
    struct FindResult {
        var count = 0
        var index = -1
    }

    /// The preview reports the source line at the top of its viewport as it scrolls.
    var onTopLineChange: ((Int) -> Void)?
    var onOpenLink: ((String) -> Void)?
    var onDidRender: (() -> Void)?

    var documentURL: URL? {
        didSet { imageHandler.baseDirectory = documentURL?.deletingLastPathComponent() }
    }

    private var webView: WKWebView?
    private let imageHandler = LocalImageSchemeHandler()
    private var isLoaded = false
    private var latestText = ""
    private var renderedText: String?
    private var renderInFlight = false
    private var renderTask: Task<Void, Never>?
    private var fontSize: Double = 16
    private var appliedFontSize: Double?
    private var pendingSync: (line: Int, atEnd: Bool)?

    /// Pause after the last keystroke before re-rendering. Short enough to feel live,
    /// long enough that fast typing costs one render instead of one per key.
    private static let renderDelay = Duration.milliseconds(120)

    // MARK: - View lifecycle

    func makeWebView() -> WKWebView {
        if let existing = self.webView { return existing }

        let configuration = WKWebViewConfiguration()
        configuration.setURLSchemeHandler(imageHandler, forURLScheme: LocalImageSchemeHandler.scheme)
        configuration.userContentController.add(WeakScriptMessageHandler(self), name: "skimmy")

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = self
        webView.setValue(false, forKey: "drawsBackground")
        self.webView = webView

        webView.loadHTMLString(PreviewShell.html, baseURL: nil)
        return webView
    }

    func update(text: String, fontSize: Double) {
        latestText = text
        self.fontSize = fontSize
        applyFontSize()
        scheduleRender()
    }

    private func applyFontSize() {
        guard isLoaded, appliedFontSize != fontSize else { return }
        appliedFontSize = fontSize
        call("setFontSize", [fontSize])
    }

    // MARK: - Rendering

    private func scheduleRender() {
        guard isLoaded, renderedText != latestText else {
            flushPendingSync()
            return
        }
        renderTask?.cancel()
        if renderedText == nil {
            renderNow()
            return
        }
        renderTask = Task { [weak self] in
            try? await Task.sleep(for: Self.renderDelay)
            if Task.isCancelled { return }
            self?.renderNow()
        }
    }

    private func renderNow() {
        // Never queue renders behind each other: if one is running, the completion
        // below picks up whatever the latest text is by then.
        guard isLoaded, !renderInFlight, renderedText != latestText else { return }
        let text = latestText
        renderInFlight = true
        call("render", [text]) { [weak self] _ in
            guard let self else { return }
            self.renderInFlight = false
            self.renderedText = text
            if self.latestText != text {
                self.renderNow()
                return
            }
            self.flushPendingSync()
            self.onDidRender?()
        }
    }

    // MARK: - Scrolling

    /// Smoothly brings the block that starts at `line` to the top (sidebar clicks).
    func scrollToLine(_ line: Int, animated: Bool) {
        call("scrollToLine", [line, animated])
    }

    /// Follows the editor without animation. Deferred until any pending render lands,
    /// so the preview never scrolls against stale content.
    func sync(toLine line: Int, atEnd: Bool) {
        pendingSync = (line, atEnd)
        if renderedText == latestText && !renderInFlight {
            flushPendingSync()
        }
    }

    private func flushPendingSync() {
        guard isLoaded, let sync = pendingSync else { return }
        pendingSync = nil
        call("syncToLine", [sync.line, sync.atEnd])
    }

    // MARK: - Find

    func find(_ query: String, completion: @escaping (FindResult) -> Void) {
        call("find", [query]) { completion(Self.findResult(from: $0)) }
    }

    func findStep(_ direction: Int, completion: @escaping (FindResult) -> Void) {
        call("findStep", [direction]) { completion(Self.findResult(from: $0)) }
    }

    func clearFind() {
        call("findClear")
    }

    private static func findResult(from value: Any?) -> FindResult {
        guard let dictionary = value as? [String: Any] else { return FindResult() }
        return FindResult(
            count: (dictionary["count"] as? NSNumber)?.intValue ?? 0,
            index: (dictionary["index"] as? NSNumber)?.intValue ?? -1
        )
    }

    // MARK: - JavaScript bridge

    /// Calls `skimmy.<function>(...arguments)`. Arguments travel as JSON, which is a
    /// subset of JavaScript, so document text needs no hand-written escaping.
    private func call(_ function: String, _ arguments: [Any] = [], completion: ((Any?) -> Void)? = nil) {
        guard isLoaded, let webView,
              let data = try? JSONSerialization.data(withJSONObject: arguments),
              let json = String(data: data, encoding: .utf8) else {
            completion?(nil)
            return
        }
        webView.evaluateJavaScript("skimmy.\(function)(...\(json))") { result, _ in
            completion?(result)
        }
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let body = message.body as? [String: Any], let type = body["type"] as? String else { return }
        switch type {
        case "line":
            if let line = (body["line"] as? NSNumber)?.intValue { onTopLineChange?(line) }
        case "link":
            if let href = body["href"] as? String { onOpenLink?(href) }
        default:
            break
        }
    }

    // MARK: - WKNavigationDelegate

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        isLoaded = true
        applyFontSize()
        scheduleRender()
    }

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        // The preview is a single page that never navigates. Only the initial load of
        // the shell is allowed; anything else a document tries is cancelled, and a
        // clicked link is handed to the app instead.
        if navigationAction.request.url?.scheme == "about" {
            decisionHandler(.allow)
            return
        }
        if navigationAction.navigationType == .linkActivated, let url = navigationAction.request.url {
            onOpenLink?(url.absoluteString)
        }
        decisionHandler(.cancel)
    }
}

/// `WKUserContentController` retains its handlers; going through a weak reference
/// lets the controller (and its web view) be released when the window closes.
private final class WeakScriptMessageHandler: NSObject, WKScriptMessageHandler {
    private weak var target: WKScriptMessageHandler?

    init(_ target: WKScriptMessageHandler) {
        self.target = target
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        target?.userContentController(userContentController, didReceive: message)
    }
}

/// Serves images that a document references by local path (`![](docs/shot.png)`),
/// which a web view cannot load by itself. Images only, nothing else from disk.
final class LocalImageSchemeHandler: NSObject, WKURLSchemeHandler {
    static let scheme = "skimmy-file"

    var baseDirectory: URL?

    func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
        guard let requestURL = urlSchemeTask.request.url,
              let fileURL = resolve(requestURL),
              let type = UTType(filenameExtension: fileURL.pathExtension),
              type.conforms(to: .image),
              let data = try? Data(contentsOf: fileURL, options: .mappedIfSafe) else {
            urlSchemeTask.didFailWithError(URLError(.fileDoesNotExist))
            return
        }
        let response = URLResponse(
            url: requestURL,
            mimeType: type.preferredMIMEType ?? "application/octet-stream",
            expectedContentLength: data.count,
            textEncodingName: nil
        )
        urlSchemeTask.didReceive(response)
        urlSchemeTask.didReceive(data)
        urlSchemeTask.didFinish()
    }

    func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {
        // Requests are answered synchronously in `start`, so there is nothing to cancel.
    }

    /// `skimmy-file://rel/<path>` is relative to the document; `skimmy-file://abs/<path>` is absolute.
    private func resolve(_ url: URL) -> URL? {
        let path = url.path
        guard !path.isEmpty else { return nil }
        switch url.host {
        case "abs":
            return URL(fileURLWithPath: path).standardizedFileURL
        case "rel":
            guard let baseDirectory else { return nil }
            return baseDirectory.appendingPathComponent(String(path.dropFirst())).standardizedFileURL
        default:
            return nil
        }
    }
}

/// The static page the preview runs in: styles, the markdown parser and the preview
/// engine. Built once per launch and shared by every window.
enum PreviewShell {
    static let html: String = {
        let nonce = UUID().uuidString
        // Documents can contain raw HTML. This policy lets only the app's own script
        // and stylesheet run (they carry the nonce), which blocks <script> tags and
        // inline handlers such as onerror= in document content, and forbids frames,
        // forms and plugins. Images may come from the web or from local files.
        let policy = [
            "default-src 'none'",
            "script-src 'nonce-\(nonce)'",
            "style-src-elem 'nonce-\(nonce)'",
            "style-src-attr 'unsafe-inline'",
            "img-src https: http: data: \(LocalImageSchemeHandler.scheme):",
            "media-src https: http: data:",
            "base-uri 'none'",
            "form-action 'none'",
        ].joined(separator: "; ")

        return """
        <!DOCTYPE html>
        <html>
        <head>
        <meta charset="utf-8">
        <meta http-equiv="Content-Security-Policy" content="\(policy)">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <style nonce="\(nonce)">\(resource("preview", "css"))</style>
        </head>
        <body>
        <div id="content"></div>
        <script nonce="\(nonce)">\(resource("marked.min", "js"))</script>
        <script nonce="\(nonce)">\(resource("preview", "js"))</script>
        </body>
        </html>
        """
    }()

    private static func resource(_ name: String, _ ext: String) -> String {
        guard let url = Bundle.main.url(forResource: name, withExtension: ext),
              let contents = try? String(contentsOf: url, encoding: .utf8) else {
            assertionFailure("Missing bundled resource \(name).\(ext)")
            return ""
        }
        return contents
    }
}
