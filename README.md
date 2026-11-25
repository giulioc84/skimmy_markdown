# Skimmy

*A fast, native macOS markdown editor & previewer.*

[![macOS](https://img.shields.io/badge/macOS-26.0%2B-blue)]()
[![Swift](https://img.shields.io/badge/Swift-5.9-orange)]()
[![License: Proprietary](https://img.shields.io/badge/License-Proprietary-lightgrey)](LICENSE)
[![Sponsor](https://img.shields.io/badge/Sponsor-%E2%9D%A4-ff69b4)](https://github.com/sponsors/giulioc84)

> **Source-available, not open-source.** The code is published so you can
> read, audit, and file precise bug reports. It is **not licensed** for reuse,
> forking, or redistribution. See [`LICENSE`](LICENSE) and
> [`CONTRIBUTING.md`](CONTRIBUTING.md).

---

## Using Skimmy

Open a Markdown file and choose **Edit** in the toolbar to type directly on the
formatted page. **Read** gives you a read-only view. Choose **Source** when you
want to edit the Markdown syntax itself.

Skimmy keeps the original source of blocks you leave untouched. Edited blocks
can use different Markdown syntax to express the same formatting. Use Source
when you need to keep a particular Markdown syntax or edit raw HTML.

In Edit, use the **Format** menu to change headings, emphasis, code, lists, and
links. You can also replace search matches and check off Markdown tasks.

The sidebar has a heading outline and a link index. Choose a heading to jump
to it in Read or Edit. Skimmy uses the standard macOS commands for saving,
duplicating, and reopening documents.

Choose System, Light, or Dark in **Skimmy > Settings > Appearance**.
The offline guide is under **Help > Skimmy Help**.

| Shortcut | Action |
| -------- | ------ |
| `⌘E` | Toggle formatted editing |
| `⇧⌘L` | Show or hide the sidebar |
| `⌘S` | Save |
| `⌘F` | Find in the current view |
| `⌘G` / `⇧⌘G` | Find the next or previous match |
| `⌘=` / `⌘-` | Increase or decrease text size |
| `⌘0` | Reset text size |

[Planned relative Markdown links](docs/relative-markdown-links.md)

## Install

Grab the **latest signed, notarized build** from the Releases page:

[📥 Download Skimmy.zip (latest)](https://github.com/giulioc84/skimmy_markdown/releases/latest/download/Skimmy.zip)

Or browse all releases: [Releases](https://github.com/giulioc84/skimmy_markdown/releases)

1. Download `Skimmy.zip`.
2. Unzip (double-click; macOS handles it).
3. Drag `Skimmy.app` into `/Applications`.
4. Double-click to launch.

Skimmy is signed with an **Apple Developer ID Application** certificate and
**notarized by Apple**, so macOS opens it cleanly — no Gatekeeper warnings,
no right-click-to-Open workaround.

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

| Target         | Purpose                                                                   |
| -------------- | ------------------------------------------------------------------------- |
| `make generate`| Produce `.xcodeproj` via XcodeGen                                         |
| `make build`   | Build Release configuration                                               |
| `make install` | Build + sign + copy to `/Applications`                                    |
| `make sign`    | Re-sign `/Applications/Skimmy.app`                                        |
| `make notarize`| Submit to Apple, wait, and staple the ticket                              |
| `make release` | `install` + `notarize` + zip into `dist/Skimmy-<ver>.zip` (shippable)     |
| `make clean`   | Delete `.build/`, `.xcodeproj`, and `dist/`                               |

### Cutting a release

```sh
# Bump to a new version and produce a shippable zip in one command
make release VERSION=1.0.1

# Or, if you've already bumped project.yml manually:
make release
```

`make release` takes 5–90 minutes — most of it is Apple's notarization queue.
The final artifact (`dist/Skimmy-<ver>.zip`) is signed, notarized, and stapled —
upload it directly to your website's download page.

### Code signing

`make install` auto-detects the first **Apple Development** certificate in your
keychain and signs the installed app with it. If you have an Apple ID signed
into Xcode, this just works — no Makefile edits needed.

To override the identity:

```sh
# Use a specific certificate by full name or SHA-1 hash
SIGN_IDENTITY="Apple Development: Jane Doe (ABCD123456)" make install

# Build unsigned (Gatekeeper will warn on every open — fine for local testing)
SIGN_IDENTITY=- make install
```

List your installed signing identities with:

```sh
security find-identity -v -p codesigning
```

For App Store or wider distribution, set `SIGN_IDENTITY` to an **Apple Developer
ID Application** certificate and add a notarization step (`xcrun notarytool`).

## Project layout

```
Skimmy/
├── App/            # Entry point (SkimmyApp.swift), DocumentGroup, menu commands
├── Model/          # MarkdownDocument, parsers (headings, links)
├── Views/          # SwiftUI + NSViewRepresentable wrappers (editor, reader, sidebar)
├── Utilities/      # Debounced parsing and persisted settings
└── Resources/      # Info.plist, marked.min.js, Assets.xcassets
```

## Tech stack

- **SwiftUI** (macOS 26+, Swift 5.9)
- **NSTextView** for editing Markdown source
- **WKWebView**, **marked.js**, and **Turndown** for formatted reading and editing
- **XcodeGen** (`project.yml` → `.xcodeproj`)

## Versioning

Skimmy follows [Semantic Versioning](https://semver.org): `MAJOR.MINOR.PATCH`.

| Segment | Bumped when… |
|---|---|
| **MAJOR** (`x`.y.z) | Breaking changes, significant redesigns, incompatible reworks |
| **MINOR** (x.`y`.z) | New features, small additions, backwards-compatible changes |
| **PATCH** (x.y.`z`) | Bug fixes, typo corrections, internal cleanup with no behavior change |

See [`CHANGELOG.md`](CHANGELOG.md) for the full version history. The current
version ships in `project.yml` as `MARKETING_VERSION`.

## Contributing

This is a personal project; the repo is private and not currently accepting PRs.
If you find a bug, please open an issue — I'd love to hear about it.

## Support the project ❤️

If Skimmy saves you time, consider [sponsoring on GitHub](https://github.com/sponsors/giulioc84).
Every bit helps keep the app maintained.

## License

**Proprietary — All Rights Reserved.** See [`LICENSE`](LICENSE).

The source code in this repository is not open-source. The compiled Skimmy
application is distributed via the author's website (and potentially the
Mac App Store in the future) under a separate end-user license agreement.

Third-party components included in builds (see [`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md))
remain under their original licenses.
