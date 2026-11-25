// Limit a replacement to one rendered text unit. In particular, adjacent list
// items, table cells, or paragraphs must never become one match.
const replaceBoundaries = new Set([
    'ADDRESS', 'ARTICLE', 'ASIDE', 'BLOCKQUOTE', 'CAPTION', 'DD', 'DETAILS', 'DIV',
    'DL', 'DT', 'FIGCAPTION', 'FIGURE', 'FOOTER', 'HEADER', 'HR', 'LI', 'OL', 'P',
    'PRE', 'SECTION', 'SUMMARY', 'TABLE', 'TBODY', 'TD', 'TFOOT', 'TH', 'THEAD',
    'TR', 'UL', ...headingTags
]);
const replaceObjects = new Set(['AUDIO', 'BR', 'IMG', 'INPUT', 'PICTURE', 'SOURCE', 'VIDEO', 'WBR']);
let lastMarkdownFind;

function findMarkdownMatch(query, backwards) {
    const found = window.find(query, false, backwards, true);
    lastMarkdownFind = found && content.isContentEditable ? { query, revision } : undefined;
    return found;
}

function* replaceTextRuns() {
    let run = [];

    function* split() {
        // Marked adds whitespace-only text nodes between blocks for its HTML output.
        if (run.some(node => node.data.trim())) yield run;
        run = [];
    }

    function* visit(parent) {
        for (let node = parent.firstChild; node; node = node.nextSibling) {
            if (node.nodeType === Node.TEXT_NODE) {
                if (node.length) run.push(node);
                continue;
            }
            if (node.nodeType !== Node.ELEMENT_NODE) continue;

            const skipped = replaceObjects.has(node.tagName)
                || node.matches('[hidden], [inert], [contenteditable="false"]');
            const boundary = skipped || replaceBoundaries.has(node.tagName);
            if (boundary) yield* split();
            if (skipped) continue;

            if (node.tagName === 'DETAILS' && !node.open) {
                const summary = [...node.children].find(child => child.tagName === 'SUMMARY');
                if (summary) yield* visit(summary);
            } else {
                yield* visit(node);
            }
            if (boundary) yield* split();
        }
    }

    yield* visit(content);
    yield* split();
}

function* matchesInRun(nodes, pattern) {
    const text = nodes.map(node => node.data).join('');
    let first = 0;
    let firstOffset = 0;

    // Match indices and DOM Text offsets both use UTF-16.
    for (const match of text.matchAll(pattern)) {
        while (firstOffset + nodes[first].length <= match.index) {
            firstOffset += nodes[first++].length;
        }
        const end = match.index + match[0].length;
        let last = first;
        let lastOffset = firstOffset;
        while (lastOffset + nodes[last].length < end) {
            lastOffset += nodes[last++].length;
        }
        yield {
            start: match.index - firstOffset,
            end: end - lastOffset,
            nodes, first, last,
            text: match[0]
        };
    }
}

function replaceMatch(match, replacement) {
    if (match.text === replacement) return;
    const { nodes, first, last, start, end } = match;
    const firstNode = nodes[first];
    if (first === last) {
        firstNode.replaceData(start, end - start, replacement);
    } else {
        firstNode.replaceData(start, firstNode.length - start, replacement);
        for (let index = first + 1; index < last; index++) nodes[index].data = '';
        nodes[last].deleteData(0, end);
    }
}

function replaceMarkdownMatches(query, replacement, all) {
    if (!content.isContentEditable || composing || !query) return null;

    const literal = query.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
    const visible = query.trim() ? literal.replace(/ +/g, '[ \\t\\r\\n\\f\\u00a0]+') : literal;
    const codePattern = new RegExp(literal, 'giu');
    const prosePattern = new RegExp(visible, 'giu');
    const patternFor = nodes => nodes[0].parentElement?.closest('pre') ? codePattern : prosePattern;

    if (all) {
        let count = 0;
        for (const nodes of replaceTextRuns()) {
            const matches = [...matchesInRun(nodes, patternFor(nodes))];
            for (const match of matches.reverse()) replaceMatch(match, replacement);
            count += matches.length;
        }
        if (count) commit();
        return count;
    }

    const selection = window.getSelection();
    const selected = selection.rangeCount ? selection.getRangeAt(0) : null;
    const position = selected && content.contains(selected.endContainer) ? selected : null;
    const after = position?.cloneRange();
    after?.collapse(false);
    const selectedByFind = lastMarkdownFind?.query === query && lastMarkdownFind.revision === revision;
    const replaceSelection = position && !position.collapsed
        && (selectedByFind || new RegExp('^(?:' + visible + ')$', 'iu').test(position.toString()));
    let firstMatch;
    let nextMatch;

    findMatch: for (const nodes of replaceTextRuns()) {
        for (const match of matchesInRun(nodes, patternFor(nodes))) {
            firstMatch ??= match;
            if (!position) break findMatch;

            let isSelected = false;
            if (replaceSelection) {
                const range = document.createRange();
                range.setStart(nodes[match.first], match.start);
                range.setEnd(nodes[match.last], match.end);
                isSelected = range.compareBoundaryPoints(Range.START_TO_START, position) === 0
                    && range.compareBoundaryPoints(Range.END_TO_END, position) === 0;
            }
            const followsSelection = !replaceSelection
                && after.comparePoint(nodes[match.first], match.start) >= 0;
            if (isSelected || followsSelection) {
                nextMatch = match;
                break findMatch;
            }
        }
    }

    // A highlighted match outside one editable run must not replace a different
    // occurrence elsewhere in the document.
    if (replaceSelection && !nextMatch) return null;
    const match = nextMatch ?? firstMatch;
    if (!match) return 0;

    replaceMatch(match, replacement);
    const node = match.nodes[match.first];
    selection.collapse(node, match.start + replacement.length);
    node.parentElement?.scrollIntoView({ block: 'nearest', inline: 'nearest' });
    commit();
    return 1;
}
