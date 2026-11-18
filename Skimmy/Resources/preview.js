// Skimmy preview engine. Runs inside the WKWebView; the app talks to it
// through the `skimmy` object and hears back through the `skimmy` message handler.
//
// Rendering is incremental: the document is split into top-level blocks and only
// the blocks that changed since the last render are re-parsed and swapped in the DOM.
const skimmy = (() => {
    'use strict';

    const content = document.getElementById('content');
    const options = { gfm: true, breaks: false };
    const TOP_PAD = 16;

    /** @type {{key: string, line: number, lines: number, nodes: Node[]}[]} */
    let blocks = [];
    let defsKey = '';
    let lineCount = 1;

    const post = (message) => {
        const handler = window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.skimmy;
        if (handler) handler.postMessage(message);
    };

    // ---- Splitting the source into blocks -------------------------------------

    const VOID_TAG = /^(area|base|br|col|embed|hr|img|input|link|meta|source|track|wbr)$/i;
    const TAG = /<(\/?)([a-zA-Z][\w:-]*)(?:"[^"]*"|'[^']*'|[^'">])*?(\/?)>/g;

    /** Net number of HTML elements a raw-HTML chunk leaves open. */
    function openTagBalance(html) {
        let depth = 0;
        const text = html.replace(/<!--[\s\S]*?-->/g, '');
        TAG.lastIndex = 0;
        let match;
        while ((match = TAG.exec(text))) {
            if (match[3] || VOID_TAG.test(match[2])) continue;
            depth += match[1] ? -1 : 1;
        }
        return depth;
    }

    function countNewlines(text) {
        let count = 0;
        for (let i = text.indexOf('\n'); i !== -1; i = text.indexOf('\n', i + 1)) count++;
        return count;
    }

    function split(source) {
        const lexer = new marked.Lexer(options);
        // Block-level pass only; inline parsing is deferred to the blocks that changed.
        const tokens = lexer.blockTokens(source.replace(/\r\n|\r/g, '\n'), []);
        const result = [];
        let line = 0;
        for (let i = 0; i < tokens.length; i++) {
            const token = tokens[i];
            let raw = token.raw;
            let grouped = false;
            if (token.type === 'html') {
                // Raw HTML such as <details> can wrap the blocks that follow it.
                // Keep the whole run together so it nests the way it would in one pass.
                let depth = openTagBalance(raw);
                while (depth > 0 && i + 1 < tokens.length) {
                    const next = tokens[++i];
                    raw += next.raw;
                    grouped = true;
                    if (next.type === 'html') depth += openTagBalance(next.raw);
                }
            }
            const newlines = countNewlines(raw);
            if (grouped || (token.type !== 'space' && token.type !== 'def')) {
                result.push({ key: raw, line, lines: newlines, nodes: [] });
            }
            line += newlines;
        }
        return { blocks: result, links: lexer.tokens.links, lineCount: line + 1 };
    }

    function renderBlock(raw, links) {
        const lexer = new marked.Lexer(options);
        Object.assign(lexer.tokens.links, links);
        return marked.parser(lexer.lex(raw), options);
    }

    // ---- Patching the DOM ------------------------------------------------------

    function slug(text) {
        return text.trim().toLowerCase().replace(/[^\p{L}\p{N}\s_-]/gu, '').replace(/\s+/g, '-');
    }

    function assignHeadingIDs() {
        const seen = new Map();
        for (const heading of content.querySelectorAll('h1,h2,h3,h4,h5,h6')) {
            const base = slug(heading.textContent) || 'section';
            const n = seen.get(base) || 0;
            seen.set(base, n + 1);
            const id = n ? base + '-' + n : base;
            if (heading.id !== id) heading.id = id;
        }
    }

    const HAS_SCHEME = /^([a-z][a-z0-9+.-]*:|\/\/|#)/i;

    /** Point images with local paths at the app, which serves them from disk. */
    function localizeImages(root) {
        for (const image of root.querySelectorAll('img[src]')) {
            let src = image.getAttribute('src');
            if (/^file:\/\//i.test(src)) src = src.replace(/^file:\/\/(localhost)?/i, '');
            else if (HAS_SCHEME.test(src)) continue;
            try { src = decodeURI(src); } catch (_) { /* keep as written */ }
            const absolute = src.startsWith('/');
            const path = absolute ? src : '/' + src.replace(/^\.\//, '');
            image.setAttribute('src', 'skimmy-file://' + (absolute ? 'abs' : 'rel') + encodeURI(path).replace(/[?#]/g, encodeURIComponent));
        }
    }

    function render(source) {
        const next = split(source);
        const nextDefsKey = JSON.stringify(next.links);
        if (nextDefsKey !== defsKey) {
            // Reference definitions changed: any block may resolve differently.
            for (const block of blocks) for (const node of block.nodes) node.remove();
            blocks = [];
            defsKey = nextDefsKey;
        }
        const fresh = next.blocks;
        lineCount = next.lineCount;

        let start = 0;
        while (start < blocks.length && start < fresh.length && blocks[start].key === fresh[start].key) {
            fresh[start].nodes = blocks[start].nodes;
            start++;
        }
        let oldEnd = blocks.length - 1;
        let newEnd = fresh.length - 1;
        while (oldEnd >= start && newEnd >= start && blocks[oldEnd].key === fresh[newEnd].key) {
            fresh[newEnd].nodes = blocks[oldEnd].nodes;
            oldEnd--;
            newEnd--;
        }

        const changed = oldEnd >= start || newEnd >= start;
        for (let i = start; i <= oldEnd; i++) {
            for (const node of blocks[i].nodes) node.remove();
        }
        if (newEnd >= start) {
            let anchor = null;
            for (let i = newEnd + 1; i < fresh.length && !anchor; i++) {
                if (fresh[i].nodes.length) anchor = fresh[i].nodes[0];
            }
            const fragment = document.createDocumentFragment();
            for (let i = start; i <= newEnd; i++) {
                const template = document.createElement('template');
                template.innerHTML = renderBlock(fresh[i].key, next.links);
                localizeImages(template.content);
                fresh[i].nodes = Array.from(template.content.childNodes);
                fragment.appendChild(template.content);
            }
            content.insertBefore(fragment, anchor);
        }
        blocks = fresh;

        if (changed) {
            assignHeadingIDs();
            if (findQuery) find(findQuery);
        }
        return newEnd - start + 1;
    }

    // ---- Scrolling by source line ----------------------------------------------

    function elementOf(index) {
        for (let i = index; i < blocks.length; i++) {
            for (const node of blocks[i].nodes) {
                if (node.nodeType === 1) return node;
            }
        }
        return null;
    }

    function blockIndexForLine(line) {
        let low = 0;
        let high = blocks.length - 1;
        let found = 0;
        while (low <= high) {
            const mid = (low + high) >> 1;
            if (blocks[mid].line <= line) { found = mid; low = mid + 1; } else { high = mid - 1; }
        }
        return found;
    }

    function offsetForLine(line) {
        if (!blocks.length) return 0;
        const index = blockIndexForLine(line);
        const block = blocks[index];
        const element = elementOf(index);
        if (!element) return document.documentElement.scrollHeight;
        const rect = element.getBoundingClientRect();
        const span = Math.max(1, block.lines);
        const fraction = Math.min(1, Math.max(0, (line - block.line) / span));
        return rect.top + window.scrollY - TOP_PAD + fraction * rect.height;
    }

    function scrollToLine(line, smooth) {
        window.scrollTo({ top: offsetForLine(line), behavior: smooth ? 'smooth' : 'instant' });
        return 0;
    }

    /** Follow the editor: `line` may be fractional; `atEnd` pins the preview to the bottom. */
    function syncToLine(line, atEnd) {
        const top = atEnd ? document.documentElement.scrollHeight : (line <= 0 ? 0 : offsetForLine(line));
        window.scrollTo({ top, behavior: 'instant' });
        return 0;
    }

    function topLine() {
        const edge = TOP_PAD + 8;
        let low = 0;
        let high = blocks.length - 1;
        let found = -1;
        while (low <= high) {
            const mid = (low + high) >> 1;
            const element = elementOf(mid);
            if (element && element.getBoundingClientRect().top <= edge) { found = mid; low = mid + 1; } else { high = mid - 1; }
        }
        return found < 0 ? 0 : blocks[found].line;
    }

    let scrollQueued = false;
    let lastReportedLine = -1;
    window.addEventListener('scroll', () => {
        if (scrollQueued) return;
        scrollQueued = true;
        requestAnimationFrame(() => {
            scrollQueued = false;
            const line = topLine();
            if (line !== lastReportedLine) {
                lastReportedLine = line;
                post({ type: 'line', line });
            }
        });
    }, { passive: true });

    // Keep the same content at the top when the pane changes width (window resize,
    // switching between Read and Split), instead of keeping the same pixel offset.
    let anchor = null;
    function captureAnchor() {
        const edge = TOP_PAD + 8;
        let low = 0;
        let high = blocks.length - 1;
        let found = -1;
        while (low <= high) {
            const mid = (low + high) >> 1;
            const element = elementOf(mid);
            if (element && element.getBoundingClientRect().top <= edge) { found = mid; low = mid + 1; } else { high = mid - 1; }
        }
        const element = found < 0 ? null : elementOf(found);
        if (!element || window.scrollY <= 0) return null;
        const rect = element.getBoundingClientRect();
        return { element, fraction: rect.height > 0 ? Math.min(1, Math.max(0, (edge - rect.top) / rect.height)) : 0, edge };
    }
    window.addEventListener('scroll', () => { anchor = null; }, { passive: true });
    let lastWidth = window.innerWidth;
    window.addEventListener('resize', () => {
        if (window.innerWidth === lastWidth) return;
        lastWidth = window.innerWidth;
        if (anchor && anchor.element.isConnected) {
            const rect = anchor.element.getBoundingClientRect();
            const top = rect.top + window.scrollY + anchor.fraction * rect.height - anchor.edge;
            const keep = anchor;
            window.scrollTo({ top, behavior: 'instant' });
            // scrollTo fires a scroll event that would drop the anchor mid-resize.
            requestAnimationFrame(() => { anchor = keep; });
        }
    });
    // Capture lazily: remember where we were once scrolling has settled.
    let settle = 0;
    window.addEventListener('scroll', () => {
        clearTimeout(settle);
        settle = setTimeout(() => { anchor = captureAnchor(); }, 120);
    }, { passive: true });

    // ---- Links -----------------------------------------------------------------

    document.addEventListener('click', (event) => {
        const anchor = event.target.closest && event.target.closest('a[href]');
        if (!anchor) return;
        event.preventDefault();
        const href = anchor.getAttribute('href');
        if (href.startsWith('#')) {
            let id = href.slice(1);
            try { id = decodeURIComponent(id); } catch (_) { /* keep the raw id */ }
            const target = document.getElementById(id) || document.getElementsByName(id)[0];
            if (target) target.scrollIntoView({ behavior: 'smooth', block: 'start' });
        } else {
            post({ type: 'link', href });
        }
    });

    // ---- Find ------------------------------------------------------------------

    const MAX_MATCHES = 5000;
    const canHighlight = typeof CSS !== 'undefined' && CSS.highlights && typeof Highlight !== 'undefined';
    let findQuery = '';
    let matches = [];
    let current = -1;

    function clearHighlights() {
        if (canHighlight) {
            CSS.highlights.delete('skimmy-find');
            CSS.highlights.delete('skimmy-find-current');
        } else {
            window.getSelection().removeAllRanges();
        }
    }

    function showCurrent(scroll) {
        if (current < 0 || current >= matches.length) return;
        const range = matches[current];
        if (canHighlight) {
            CSS.highlights.set('skimmy-find-current', new Highlight(range));
        } else {
            const selection = window.getSelection();
            selection.removeAllRanges();
            selection.addRange(range);
        }
        if (scroll) {
            const rect = range.getBoundingClientRect();
            if (rect.top < 60 || rect.bottom > window.innerHeight - 60) {
                window.scrollTo({ top: rect.top + window.scrollY - window.innerHeight / 3, behavior: 'instant' });
            }
        }
    }

    function find(query) {
        const keep = query === findQuery ? current : -1;
        findQuery = query;
        matches = [];
        current = -1;
        clearHighlights();
        if (!query) return { count: 0, index: -1 };

        const needle = query.toLowerCase();
        const walker = document.createTreeWalker(content, NodeFilter.SHOW_TEXT);
        let node;
        while ((node = walker.nextNode()) && matches.length < MAX_MATCHES) {
            const haystack = node.nodeValue.toLowerCase();
            for (let at = haystack.indexOf(needle); at !== -1 && matches.length < MAX_MATCHES; at = haystack.indexOf(needle, at + needle.length)) {
                const range = document.createRange();
                range.setStart(node, at);
                range.setEnd(node, at + needle.length);
                matches.push(range);
            }
        }
        if (matches.length) {
            if (canHighlight) CSS.highlights.set('skimmy-find', new Highlight(...matches));
            if (keep >= 0) {
                current = Math.min(keep, matches.length - 1);
                showCurrent(false);
            } else {
                // Start from the first match at or below the top of the viewport.
                current = matches.findIndex((range) => range.getBoundingClientRect().bottom >= 0);
                if (current < 0) current = 0;
                showCurrent(true);
            }
        }
        return { count: matches.length, index: current };
    }

    function findStep(direction) {
        if (!matches.length) return { count: 0, index: -1 };
        current = (current + direction + matches.length) % matches.length;
        showCurrent(true);
        return { count: matches.length, index: current };
    }

    function findClear() {
        findQuery = '';
        matches = [];
        current = -1;
        clearHighlights();
        return 0;
    }

    function setFontSize(px) {
        document.documentElement.style.setProperty('--font-size', px + 'px');
        return 0;
    }

    return { render, scrollToLine, syncToLine, find, findStep, findClear, setFontSize };
})();
