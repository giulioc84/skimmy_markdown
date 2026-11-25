import SwiftUI
import WebKit

final class ScrollProxy {
    weak var webView: WKWebView?
    var isLoaded = false
    private var pendingJump: (script: String, arguments: [String: Any])?

    func scrollTo(_ heading: DocumentHeading) {
        jump("scrollToHeading(anchor, occurrence)", arguments: [
            "anchor": heading.anchor,
            "occurrence": heading.occurrence
        ])
    }

    func didFinishLoading() {
        isLoaded = true
        if let pendingJump {
            self.pendingJump = nil
            jump(pendingJump.script, arguments: pendingJump.arguments)
        }
    }

    func finishEditing(completion: @escaping () -> Void) {
        guard isLoaded, let webView else {
            completion()
            return
        }
        webView.evaluateJavaScript("finishEditing()", completionHandler: { _, _ in completion() })
    }

    func follow(_ destination: String) {
        if destination.hasPrefix("#") {
            jump("scrollToFragment(hash)", arguments: ["hash": destination])
        } else if let url = URL(string: destination) {
            MarkdownWebView.openExternally(url)
        }
    }

    func find(_ query: String, backwards: Bool, completion: @escaping (Bool?) -> Void) {
        guard isLoaded, let webView else {
            completion(nil)
            return
        }
        webView.callAsyncJavaScript(
            "return findMarkdownMatch(query, backwards)",
            arguments: ["query": query, "backwards": backwards],
            in: nil,
            in: .page,
            completionHandler: { result in completion((try? result.get()) as? Bool) }
        )
    }

    func replace(_ query: String, with replacement: String, all: Bool, completion: @escaping (Int?) -> Void) {
        guard isLoaded, let webView else {
            completion(nil)
            return
        }
        webView.callAsyncJavaScript(
            "return replaceMarkdownMatches(query, replacement, all)",
            arguments: ["query": query, "replacement": replacement, "all": all],
            in: nil,
            in: .page,
            completionHandler: { result in completion((try? result.get()) as? Int) }
        )
    }

    func applyFormat(_ format: MarkdownFormat, linkURL: String?, linkText: String?) {
        guard isLoaded, let webView else { return }
        webView.window?.makeFirstResponder(webView)
        webView.callAsyncJavaScript(
            "return applyMarkdownFormat(action, linkURL, linkText)",
            arguments: [
                "action": format.rawValue,
                "linkURL": linkURL.map { $0 as Any } ?? NSNull(),
                "linkText": linkText.map { $0 as Any } ?? NSNull()
            ],
            in: nil,
            in: .page,
            completionHandler: { result in
                guard (try? result.get()) as? Bool == false else { return }
                NSSound.beep()
                AccessibilityNotification.Announcement("Formatting is unavailable for this selection.").post()
            }
        )
    }

    func loadLinkContext(_ completion: @escaping ([String: String]) -> Void) {
        guard isLoaded, let webView else {
            completion([:])
            return
        }
        webView.callAsyncJavaScript(
            "return markdownLinkContext()",
            in: nil,
            in: .page,
            completionHandler: { result in completion((try? result.get()) as? [String: String] ?? [:]) }
        )
    }

    func endFind(clearingSelection: Bool) {
        guard let webView else { return }
        webView.window?.makeFirstResponder(webView)
        webView.callAsyncJavaScript(
            """
            const selection = window.getSelection();
            if (content.isContentEditable) {
                content.focus({ preventScroll: true });
            }
            if (clearingSelection && !selection.isCollapsed && content.contains(selection.anchorNode)) {
                selection.collapseToEnd();
            }
            """,
            arguments: ["clearingSelection": clearingSelection],
            in: nil,
            in: .page
        )
    }

    private func jump(_ script: String, arguments: [String: Any]) {
        if isLoaded, let webView {
            webView.callAsyncJavaScript(script, arguments: arguments, in: nil, in: .page)
        } else {
            pendingJump = (script, arguments)
        }
    }
}

struct MarkdownWebView: NSViewRepresentable {
    @Binding var text: String
    var fontSize: Double
    var scrollProxy: ScrollProxy?
    var isEditing = false
    var onUndo: (() -> Void)?
    var onRedo: (() -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: config)
        let coordinator = context.coordinator
        config.userContentController.add(coordinator, name: "skimmy")
        webView.navigationDelegate = coordinator
        webView.setValue(false, forKey: "drawsBackground")
        scrollProxy?.webView = webView
        scrollProxy?.isLoaded = false
        webView.loadHTMLString(Self.html, baseURL: nil)
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        let coordinator = context.coordinator
        coordinator.parent = self
        coordinator.update(webView)
    }

    static func dismantleNSView(_ webView: WKWebView, coordinator: Coordinator) {
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "skimmy")
        if let proxy = coordinator.parent.scrollProxy, proxy.webView === webView {
            proxy.webView = nil
            proxy.isLoaded = false
        }
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var parent: MarkdownWebView
        private var isLoaded = false
        private var displayedText: String?
        private var displayedFontSize: Double?
        private var editing = false
        private var revision = 0

        init(_ parent: MarkdownWebView) {
            self.parent = parent
        }

        func update(_ webView: WKWebView) {
            guard isLoaded else { return }
            let text = parent.text
            var changes: [String: Any] = [:]
            if displayedText != text {
                displayedText = text
                revision += 1
                changes["text"] = text
                changes["revision"] = revision
            }
            if displayedFontSize != parent.fontSize {
                displayedFontSize = parent.fontSize
                changes["fontSize"] = parent.fontSize
            }
            if editing != parent.isEditing {
                editing = parent.isEditing
                if editing, let window = webView.window {
                    window.makeFirstResponder(webView)
                }
                changes["editing"] = editing
            }
            if !changes.isEmpty {
                webView.callAsyncJavaScript("""
                    if ('text' in changes) updateContent(changes.text, changes.revision);
                    if ('fontSize' in changes) document.body.style.fontSize = changes.fontSize + 'px';
                    if ('editing' in changes) setEditing(changes.editing);
                    """, arguments: ["changes": changes], in: nil, in: .page)
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            isLoaded = true
            update(webView)
            parent.scrollProxy?.didFinishLoading()
        }

        func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
            isLoaded = false
            displayedText = nil
            displayedFontSize = nil
            editing = false
            parent.scrollProxy?.isLoaded = false
            webView.loadHTMLString(MarkdownWebView.html, baseURL: nil)
        }

        func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.frameInfo.isMainFrame,
                  let body = message.body as? [String: Any],
                  body["revision"] as? Int == revision else { return }

            if let markdown = body["markdown"] as? String, markdown != displayedText {
                displayedText = markdown
                parent.text = markdown
            } else if let destination = body["openLink"] as? String, let url = URL(string: destination) {
                MarkdownWebView.openExternally(url)
            } else if let action = body["action"] as? String {
                switch action {
                case "undo": parent.onUndo?()
                case "redo": parent.onRedo?()
                default: break
                }
            }
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            decisionHandler(MarkdownWebView.navigationPolicy(
                url: navigationAction.request.url,
                isLinkClick: navigationAction.navigationType == .linkActivated,
                isMainFrame: navigationAction.targetFrame?.isMainFrame ?? false,
                open: { NSWorkspace.shared.open($0) }
            ))
        }
    }

    /// URL schemes a clicked link may hand to the system. Everything else
    /// (file:, app-specific schemes, javascript:, …) is refused.
    static let externalSchemes: Set<String> = ["http", "https", "mailto"]

    /// Opens a URL from the document in its default app, but only for the
    /// schemes above. Use this for every link the user can click.
    static func openExternally(_ url: URL, open: (URL) -> Void = { NSWorkspace.shared.open($0) }) {
        guard let scheme = url.scheme?.lowercased(), externalSchemes.contains(scheme) else { return }
        open(url)
    }

    /// Decides what the preview may load. Only the app's own page loads in the
    /// view; link clicks to web/mail addresses open in the default app; in-page
    /// anchors scroll; everything else is cancelled.
    static func navigationPolicy(
        url: URL?,
        isLinkClick: Bool,
        isMainFrame: Bool,
        open: (URL) -> Void
    ) -> WKNavigationActionPolicy {
        guard let url = url, let scheme = url.scheme?.lowercased() else { return .cancel }
        if isLinkClick {
            if externalSchemes.contains(scheme) {
                openExternally(url, open: open)
                return .cancel
            }
            // "#heading" links resolve against the blank base page: scroll in place.
            if scheme == "about", url.fragment != nil { return .allow }
            return .cancel
        }
        // The page itself is loaded with loadHTMLString(baseURL: nil) → about:blank.
        if isMainFrame, scheme == "about" { return .allow }
        return .cancel
    }

    private static let html: String = {
        func resource(_ name: String, _ ext: String) -> String? {
            guard let url = Bundle.main.url(forResource: name, withExtension: ext) else { return nil }
            return try? String(contentsOf: url, encoding: .utf8)
        }

        guard let marked = resource("marked.min", "js"),
              let turndown = resource("turndown-gfm.min", "js"),
              let editor = resource("markdown-editor", "js"),
              let formatting = resource("markdown-formatting", "js"),
              let replace = resource("markdown-replace", "js"),
              let styles = resource("markdown", "css") else {
            return "<html><body>Could not load the Markdown editor.</body></html>"
        }

        let nonce = UUID().uuidString
        return """
        <!DOCTYPE html>
        <html lang="en">
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <meta http-equiv="Content-Security-Policy" content="default-src 'none'; script-src 'nonce-\(nonce)'; style-src 'unsafe-inline'; img-src http: https: data:; media-src http: https:; font-src data:; form-action 'none'; base-uri 'none'">
        <style>\(styles)</style>
        <script nonce="\(nonce)">\(marked)</script>
        <script nonce="\(nonce)">\(turndown)</script>
        </head>
        <body>
        <main id="content"></main>
        <script nonce="\(nonce)">\(editor)</script>
        <script nonce="\(nonce)">\(formatting)</script>
        <script nonce="\(nonce)">\(replace)</script>
        </body>
        </html>
        """
    }()
}
