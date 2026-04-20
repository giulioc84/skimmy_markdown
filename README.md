# Skimmy

*A fast, native macOS markdown editor & previewer.*

[![macOS](https://img.shields.io/badge/macOS-26.0%2B-blue)]()
[![Swift](https://img.shields.io/badge/Swift-5.9-orange)]()
[![License: MIT](https://img.shields.io/badge/License-MIT-green)](LICENSE)
[![Sponsor](https://img.shields.io/badge/Sponsor-%E2%9D%A4-ff69b4)](https://github.com/sponsors/giulioc84)

---

## Why Skimmy?

Skimmy is a minimal, native macOS editor for `.md` files. Unlike Electron-based
editors, it uses AppKit's `NSTextView` for the editor and `WKWebView` for the
preview — so it launches instantly, scrolls smoothly, and feels at home on macOS.

No tabs, no plugins, no cloud. Open a file, write markdown, see it rendered.

*(Screenshot coming soon.)*

## Features

### Editing
- Native `NSTextView`-backed editor with full undo/redo and system find bar (`⌘F`)
- Monospaced fonts with adjustable size (`⌘=`, `⌘-`, `⌘0`), persisted across launches
- Auto-correct, smart quotes, smart dashes, and link detection explicitly **off** — no markdown-breaking surprises

### Preview
- Instant GitHub-flavored rendering via [marked.js](https://github.com/markedjs/marked) inside `WKWebView`
- Automatic light / dark theme via `prefers-color-scheme`
- Clickable links open in the default browser (not in-app)

### Navigation
- Toggleable sidebar (`⇧⌘L`) with two tabs:
  - **Contents** — full H1–H6 outline, click to scroll
  - **Links** — every inline `[text](url)`, image `![alt](url)`, and autolink `<url>`
- Debounced parsing on a background thread (300 ms) so large docs stay responsive

### Files & windows
- Native `DocumentGroup` integration — proper Open / Save / Save As / Recents
- Registered as Owner for `.md`, `.markdown`, `.mdown`
- Welcome screen with up to 10 recent documents
- Save-confirmation dialog when leaving edit mode with unsaved changes
- Visual-effect (blur) window background

### Keyboard shortcuts

| Shortcut  | Action                    |
| --------- | ------------------------- |
| `⌘E`      | Toggle edit / preview     |
| `⇧⌘L`     | Toggle sidebar            |
| `⌘S`      | Save                      |
| `⌘F`      | Find in editor            |
| `⌘=`/`⌘-` | Increase / decrease font  |
| `⌘0`      | Reset font size           |

## Install (from Releases)

> First release will be cut soon. Until then, please use **Build from source** below.

1. Download `Skimmy.app.zip` from the latest [release](https://github.com/giulioc84/skimmy_markdown/releases).
2. Unzip and drag `Skimmy.app` into `/Applications`.
3. Because Skimmy is signed with an **Apple Development** certificate (not a paid
   Developer ID), macOS will show *"Skimmy cannot be opened because the developer
   cannot be verified"* on first launch.
   **Right-click → Open → Open** once; it won't ask again.

## Build from source

Prerequisites: **Xcode 26.0+**, **Homebrew**.

```sh
brew install xcodegen

git clone https://github.com/giulioc84/skimmy_markdown.git
cd skimmy_markdown
make install   # generates .xcodeproj, builds Release, signs, installs to /Applications
open -a Skimmy
```

Available `make` targets:

| Target         | Purpose                                    |
| -------------- | ------------------------------------------ |
| `make generate`| Produce `.xcodeproj` via XcodeGen          |
| `make build`   | Build Release configuration                |
| `make install` | Build + sign + copy to `/Applications`     |
| `make sign`    | Re-sign `/Applications/Skimmy.app`         |
| `make clean`   | Delete `.build/` and `.xcodeproj`          |

### Code signing

The `Makefile` signs the installed app with the **Apple Development** certificate
whose SHA-1 is configured in `Makefile` as `SIGN_IDENTITY`. Change this to match
the certificate on your machine — list yours with:

```sh
security find-identity -v -p codesigning
```

For App Store / broader distribution, replace the identity with an **Apple
Developer ID Application** certificate and add a notarization step.

## Project layout

```
Skimmy/
├── App/            # Entry point (SkimmyApp.swift), DocumentGroup, menu commands
├── Model/          # MarkdownDocument, parsers (headings, links)
├── Views/          # SwiftUI + NSViewRepresentable wrappers (editor, reader, sidebar)
├── Utilities/      # Debounced parsing, persisted settings, window helpers
└── Resources/      # Info.plist, marked.min.js, Assets.xcassets
```

## Tech stack

- **SwiftUI** (macOS 26+, Swift 5.9)
- **NSTextView** for the editor (wrapped in `NSViewRepresentable`)
- **WKWebView** + **marked.js** for the preview
- **XcodeGen** (`project.yml` → `.xcodeproj`)

See [`CLAUDE.md`](CLAUDE.md) for architectural notes and key implementation patterns.

## Contributing

This is a personal project; the repo is private and not currently accepting PRs.
If you find a bug, please open an issue — I'd love to hear about it.

## Support the project ❤️

If Skimmy saves you time, consider [sponsoring on GitHub](https://github.com/sponsors/giulioc84).
Every bit helps keep the app maintained.

## License

[MIT](LICENSE). Third-party attributions in [`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md).
