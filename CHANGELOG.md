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

_Nothing yet._

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
