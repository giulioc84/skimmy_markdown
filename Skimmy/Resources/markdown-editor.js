function kebabCase(str) {
    return str.split(/[^\p{L}\p{N}\p{M}]+/u).filter(Boolean).join('-').toLowerCase().normalize();
}

const headingTags = ['H1', 'H2', 'H3', 'H4', 'H5', 'H6'];
const headingSelector = headingTags.join(', ');
const taskAttribute = 'data-skimmy-task';
const taskToken = Array.from(crypto.getRandomValues(new Uint32Array(4)), value => value.toString(16)).join('-');
const taskSelector = 'input[' + taskAttribute + '="' + taskToken + '"]';
const taskSpacingMarker = '\uE000' + taskToken + '\uE001';
marked.setOptions({ gfm: true });

let traceBlock;
marked.use({
    renderer: {
        checkbox({ checked }) {
            return '<input type="checkbox" ' + taskAttribute + '="' + taskToken + '"' +
                (checked ? ' checked' : '') + ' disabled>';
        }
    },
    extensions: [{
        name: 'sourceSpans',
        level: 'block',
        tokenizer(src, tokens) {
            if (tokens === this.lexer.tokens) traceBlock?.(src.length, tokens);
            // Observe the lexer without consuming input or changing its tokens.
        }
    }]
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
const authoredDisclosures = new WeakMap();

function safeURL(value, attr) {
    const v = value.trim().replace(/[\u0000-\u0020]/g, '');
    if (v.startsWith('#')) return attr === 'href';
    const m = v.match(/^([a-zA-Z][a-zA-Z0-9+.-]*):/);
    if (!m) return false;                       // no base URL: relative links can't resolve
    const scheme = m[1].toLowerCase();
    if (scheme === 'http' || scheme === 'https') return true;
    if (scheme === 'mailto') return attr === 'href';
    if (scheme === 'data') return attr === 'src' && /^data:image\/(png|gif|jpe?g|webp|bmp)[;,]/i.test(v);
    return false;
}

function assignHeadingID(heading, headingIDs) {
    if (!heading.id) {
        const base = heading.textContent.trim().toLowerCase()
            .replace(/[^-\p{L}\p{N}\p{M}_ ]/gu, '').replaceAll(' ', '-');
        let id = base;
        while (headingIDs.has(id)) {
            const next = headingIDs.get(base) + 1;
            headingIDs.set(base, next);
            id = base + '-' + next;
        }
        heading.id = id;
    }
    headingIDs.set(heading.id, 0);
    // Fragment links can move focus to their destination without adding a tab stop.
    heading.tabIndex = -1;
}

function sanitize(node, headings) {
    let child = node.firstChild;
    while (child) {
        const next = child.nextSibling;
        if (child.nodeType === Node.COMMENT_NODE) child.remove();
        else if (child.nodeType === Node.ELEMENT_NODE) sanitizeElement(child, headings);
        child = next;
    }
}

function sanitizeElement(child, headings) {
    const tag = child.tagName.toUpperCase();
    if (DROP.has(tag)) { child.remove(); return; }
    if (!KEEP.has(tag)) {
        sanitize(child, headings);
        const inner = document.createDocumentFragment();
        while (child.firstChild) inner.appendChild(child.firstChild);
        child.replaceWith(inner);
        return;
    }
    const sourceAttr = tag === 'A' ? 'href' : tag === 'IMG' ? 'src' : null;
    // A per-page value distinguishes the Markdown renderer's tasks from authored HTML.
    const isTask = tag === 'INPUT' && child.matches(taskSelector);
    let sourceValue;
    const attrs = child.attributes;
    for (let i = attrs.length - 1; i >= 0; i--) {
        const { name, value } = attrs[i];
        let ok = ATTRS.has(name);
        if (ok && URL_ATTRS.has(name)) ok = safeURL(value, name);
        if (ok && name === 'srcset') ok = value.split(/,\s+/).every(p => safeURL(p.trim().split(/\s+/)[0] || '', 'src'));
        if (ok && name === 'type' && tag === 'INPUT') ok = value.toLowerCase() === 'checkbox';
        if (tag === 'CODE' && name === 'class') ok = /^language-[\w.+#-]+$/.test(value);
        if (!ok) {
            if (name === sourceAttr) sourceValue = value;
            child.removeAttribute(name);
        }
    }
    // Preserve inert destinations for saving without activating the URL.
    if (sourceValue !== undefined) child.setAttribute('data-source-' + sourceAttr, sourceValue);
    if (tag === 'INPUT') {
        if ((child.getAttribute('type') || '').toLowerCase() !== 'checkbox') { child.remove(); return; }
        child.setAttribute('disabled', '');
        if (isTask) child.setAttribute(taskAttribute, taskToken);
    }
    if (tag === 'A' && child.hasAttribute('href')) {
        child.setAttribute('rel', 'noopener noreferrer');
        child.tabIndex = 0;
    }
    if (tag === 'PRE' || tag === 'TABLE') child.tabIndex = 0;
    if (tag === 'DETAILS') authoredDisclosures.set(child, child.getAttribute('open'));
    if (headingTags.includes(tag)) headings.push(child);
    sanitize(child, headings);
}

const content = document.querySelector('main');
const converter = new TurndownService({ headingStyle: 'atx', codeBlockStyle: 'fenced', bulletListMarker: '-' });
converter.use(turndownPluginGfm.gfm);
converter.addRule('taskCheckbox', {
    filter: node => node.nodeName === 'INPUT' && node.type === 'checkbox',
    replacement: (_, node) => node.matches(taskSelector)
        ? (node.checked ? '[x] ' : '[ ] ') + taskSpacingMarker
        : node.outerHTML
});
converter.addRule('strikethrough', {
    filter: ['del', 's', 'strike'],
    replacement: text => '~~' + text + '~~'
});
converter.keep(['abbr', 'audio', 'details', 'dl', 'figure', 'ins', 'kbd', 'mark',
    'picture', 'small', 'sub', 'sup', 'u', 'video']);
const escapeMarkdown = converter.escape.bind(converter);
converter.escape = text => escapeMarkdown(text.replace(/[ \t]*\u00a0[ \t\u00a0]*/g, ' ').replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;').replaceAll('>', '&gt;')).replaceAll('|', '\\|');

let revision = 0;
let markdown = '';
let renderedSource = '';
let lineEnding = '\n';
let origins = new WeakMap();
let prefixes = [];
let suffix = '';
let composing = false;
let serializedSource = '';
let sourceParts;
let structureChanged = false;
const dirtyBlocks = new Set();

function markDirty(records) {
    for (const record of records) {
        let block = record.target;
        if (record.attributeName === 'open' && block.tagName === 'DETAILS') continue;
        if ((record.attributeName === 'disabled' || record.attributeName === 'aria-label') && block.matches(taskSelector)) continue;
        if (block === content) {
            if (record.type === 'childList') {
                structureChanged = true;
                sourceParts = undefined;
                dirtyBlocks.clear();
            }
            continue;
        }
        while (block && block.parentNode !== content) block = block.parentNode;
        const origin = origins.get(block);
        if (origin) {
            origin.converted = undefined;
            if (!structureChanged) dirtyBlocks.add(block);
        }
    }
}

const observer = new MutationObserver(markDirty);
observer.observe(content, { subtree: true, characterData: true, childList: true, attributes: true });

// Marked normalizes line endings and omits reference definitions from its tokens.
// Observe the consumed spans so invisible content and the original bytes survive edits.
function sourceSpans(source) {
    const normalized = source.replace(/\r\n|\r/g, '\n');
    const crlf = Array.from(source.matchAll(/\r\n/g), (match, index) => match.index - index);
    const spans = [];
    let extra = 0;
    let cursor = 0;
    let previousToken;
    let previousLength;

    traceBlock = (remaining, tokens) => {
        const end = normalized.length - remaining;
        if (end === cursor) return;
        const last = tokens.at(-1);
        const length = last?.raw.length;
        const token = last !== previousToken || length !== previousLength ? last : undefined;
        const start = cursor + extra;
        while (crlf[extra] < end) extra++;
        const original = source.slice(start, end + extra);
        const previous = spans.at(-1);
        if (previous && previous.token === token) previous.raw += original;
        else spans.push({ token, raw: original });
        cursor = end;
        previousToken = last;
        previousLength = length;
    };

    try {
        const tokens = marked.lexer(normalized);
        traceBlock(0, tokens);
    } finally {
        traceBlock = undefined;
    }
    return spans;
}

function render(source) {
    const fragment = document.createDocumentFragment();
    const template = document.createElement('template');
    const headingIDs = new Map();
    const headings = [];
    origins = new WeakMap();
    prefixes = [];
    suffix = '';
    lineEnding = source.match(/\r\n|[\r\n]/)?.[0] ?? '\n';

    for (const {token, raw} of sourceSpans(source)) {
        if (!token || token.type === 'space') {
            suffix += raw;
            continue;
        }
        const html = marked.parser([token]);
        template.innerHTML = html;
        sanitize(template.content, headings);
        if (html.includes(taskToken)) {
            for (const checkbox of template.content.querySelectorAll(taskSelector)) {
                checkbox.disabled = !content.isContentEditable;
                checkbox.tabIndex = 0;
            }
        }
        for (const heading of headings) assignHeadingID(heading, headingIDs);
        headings.length = 0;
        if (!template.content.firstElementChild && !template.content.textContent.trim()) {
            suffix += raw;
            continue;
        }
        const block = document.createElement('div');
        block.append(template.content);
        const ending = raw.match(/(?:\r\n|\n|\r)(?:[ \t]*(?:\r\n|\n|\r))*$/)?.[0] ?? '';
        origins.set(block, {index: prefixes.length, raw, ending, html: blockHTML(block), converted: raw});
        prefixes.push(suffix);
        suffix = '';
        fragment.append(block);
    }
    content.replaceChildren(fragment);
    observer.takeRecords();
    dirtyBlocks.clear();
    structureChanged = false;
    sourceParts = undefined;
    serializedSource = source;
    renderedSource = source;
}

function taskLabel(checkbox) {
    let label = '';
    for (let node = checkbox.nextSibling; node; node = node.nextSibling) {
        if (node.matches?.('ul, ol, p, div, blockquote, pre, table')) break;
        label += node.textContent;
    }
    return label.replace(/\s+/g, ' ').trim() || 'Task';
}

function syncTaskControls(editing) {
    for (const checkbox of content.querySelectorAll(taskSelector)) {
        checkbox.disabled = !editing;
    }
}

function refreshTaskLabels(node) {
    let changed = false;
    for (const checkbox of node.querySelectorAll(taskSelector)) {
        const label = taskLabel(checkbox);
        if (checkbox.getAttribute('aria-label') !== label) {
            checkbox.setAttribute('aria-label', label);
            changed = true;
        }
    }
    return changed;
}

function blockHTML(node) {
    const html = node.innerHTML;
    if (!html.includes(taskToken)) return html;
    const labelsChanged = refreshTaskLabels(node);
    if (!node.querySelector(taskSelector + '[disabled]')) return labelsChanged ? node.innerHTML : html;
    // Disabled state belongs to the editor mode, so leave it out of the source comparison.
    const copy = node.cloneNode(true);
    for (const checkbox of copy.querySelectorAll(taskSelector)) checkbox.removeAttribute('disabled');
    return copy.innerHTML;
}

function toMarkdown(node, html, originalHTML) {
    if (node.nodeType === Node.TEXT_NODE) return converter.escape(node.textContent.trim());
    if (node.nodeType !== Node.ELEMENT_NODE) return '';

    if (html === undefined) {
        refreshTaskLabels(node);
        html = node.outerHTML;
    }
    // Restore inert URL attributes only in the detached serialization input.
    const template = document.createElement('template');
    template.innerHTML = html;
    if (html.includes('<details')) {
        const nested = node.querySelectorAll('details');
        const live = node.tagName === 'DETAILS' ? [node, ...nested] : nested;
        let index = 0;
        for (const copy of template.content.querySelectorAll('details')) {
            const open = authoredDisclosures.get(live[index++]);
            if (open === null) copy.removeAttribute('open');
            else if (open !== undefined) copy.setAttribute('open', open);
        }
        if (template.innerHTML === originalHTML) return undefined;
    }
    for (const link of template.content.querySelectorAll('[data-source-href], [data-source-src]')) {
        for (const attr of ['href', 'src']) {
            const value = link.getAttribute('data-source-' + attr);
            if (value !== null) {
                link.setAttribute(attr, value);
                link.removeAttribute('data-source-' + attr);
            }
        }
    }
    for (const lineBreak of template.content.querySelectorAll('pre br')) {
        lineBreak.replaceWith('\n');
    }
    for (const target of template.content.querySelectorAll('[tabindex]')) {
        target.removeAttribute('tabindex');
    }
    const hasTasks = html.includes(taskToken);
    if (hasTasks) {
        for (const checkbox of template.content.querySelectorAll(taskSelector)) {
            checkbox.removeAttribute('aria-label');
            checkbox.disabled = true;
        }
    }
    let converted = converter.turndown(template.content);
    if (hasTasks) {
        // Turndown trims trailing whitespace. Empty tasks need a space after
        // their marker, including at EOF and before a quoted section ends.
        converted = converted.replaceAll(taskSpacingMarker, '').replaceAll(' ' + taskAttribute + '="' + taskToken + '"', '');
    }
    return converted.replaceAll('\n', lineEnding);
}

function blockMarkdown(node, origin) {
    if (origin.converted === undefined) {
        const html = blockHTML(node);
        if (html === origin.html) {
            origin.converted = origin.raw;
        } else {
            const converted = toMarkdown(node, html, origin.html);
            origin.converted = converted === undefined ? origin.raw : converted ? converted + origin.ending : '';
        }
    }
    return origin.converted;
}

function serialize() {
    markDirty(observer.takeRecords());
    if (!structureChanged) {
        if (!dirtyBlocks.size) return serializedSource;
        if (!sourceParts) {
            sourceParts = [];
            for (const node of content.childNodes) {
                const { index, raw } = origins.get(node);
                sourceParts.push(prefixes[index], raw);
            }
            sourceParts.push(suffix);
        }
        for (const node of dirtyBlocks) {
            const origin = origins.get(node);
            const raw = blockMarkdown(node, origin);
            // Removing a block may also remove a separator. Use the structural path.
            if (!raw) {
                structureChanged = true;
                sourceParts = undefined;
                break;
            }
            sourceParts[origin.index * 2 + 1] = raw;
        }
        dirtyBlocks.clear();
        if (sourceParts) return serializedSource = sourceParts.join('');
    }
    return serializeStructure();
}

function serializeStructure() {
    const parts = [];
    let originalIndex = 0;
    let lastWasNew = false;

    for (const node of content.childNodes) {
        const origin = origins.get(node);
        const index = origin?.index;
        let prefix = '';
        if (index >= originalIndex) {
            while (originalIndex < index) {
                const skipped = prefixes[originalIndex++];
                if (skipped.trim()) prefix += skipped;
            }
            prefix += prefixes[originalIndex++];
        }

        const raw = origin ? blockMarkdown(node, origin) : toMarkdown(node);

        if (!raw) {
            if (prefix.trim()) parts.push(prefix);
            continue;
        }
        if (parts.length && (!origin || lastWasNew)) {
            const previous = parts.at(-1);
            const breaks = ((previous.match(/(?:\r\n|[\r\n]){1,2}$/)?.[0] ?? '') +
                (prefix.match(/^(?:\r\n|[\r\n]){1,2}/)?.[0] ?? '')).match(/\r\n|[\r\n]/g)?.length ?? 0;
            if (breaks < 2) parts.push(lineEnding.repeat(2 - breaks));
        }
        parts.push(prefix + raw);
        lastWasNew = !origin;
    }

    while (originalIndex < prefixes.length) {
        const skipped = prefixes[originalIndex++];
        if (skipped.trim()) parts.push(skipped);
    }
    if (parts.length || suffix.trim() || !prefixes.length) parts.push(suffix);
    return parts.join('');
}

function post(change) {
    window.webkit?.messageHandlers.skimmy.postMessage({ revision, ...change });
}

function commit() {
    const updated = serialize();
    if (updated !== markdown) {
        markdown = updated;
        post({ markdown });
    }
}

function markdownTaskStates(raw) {
    const states = [];
    marked.walkTokens(marked.lexer(raw), token => {
        if (token.type === 'list_item' && token.task) states.push(!!token.checked);
    });
    return states;
}

function patchTaskMarker(raw, index, expected) {
    const markers = Array.from(raw.matchAll(/\[([ xX])\]/g));
    const checked = expected[index];
    const replacement = checked ? 'x' : ' ';
    const apply = offsets => {
        const parts = [];
        let cursor = 0;
        for (const offset of offsets) {
            parts.push(raw.slice(cursor, offset), replacement);
            cursor = offset + 1;
        }
        parts.push(raw.slice(cursor));
        return parts.join('');
    };
    const tryMarker = offset => {
        const patched = apply([offset]);
        const states = markdownTaskStates(patched);
        return states.length === expected.length && states.every((state, i) => state === expected[i]) ? patched : undefined;
    };

    // A plain task list normally lines up with the source brackets. Validate the
    // candidate with Marked because fenced code and inline text may contain lookalikes.
    if (markers[index]) {
        const patched = tryMarker(markers[index].index + 1);
        if (patched !== undefined && patched !== raw) return patched;
    }
    const candidates = markers.filter(marker => (marker[1] !== ' ') !== checked)
        .map(marker => marker.index + 1);
    if (!candidates.length) return undefined;

    // Find the marker in a block with lookalikes by testing halves of the
    // candidates. Either spelling is valid, so these probes keep the list structure.
    let first = 0;
    let last = candidates.length;
    while (last - first > 1) {
        const middle = Math.floor((first + last) / 2);
        const states = markdownTaskStates(apply(candidates.slice(first, middle)));
        if (states.length !== expected.length) return undefined;
        if (states[index] === checked) last = middle;
        else first = middle;
    }
    return tryMarker(candidates[first]);
}

function toggleTask(checkbox) {
    if (checkbox.checked === checkbox.hasAttribute('checked')) return;
    let block = checkbox.parentElement;
    while (block && block.parentElement !== content) block = block.parentElement;
    const origin = origins.get(block);
    let patched;
    if (origin && origin.html === blockHTML(block)) {
        const controls = Array.from(block.querySelectorAll(taskSelector));
        patched = patchTaskMarker(origin.raw, controls.indexOf(checkbox), controls.map(task => task.checked));
    }
    checkbox.toggleAttribute('checked', checkbox.checked);
    if (patched !== undefined) {
        origin.raw = patched;
        origin.html = blockHTML(block);
    }
    commit();
}

function caretOffset() {
    const selection = window.getSelection();
    if (!content.isContentEditable || !content.contains(selection.focusNode)) return null;
    const range = document.createRange();
    range.selectNodeContents(content);
    range.setEnd(selection.focusNode, selection.focusOffset);
    return range.toString().length;
}

function restoreCaret(offset) {
    if (offset === null) return;
    const selection = window.getSelection();
    const walker = document.createTreeWalker(content, NodeFilter.SHOW_TEXT);
    for (let node = walker.nextNode(); node; node = walker.nextNode()) {
        if (offset <= node.length) {
            selection.collapse(node, offset);
            return;
        }
        offset -= node.length;
    }
    selection.selectAllChildren(content);
    selection.collapseToEnd();
}

function updateContent(source, version) {
    const offset = caretOffset();
    const y = window.scrollY;
    revision = version;
    markdown = source;
    render(source);
    restoreCaret(offset);
    if (y || offset !== null) window.scrollTo(0, y);
}

function finishEditing() {
    // Moving to a native source view can destroy this page immediately.
    // Commit visible composition text before handing control back to Swift.
    if (!content.isContentEditable) return;
    content.blur();
    composing = false;
    commit();
}

function setEditing(editing) {
    if (!editing) finishEditing();
    content.contentEditable = String(editing);
    syncTaskControls(editing);
    if (editing) {
        content.setAttribute('aria-label', 'Markdown document');
        content.setAttribute('data-placeholder', 'Start writing…');
        content.focus({ preventScroll: true });
    } else {
        content.removeAttribute('aria-label');
        if (markdown !== renderedSource) updateContent(markdown, revision);
    }
}

content.addEventListener('input', event => {
    if (!composing && !event.isComposing) commit();
});
content.addEventListener('compositionstart', () => { composing = true; });
content.addEventListener('compositionend', () => {
    composing = false;
    commit();
});
content.addEventListener('change', event => {
    const checkbox = event.target;
    if (!content.isContentEditable || !checkbox.matches?.(taskSelector)) return;
    if (composing) {
        checkbox.checked = checkbox.hasAttribute('checked');
        return;
    }
    toggleTask(checkbox);
});
content.addEventListener('click', event => {
    const link = event.target.closest?.('a[href]');
    if (!link || event.defaultPrevented || (content.isContentEditable && event.altKey)) return;

    const destination = link.getAttribute('href').trim();
    if (destination.startsWith('#')) {
        event.preventDefault();
        scrollToFragment(destination);
    } else if (content.isContentEditable) {
        event.preventDefault();
        post({ openLink: destination });
    }
});
content.addEventListener('beforeinput', event => {
    if (event.inputType === 'historyUndo' || event.inputType === 'historyRedo') {
        event.preventDefault();
        post({ action: event.inputType === 'historyUndo' ? 'undo' : 'redo' });
    }
    if (event.inputType === 'insertParagraph') {
        const selection = window.getSelection();
        const enclosingCode = node => (node?.parentElement ?? node)?.closest?.('pre');
        const code = enclosingCode(selection.anchorNode);
        if (code && code === enclosingCode(selection.focusNode)) {
            event.preventDefault();
            document.execCommand('insertLineBreak');
        }
    }
});
content.addEventListener('keydown', event => {
    const active = document.activeElement;
    if (event.key === ' ' && content.isContentEditable && active?.matches(taskSelector)) {
        event.preventDefault();
        if (!event.repeat) active.click();
        return;
    }
    if (event.key === 'Enter' && content.isContentEditable && active?.matches('a[href]')) {
        event.preventDefault();
        active.click();
        return;
    }
    if (event.metaKey && !event.altKey && event.key.toLowerCase() === 'z') {
        event.preventDefault();
        post({ action: event.shiftKey ? 'redo' : 'undo' });
    }
});
content.addEventListener('paste', event => {
    if (!content.isContentEditable) return;
    event.preventDefault();
    const plain = event.clipboardData.getData('text/plain');
    if (plain) document.execCommand('insertText', false, plain);
});
content.addEventListener('drop', event => {
    if (!content.isContentEditable) return;
    event.preventDefault();
    const plain = event.dataTransfer.getData('text/plain');
    const range = document.caretRangeFromPoint(event.clientX, event.clientY);
    if (!plain || !range || !content.contains(range.startContainer)) return;
    const selection = window.getSelection();
    selection.removeAllRanges();
    selection.addRange(range);
    document.execCommand('insertText', false, plain);
});

function scrollBehavior() {
    return matchMedia('(prefers-reduced-motion: reduce)').matches ? 'instant' : 'smooth';
}

function scrollToTarget(target, focus = false) {
    if (!target) return;
    if (focus && !content.isContentEditable && target.matches(headingSelector)) {
        target.focus({ preventScroll: true });
    }
    target.scrollIntoView({ behavior: scrollBehavior(), block: 'start' });
}

function scrollToFragment(hash) {
    let id = hash.slice(1);
    if (!id) {
        window.scrollTo({ top: 0, behavior: scrollBehavior() });
        return;
    }
    try { id = decodeURIComponent(id); } catch { /* Allow literal percent signs in custom IDs. */ }

    const named = () => Array.from(content.querySelectorAll('a[name]')).find(el => el.name === id);
    const legacy = () => {
        const normalized = id.normalize();
        return Array.from(content.querySelectorAll(headingSelector)).find(el => kebabCase(el.textContent) === normalized);
    };
    scrollToTarget(document.getElementById(id) ?? named() ?? legacy(), true);
}

function scrollToHeading(id, occurrence) {
    const normalized = id.normalize();
    for (const heading of content.querySelectorAll(headingSelector)) {
        if (kebabCase(heading.textContent) === normalized && occurrence-- === 0) {
            scrollToTarget(heading);
            return;
        }
    }
}
