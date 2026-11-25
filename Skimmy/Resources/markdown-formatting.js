const markdownParagraphs = 'p, h1, h2, h3, h4, h5, h6, li, td, th, summary, div';
let markdownSelection;
let markdownLinkSelection;

function selectionInMarkdown() {
    const selection = window.getSelection();
    if (!selection.rangeCount) return null;
    const range = selection.getRangeAt(0);
    return content.contains(range.startContainer) && content.contains(range.endContainer) ? range : null;
}

function rememberMarkdownRange(range) {
    if (!range) return null;
    return {
        revision,
        start: range.startContainer,
        end: range.endContainer,
        startOffset: range.startOffset,
        endOffset: range.endOffset
    };
}

function recoverMarkdownRange(bookmark) {
    if (bookmark?.revision !== revision || !content.contains(bookmark.start) || !content.contains(bookmark.end)) {
        return null;
    }
    const range = document.createRange();
    try {
        range.setStart(bookmark.start, bookmark.startOffset);
        range.setEnd(bookmark.end, bookmark.endOffset);
    } catch {
        return null;
    }
    return range;
}

document.addEventListener('selectionchange', () => {
    if (!content.isContentEditable) return;
    const range = selectionInMarkdown();
    if (range) markdownSelection = rememberMarkdownRange(range);
});

function selectMarkdownRange(range) {
    const selection = window.getSelection();
    selection.removeAllRanges();
    selection.addRange(range);
    markdownSelection = rememberMarkdownRange(range);
}

function markdownElement(node) {
    return node.nodeType === Node.ELEMENT_NODE ? node : node.parentElement;
}

function sharedMarkdownElement(range, selector) {
    const start = markdownElement(range.startContainer).closest(selector);
    const end = markdownElement(range.endContainer).closest(selector);
    if (start && start === end) return start;
    if (range.startContainer === range.endContainer && range.endOffset === range.startOffset + 1) {
        const selected = range.startContainer.childNodes[range.startOffset];
        if (selected?.matches?.(selector)) return selected;
    }
    return null;
}

function markdownLinkContext() {
    markdownLinkSelection = null;
    if (!content.isContentEditable) return {};
    const range = selectionInMarkdown() ?? recoverMarkdownRange(markdownSelection);
    if (!range) return {};
    const anchor = sharedMarkdownElement(range, 'a[href], a[data-source-href]');
    if (anchor ? anchor.closest('pre, code') : !canWrapMarkdownLink(range)) return {};
    markdownLinkSelection = { bookmark: rememberMarkdownRange(range), source: markdown };
    return anchor
        ? { url: anchor.getAttribute('href') ?? anchor.dataset.sourceHref, text: anchor.textContent }
        : { text: range.toString() };
}

function editableMarkdownInline(range, additionalExcludedElements = '') {
    if (range.collapsed) return true;
    if (!sharedMarkdownElement(range, markdownParagraphs)) return false;
    // Wrapping text must not discard another link or embedded content.
    return !range.cloneContents().querySelector(
        markdownParagraphs + ', a, img, input, pre, table, picture, video, audio, hr' + additionalExcludedElements
    );
}

function canWrapMarkdownLink(range) {
    const excluded = 'a, pre, code';
    return !markdownElement(range.startContainer).closest(excluded) &&
        !markdownElement(range.endContainer).closest(excluded) &&
        editableMarkdownInline(range, ', code');
}

function withinMarkdownParagraph(range) {
    if (range.collapsed && (range.startContainer === content || range.startContainer.parentNode === content)) {
        return true;
    }
    const block = sharedMarkdownElement(range, markdownParagraphs);
    return block && !block.closest('li, blockquote') && !range.cloneContents().querySelector(markdownParagraphs);
}

function updateMarkdownCode(range) {
    if (sharedMarkdownElement(range, 'pre')) return false;
    const code = sharedMarkdownElement(range, 'code');
    if (code) {
        const text = document.createTextNode(code.textContent);
        code.replaceWith(text);
        range.selectNodeContents(text);
    } else {
        const text = range.toString();
        if (!text.trim() || !editableMarkdownInline(range)) return false;
        const code = document.createElement('code');
        code.textContent = text;
        range.deleteContents();
        range.insertNode(code);
        range.selectNodeContents(code);
    }
    selectMarkdownRange(range);
    return true;
}

function markdownLinkDestination(value) {
    if (typeof value !== 'string') return null;
    value = value.trim();
    if (/[\u0000-\u0020\u007f]/.test(value) || !safeURL(value, 'href')) return null;
    if (value.startsWith('#')) return value;
    try {
        const url = new URL(value);
        if (url.protocol === 'mailto:' ? url.pathname : url.hostname) return value;
    } catch {
        return null;
    }
    return null;
}

function updateMarkdownLink(range, action, linkURL, linkText) {
    let anchor = sharedMarkdownElement(range, 'a[href], a[data-source-href]');
    if (anchor?.closest('pre, code')) return false;
    if (action === 'unlink') {
        if (!anchor) return false;
        const children = [...anchor.childNodes];
        anchor.replaceWith(...children);
        if (children.length) {
            range.setStartBefore(children[0]);
            range.setEndAfter(children.at(-1));
        }
        selectMarkdownRange(range);
        return true;
    }

    const destination = markdownLinkDestination(linkURL);
    if (!destination) return false;
    const label = typeof linkText === 'string' && linkText.trim() ? linkText : '';
    if (anchor) {
        anchor.removeAttribute('data-source-href');
        if (label && label !== anchor.textContent) anchor.textContent = label;
    } else {
        if (!canWrapMarkdownLink(range)) return false;
        anchor = document.createElement('a');
        const selectedText = range.toString();
        if (selectedText.trim() && (!label || label === selectedText)) {
            anchor.append(range.extractContents());
        } else {
            range.deleteContents();
            anchor.textContent = label || destination;
        }
        range.insertNode(anchor);
    }
    anchor.setAttribute('href', destination);
    anchor.setAttribute('rel', 'noopener noreferrer');
    anchor.tabIndex = 0;
    range.selectNodeContents(anchor);
    selectMarkdownRange(range);
    return true;
}

function applyMarkdownFormat(action, linkURL, linkText) {
    if (!content.isContentEditable || composing) return false;
    const linking = action === 'link' || action === 'unlink';
    // The native link sheet belongs to the exact selection it opened from.
    const range = linking
        ? (markdownLinkSelection?.source === markdown ? recoverMarkdownRange(markdownLinkSelection.bookmark) : null)
        : selectionInMarkdown() ?? recoverMarkdownRange(markdownSelection);
    if (linking) markdownLinkSelection = null;
    if (!range) return false;

    // Focusing the editor after a native menu or sheet can collapse its selection.
    const bookmark = rememberMarkdownRange(range);
    content.focus({ preventScroll: true });
    const restored = recoverMarkdownRange(bookmark);
    if (!restored) return false;
    selectMarkdownRange(restored);

    // A toolbar command is one edit, including any DOM normalization it needs.
    composing = true;
    try {
        if (linking) return updateMarkdownLink(restored, action, linkURL, linkText);
        if (action === 'code') return updateMarkdownCode(restored);
        if (action === 'bold' || action === 'italic') {
            if (sharedMarkdownElement(restored, 'pre, code')) return false;
            document.execCommand('styleWithCSS', false, false);
            return document.execCommand(action);
        }
        if (Array.from(content.querySelectorAll('pre, table, details')).some(block => restored.intersectsNode(block))) {
            return false;
        }
        if (action === 'unorderedList' || action === 'orderedList') {
            const taskItems = content.querySelectorAll('li:has(input[type="checkbox"])');
            if (Array.from(taskItems).some(item => restored.intersectsNode(item))) return false;
            return document.execCommand(action === 'orderedList' ? 'insertOrderedList' : 'insertUnorderedList');
        }
        if (action === 'paragraph' || /^heading[1-6]$/.test(action)) {
            if (!withinMarkdownParagraph(restored)) return false;
            return document.execCommand('formatBlock', false, action === 'paragraph' ? 'p' : 'h' + action.at(-1));
        }
        return false;
    } finally {
        composing = false;
        commit();
    }
}
