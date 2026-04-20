import SwiftUI
import WebKit

class ScrollProxy: ObservableObject {
    weak var webView: WKWebView?
    var isLoaded = false
    private var pendingScrollID: String?

    func scrollTo(_ headingID: String) {
        guard !headingID.isEmpty else { return }
        if isLoaded, let webView = webView {
            let escaped = headingID.replacingOccurrences(of: "'", with: "\\'")
            webView.evaluateJavaScript("scrollToHeading('\(escaped)');")
        } else {
            pendingScrollID = headingID
        }
    }

    func didFinishLoading() {
        isLoaded = true
        if let scrollID = pendingScrollID {
            pendingScrollID = nil
            scrollTo(scrollID)
        }
    }
}

struct MarkdownWebView: NSViewRepresentable {
    let text: String
    var fontSize: Double
    var scrollProxy: ScrollProxy?

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.setValue(false, forKey: "drawsBackground")
        context.coordinator.webView = webView
        context.coordinator.scrollProxy = scrollProxy
        scrollProxy?.webView = webView

        let html = Self.buildHTML(markdown: text, fontSize: fontSize)
        webView.loadHTMLString(html, baseURL: nil)
        context.coordinator.lastText = text
        context.coordinator.lastFontSize = fontSize

        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        let coordinator = context.coordinator

        if !coordinator.isLoaded {
            coordinator.pendingText = text
            coordinator.pendingFontSize = fontSize
            return
        }

        if coordinator.lastFontSize != fontSize {
            coordinator.lastFontSize = fontSize
            let js = "document.body.style.fontSize = '\(fontSize)px';"
            webView.evaluateJavaScript(js)
        }

        if coordinator.lastText != text {
            coordinator.lastText = text
            let escaped = text
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "`", with: "\\`")
                .replacingOccurrences(of: "$", with: "\\$")
            webView.evaluateJavaScript("updateContent(`\(escaped)`);")
        }
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        weak var webView: WKWebView?
        var scrollProxy: ScrollProxy?
        var isLoaded = false
        var lastText = ""
        var lastFontSize: Double = 16
        var pendingText: String?
        var pendingFontSize: Double?

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            isLoaded = true

            if let fontSize = pendingFontSize, fontSize != lastFontSize {
                lastFontSize = fontSize
                webView.evaluateJavaScript("document.body.style.fontSize = '\(fontSize)px';")
            }

            if let text = pendingText, text != lastText {
                lastText = text
                let escaped = text
                    .replacingOccurrences(of: "\\", with: "\\\\")
                    .replacingOccurrences(of: "`", with: "\\`")
                    .replacingOccurrences(of: "$", with: "\\$")
                webView.evaluateJavaScript("updateContent(`\(escaped)`);")
            }

            pendingText = nil
            pendingFontSize = nil
            scrollProxy?.didFinishLoading()
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            if navigationAction.navigationType == .linkActivated,
               let url = navigationAction.request.url {
                NSWorkspace.shared.open(url)
                decisionHandler(.cancel)
                return
            }
            decisionHandler(.allow)
        }
    }

    // MARK: - HTML Template

    private static func buildHTML(markdown: String, fontSize: Double) -> String {
        guard let jsURL = Bundle.main.url(forResource: "marked", withExtension: "min.js"),
              let jsCode = try? String(contentsOf: jsURL, encoding: .utf8) else {
            return "<html><body>Error: Could not load marked.js</body></html>"
        }

        let escaped = markdown
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "`", with: "\\`")
            .replacingOccurrences(of: "$", with: "\\$")

        return """
        <!DOCTYPE html>
        <html>
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <style>
        \(Self.cssStyles(fontSize: fontSize))
        </style>
        <script>\(jsCode)</script>
        </head>
        <body>
        <div id="content"></div>
        <script>
        \(Self.jsSetup)

        updateContent(`\(escaped)`);
        </script>
        </body>
        </html>
        """
    }

    private static let jsSetup = """
    function kebabCase(str) {
        return str.split(/[^a-zA-Z0-9]+/).filter(s => s.length > 0).map(s => s.toLowerCase()).join('-');
    }

    const renderer = new marked.Renderer();

    renderer.heading = function({ tokens, depth }) {
        const text = this.parser.parseInline(tokens);
        const stripped = text.replace(/<[^>]*>/g, '');
        const decoded = stripped.replace(/&amp;/g, '&').replace(/&lt;/g, '<').replace(/&gt;/g, '>').replace(/&quot;/g, '"').replace(/&#39;/g, "'");
        const id = kebabCase(decoded);
        return `<h${depth} id="${id}">${text}</h${depth}>`;
    };

    marked.setOptions({
        renderer: renderer,
        gfm: true,
        breaks: false
    });

    function updateContent(md) {
        const scrollMax = document.documentElement.scrollHeight - document.documentElement.clientHeight;
        const scrollRatio = scrollMax > 0 ? window.scrollY / scrollMax : 0;

        const el = document.getElementById('content');
        el.textContent = '';
        const parsed = marked.parse(md);
        const template = document.createElement('template');
        // marked.js sanitizes output; this is a local-only document renderer
        template.innerHTML = parsed;
        el.appendChild(template.content);

        const newMax = document.documentElement.scrollHeight - document.documentElement.clientHeight;
        if (newMax > 0) {
            window.scrollTo(0, scrollRatio * newMax);
        }
    }

    function scrollToHeading(id) {
        const el = document.getElementById(id);
        if (el) {
            el.scrollIntoView({ behavior: 'smooth', block: 'start' });
        }
    }
    """

    private static func cssStyles(fontSize: Double) -> String { """
    :root {
        color-scheme: light dark;
    }
    body {
        font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", "Noto Sans",
                     Helvetica, Arial, sans-serif;
        font-size: \(fontSize)px;
        line-height: 1.6;
        color: #1f2328;
        background: transparent;
        margin: 0;
        padding: 24px 32px;
        word-wrap: break-word;
    }
    @media (prefers-color-scheme: dark) {
        body { color: #e6edf3; }
        a { color: #58a6ff; }
        code, pre { background: #161b22; }
        pre { border-color: #30363d; }
        blockquote { border-color: #30363d; color: #8b949e; }
        table th, table td { border-color: #30363d; }
        table tr:nth-child(2n) { background: #161b22; }
        hr { background: #30363d; }
        img { opacity: 0.9; }
    }
    a { color: #0969da; text-decoration: none; }
    a:hover { text-decoration: underline; }
    h1, h2, h3, h4, h5, h6 {
        margin-top: 24px;
        margin-bottom: 16px;
        font-weight: 600;
        line-height: 1.25;
    }
    h1 { font-size: 2em; padding-bottom: 0.3em; border-bottom: 1px solid #d1d9e0; }
    h2 { font-size: 1.5em; padding-bottom: 0.3em; border-bottom: 1px solid #d1d9e0; }
    @media (prefers-color-scheme: dark) {
        h1, h2 { border-bottom-color: #30363d; }
    }
    h3 { font-size: 1.25em; }
    h4 { font-size: 1em; }
    h5 { font-size: 0.875em; }
    h6 { font-size: 0.85em; color: #656d76; }
    p { margin-top: 0; margin-bottom: 16px; }
    code {
        padding: 0.2em 0.4em;
        font-size: 85%;
        background: #eff1f3;
        border-radius: 6px;
        font-family: ui-monospace, SFMono-Regular, "SF Mono", Menlo, monospace;
    }
    pre {
        padding: 16px;
        overflow: auto;
        font-size: 85%;
        line-height: 1.45;
        background: #f6f8fa;
        border-radius: 6px;
        border: 1px solid #d1d9e0;
    }
    pre code {
        padding: 0;
        background: transparent;
        border-radius: 0;
        font-size: 100%;
    }
    blockquote {
        margin: 0 0 16px 0;
        padding: 0 1em;
        color: #656d76;
        border-left: 0.25em solid #d1d9e0;
    }
    ul, ol { padding-left: 2em; margin-bottom: 16px; }
    li + li { margin-top: 0.25em; }
    table {
        display: block;
        border-spacing: 0;
        border-collapse: collapse;
        margin-bottom: 16px;
        width: max-content;
        max-width: 100%;
        overflow: auto;
    }
    table th, table td {
        padding: 6px 13px;
        border: 1px solid #d1d9e0;
    }
    table th { font-weight: 600; }
    table tr:nth-child(2n) { background: #f6f8fa; }
    hr {
        height: 0.25em;
        padding: 0;
        margin: 24px 0;
        background: #d1d9e0;
        border: 0;
    }
    img { max-width: 100%; height: auto; }
    input[type="checkbox"] { margin-right: 0.5em; }
    """ }
}
