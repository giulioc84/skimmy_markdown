import SwiftUI
import WebKit

class ScrollProxy: ObservableObject {
    weak var webView: WKWebView?
    var isLoaded = false
    private var pendingScrollID: String?

    func scrollTo(_ headingID: String) {
        guard !headingID.isEmpty else { return }
        if isLoaded, let webView = webView {
            webView.evaluateJavaScript("scrollToHeading(\(MarkdownWebView.jsStringLiteral(headingID)));")
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
            webView.evaluateJavaScript("updateContent(\(MarkdownWebView.jsStringLiteral(text)));")
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
                webView.evaluateJavaScript("updateContent(\(MarkdownWebView.jsStringLiteral(text)));")
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
            decisionHandler(MarkdownWebView.navigationPolicy(
                url: navigationAction.request.url,
                isLinkClick: navigationAction.navigationType == .linkActivated,
                isMainFrame: navigationAction.targetFrame?.isMainFrame ?? false,
                open: { NSWorkspace.shared.open($0) }
            ))
        }
    }

    // MARK: - HTML Template

    // MARK: - Safety helpers

    /// Encodes any string as a JavaScript string literal that is safe to embed
    /// both in `evaluateJavaScript` and inside an inline `<script>` element.
    static func jsStringLiteral(_ string: String) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: [string], options: [.fragmentsAllowed]),
              var json = String(data: data, encoding: .utf8) else { return "\"\"" }
        json.removeFirst() // drop "["
        json.removeLast()  // drop "]"
        // Never let "<", ">" or "&" appear literally, so the literal cannot close
        // the surrounding <script> element; also escape JS line separators.
        return json
            .replacingOccurrences(of: "<", with: "\\u003c")
            .replacingOccurrences(of: ">", with: "\\u003e")
            .replacingOccurrences(of: "&", with: "\\u0026")
            .replacingOccurrences(of: "\u{2028}", with: "\\u2028")
            .replacingOccurrences(of: "\u{2029}", with: "\\u2029")
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

    static func buildHTML(markdown: String, fontSize: Double) -> String {
        guard let jsURL = Bundle.main.url(forResource: "marked", withExtension: "min.js"),
              let jsCode = try? String(contentsOf: jsURL, encoding: .utf8) else {
            return "<html><body>Error: Could not load marked.js</body></html>"
        }

        // A fresh nonce per page: only our own two <script> blocks may run.
        // Inline event handlers (onerror=…) can never carry a nonce, so the
        // Content-Security-Policy blocks them even if the sanitizer missed one.
        let nonce = UUID().uuidString.replacingOccurrences(of: "-", with: "")

        return """
        <!DOCTYPE html>
        <html>
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <meta http-equiv="Content-Security-Policy" content="default-src 'none'; script-src 'nonce-\(nonce)'; style-src 'unsafe-inline'; img-src http: https: data:; media-src http: https:; font-src data:; form-action 'none'; base-uri 'none'">
        <style>
        \(Self.cssStyles(fontSize: fontSize))
        </style>
        <script nonce="\(nonce)">\(jsCode)</script>
        </head>
        <body>
        <div id="content"></div>
        <script nonce="\(nonce)">
        \(Self.jsSetup)

        updateContent(\(Self.jsStringLiteral(markdown)));
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

    // Markdown may contain raw HTML. marked.js does NOT sanitize it, so every
    // rendered node goes through this allowlist before it reaches the page:
    // unknown elements are unwrapped (their text kept), dangerous ones are
    // dropped, and only harmless attributes with safe URLs survive.
    const DROP = new Set(['SCRIPT','STYLE','IFRAME','FRAME','FRAMESET','OBJECT','EMBED','APPLET',
        'LINK','META','BASE','FORM','BUTTON','SELECT','TEXTAREA','OPTION','TEMPLATE','NOSCRIPT',
        'SVG','MATH','PORTAL','DIALOG']);
    const KEEP = new Set(['A','ABBR','B','BLOCKQUOTE','BR','CAPTION','CITE','CODE','DD','DEL','DETAILS',
        'DFN','DIV','DL','DT','EM','FIGCAPTION','FIGURE','H1','H2','H3','H4','H5','H6','HR','I','IMG',
        'INPUT','INS','KBD','LI','MARK','OL','P','PRE','Q','S','SAMP','SMALL','SPAN','STRIKE','STRONG',
        'SUB','SUMMARY','SUP','TABLE','TBODY','TD','TFOOT','TH','THEAD','TR','TT','U','UL','VAR',
        'PICTURE','SOURCE','VIDEO','AUDIO']);
    const ATTRS = new Set(['href','src','srcset','alt','title','id','name','align','colspan','rowspan',
        'start','width','height','type','checked','disabled','open','lang','dir','controls','loop',
        'muted','poster','media','reversed','scope','abbr','datetime','cite']);
    const URL_ATTRS = new Set(['href','src','poster','cite']);

    function safeURL(value, attr) {
        const v = value.trim().replace(/[\\u0000-\\u0020]/g, '');
        if (v.startsWith('#')) return attr === 'href';
        const m = v.match(/^([a-zA-Z][a-zA-Z0-9+.-]*):/);
        if (!m) return false;                       // no base URL: relative links can't resolve
        const scheme = m[1].toLowerCase();
        if (scheme === 'http' || scheme === 'https') return true;
        if (scheme === 'mailto') return attr === 'href';
        if (scheme === 'data') return attr === 'src' && /^data:image\\/(png|gif|jpe?g|webp|bmp)[;,]/i.test(v);
        return false;
    }

    function sanitize(node) {
        for (const child of Array.from(node.childNodes)) {
            if (child.nodeType === Node.COMMENT_NODE) { child.remove(); continue; }
            if (child.nodeType !== Node.ELEMENT_NODE) continue;
            const tag = child.tagName.toUpperCase();
            if (DROP.has(tag)) { child.remove(); continue; }
            if (!KEEP.has(tag)) {
                sanitize(child);
                const inner = document.createDocumentFragment();
                while (child.firstChild) inner.appendChild(child.firstChild);
                child.replaceWith(inner);
                continue;
            }
            for (const attr of Array.from(child.attributes)) {
                const name = attr.name.toLowerCase();
                let ok = ATTRS.has(name);
                if (ok && URL_ATTRS.has(name)) ok = safeURL(attr.value, name);
                if (ok && name === 'srcset') ok = attr.value.split(/,\\s+/).every(p => safeURL(p.trim().split(/\\s+/)[0] || '', 'src'));
                if (ok && name === 'type' && tag === 'INPUT') ok = attr.value.toLowerCase() === 'checkbox';
                if (!ok) child.removeAttribute(attr.name);
            }
            if (tag === 'INPUT') {
                if ((child.getAttribute('type') || '').toLowerCase() !== 'checkbox') { child.remove(); continue; }
                child.setAttribute('disabled', '');
            }
            if (tag === 'A' && child.hasAttribute('href')) child.setAttribute('rel', 'noopener noreferrer');
            sanitize(child);
        }
    }

    function updateContent(md) {
        const scrollMax = document.documentElement.scrollHeight - document.documentElement.clientHeight;
        const scrollRatio = scrollMax > 0 ? window.scrollY / scrollMax : 0;

        const el = document.getElementById('content');
        el.textContent = '';
        const parsed = marked.parse(md);
        // Parse into an inert document (nothing runs or loads there), clean it,
        // and only then move the nodes into the live page.
        const doc = new DOMParser().parseFromString('<body>' + parsed, 'text/html');
        sanitize(doc.body);
        const fragment = document.createDocumentFragment();
        while (doc.body.firstChild) fragment.appendChild(document.adoptNode(doc.body.firstChild));
        el.replaceChildren(fragment);

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
