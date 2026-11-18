# Changelog

All notable changes to Skimmy are documented here.
The format is loosely based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

Skimmy follows [Semantic Versioning](https://semver.org): `MAJOR.MINOR.PATCH`.

| Segment | Bumped when… |
|---|---|
| **MAJOR** (`x`.y.z) | Breaking changes, significant redesigns, incompatible reworks |
| **MINOR** (x.`y`.z) | New features, small additions, backwards-compatible changes |
| **PATCH** (x.y.`z`) | Bug fixes, typo corrections, internal cleanup with no behavior change |

---

## [Unreleased]

A redesign. Suggested version: **2.0.0** (`make release VERSION=2.0.0`).

### Added

- **Split view**: editor on the left, live preview on the right, in one window. The
  preview updates as you type and follows the editor as it scrolls. Drag the divider to
  resize; double-click it to reset. Files now open in Split by default, and new windows
  open in whichever mode you used last.
- **Three modes** in the toolbar and View menu: Read (`⌘1`), Split (`⌘2`), Edit (`⌘3`).
  `⌘E` still flips between reading and editing.
- **Format menu**: Bold (`⌘B`), Italic (`⌘I`), Code (`⇧⌘K`), Link (`⌘K`). Each wraps the
  selection, or removes the markers if the selection is already wrapped.
- **List continuation**: Return inside a bullet, numbered or task-list item starts the
  next item; Return on an empty item ends the list.
- **Find in Read mode** highlights every match and shows "3 of 12". Find Next / Previous
  (`⌘G` / `⇧⌘G`) and Find and Replace (`⌥⌘F`) are in the Edit menu.
- **Sidebar** highlights the section you are in, and its entries now work while editing
  (they jump the editor to that heading).
- **Local images** referenced by path (`![](docs/shot.png)`) now show in the preview.
- **Relative links** to other markdown files open them in Skimmy.
- Status pill shows words, characters and reading time.
- New app icon and a teal accent colour. Icon sources are in `design/icon/`.

### Changed

- **Liquid Glass interface**: the custom vertical toolbar is replaced by the standard
  macOS 26 toolbar and sidebar, which the system draws as glass. The find bar, status
  pill and welcome screen use glass too.
- Preview typography: readable line length, refined headings, code blocks, tables and
  quotes.
- The editor centres its text column in wide windows and uses more comfortable spacing.
- Heading ids in the preview follow GitHub's rules (accented letters kept, duplicates
  numbered), so `[link](#section)` anchors match what GitHub renders.

### Performance

- The preview re-renders **only the blocks that changed** instead of the whole document.
  On a 1.1 MB test file a keystroke costs about 33 ms, down from about 680 ms.
- Preview updates are debounced and never queue up behind each other while you type.
- The editor and preview are kept alive when switching modes; previously each switch
  rebuilt the web view and reloaded the page. Undo history, selection and scroll
  position now survive a mode switch.
- Word and character counts moved off the main thread (they were recomputed on every
  keystroke).
- The sidebar lists are lazy, so documents with thousands of headings stay responsive.

### Fixed

- `⌘F` did nothing while editing. It now opens the system find bar.
- File → Save As…, Duplicate and Revert To were missing from the File menu.
- Duplicate headings broke the outline (two entries shared one identity) and always
  scrolled to the first occurrence. Headings with non-English letters could fail to
  scroll at all.
- Outline line numbers were wrong for files with Windows line endings.
- In-document anchor links (`[x](#heading)`) opened a blank browser tab.

### Security

- Raw HTML inside a document could run JavaScript in the preview (for example
  `<img onerror=...>`). The preview now has a content security policy that only lets
  Skimmy's own script run.
- Links in a document can no longer launch arbitrary local files or custom URL schemes.
  Web and mail links open as before; local non-text files are revealed in Finder.

### Removed

- The "You have unsaved changes" dialog when leaving edit mode, and its "Save as New
  File" option. With editing always available it no longer has a trigger. Use
  File → Revert To to discard changes and File → Duplicate for a copy.

### Infrastructure

- GitHub Actions workflow that compiles the app on macOS 26 for every pull request.

---

## [1.0.0] — 2026-04-21

First versioned release. Signed with an **Apple Developer ID Application**
certificate, hardened-runtime enabled, notarized by Apple, and stapled —
opens cleanly on any Mac (no Gatekeeper warning).

### Added

- **Editor**
  - Native `NSTextView`-backed editor with full undo/redo and macOS system find bar (`⌘F`).
  - Monospaced fonts with adjustable size (`⌘=`, `⌘-`, `⌘0`), persisted across launches via `UserDefaults`.
  - Auto-correct, smart quotes, smart dashes, and link detection explicitly disabled.
- **Preview**
  - GitHub-flavored markdown rendering via bundled `marked.js` inside a `WKWebView`.
  - Automatic light / dark theme via `prefers-color-scheme`.
  - Link clicks open in the default browser (not in-app).
- **Navigation**
  - Toggleable sidebar (`⇧⌘L`) with two tabs:
    - **Contents** — full H1–H6 outline, click-to-scroll.
    - **Links** — every inline `[text](url)`, image `![alt](url)`, and autolink `<url>`.
  - 300 ms debounced parsing on a background thread.
- **Files & windows**
  - Native `DocumentGroup` integration (Open / Save / Save As / Recents).
  - Registered as Owner for `.md`, `.markdown`, `.mdown`.
  - Welcome screen showing up to 10 recent documents.
  - Save-confirmation dialog when leaving edit mode with unsaved changes.
  - Visual-effect (blur) window background.
- **Shortcuts**: `⌘E` (toggle edit/preview), `⇧⌘L` (sidebar), `⌘S` (save), `⌘F` (find),
  `⌘=` / `⌘-` / `⌘0` (font size).

### Infrastructure

- Automated signing + notarization via `make install` + `make notarize`
  (auto-detects `Developer ID Application` cert, prefers it over `Apple Development`).
- XcodeGen-based project generation from `project.yml`.
- Proprietary license (All Rights Reserved).

[Unreleased]: https://github.com/giulioc84/skimmy_markdown/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/giulioc84/skimmy_markdown/releases/tag/v1.0.0
