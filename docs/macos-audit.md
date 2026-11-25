# Skimmy macOS audit

Reviewed November 25, 2026 against Apple's current macOS Human Interface Guidelines. The workspace targets macOS 26 and the test Mac runs macOS 27.2.1 with Xcode 26.2. The review covered menus, document handling, window controls, settings, Help, keyboard access, and the native and WebKit editing surfaces. [Designing for macOS](https://developer.apple.com/design/human-interface-guidelines/designing-for-macos) · [Apple accessibility guidance](https://developer.apple.com/design/human-interface-guidelines/accessibility)

## Findings and changes

| Area | Finding and change |
| --- | --- |
| Edit and Window menu flicker | The app observed sidebar and focus changes at scene level. The split view could publish the same sidebar value repeatedly, and document commands received fresh closures as the view updated. The revised code isolates command state and gives each document window a stable command target. An active menu bar still needs a visual retest. |
| Standard menus | SwiftUI supplies App, File, Edit, View, Window, and Help menus. Skimmy keeps the native File and Window commands and the native undo and clipboard groups. Document commands stay visible and disable when unavailable. |
| Help | The native Help menu has a bundled Apple Help book with a local search index. It covers reading, editing, finding text, using the sidebar, and choosing an appearance. |
| Appearance | **Skimmy > Settings > Appearance** offers System, Light, and Dark. System is the default. The app remembers the choice and applies it to existing windows. The rendered page uses WebKit's semantic canvas colors, with stronger colors when increased contrast is requested. |
| Keyboard and focus | **⌘F**, **⌘G**, and **⇧⌘G** open Find and repeat searches. Closing Find returns focus to the document. Formatted links can receive keyboard focus, Return follows a focused link, and a heading link moves focus to its heading in Read. |
| Feedback | Find reports when there is no match. Recent-file failures show the system error. Read-only documents have a text status, and unavailable zoom controls are disabled. |
| Sidebar and motion | Each document window remembers its own sidebar state. The sidebar exposes named heading and link groups. Navigation respects Reduce Motion. |
| Document types | Skimmy registers as a standard Markdown editor and preserves the existing extensions and UTI. Native document windows handle Open, Save, Save As, Duplicate, and Revert. |

[Apple menu bar guidance](https://developer.apple.com/design/human-interface-guidelines/the-menu-bar) · [Mac keyboard shortcuts](https://support.apple.com/en-us/102650) · [Apple Dark Mode guidance](https://developer.apple.com/design/human-interface-guidelines/dark-mode) · [Apple focus guidance](https://developer.apple.com/design/human-interface-guidelines/focus-and-selection/) · [File handler rank definitions](https://developer.apple.com/library/archive/documentation/General/Reference/InfoPlistKeyReference/Articles/CoreFoundationKeys.html)

## Accessibility checks

The formatted page exposes semantic headings, links, lists, and table headers. The native Source editor has an accessibility label. The default macOS controls provide accessibility semantics for toolbar buttons, appearance choices, and text editing. In offscreen WebKit, the normal-size body, link, and quote colors met a 4.5:1 contrast threshold on both backgrounds.

| Preview text | Light | Dark |
| --- | ---: | ---: |
| Body | 21.0:1 | 16.7:1 |
| Links | 7.2:1 | 8.3:1 |
| Quotes and muted text | 7.3:1 | 7.4:1 |

Offscreen tests covered keyboard link activation in Edit, heading focus in Read, and exact Markdown preservation during navigation. At 200% text size in a 620-pixel reader, wide tables and code blocks kept scrolling within their own keyboard-focusable regions. Existing WebKit and AppKit views responded to changes between System, Light, and Dark. [Apple color guidance](https://developer.apple.com/design/human-interface-guidelines/color) · [Apple accessibility guidance](https://developer.apple.com/design/human-interface-guidelines/accessibility)

## Scope decisions

- **⌘E** remains Skimmy’s formatted-editing shortcut. Apple assigns the same key to Use Selection for Find. Skimmy’s Find submenu uses the standard search and repeat-search shortcuts.
- The review covered native window actions, save behavior, and accessible controls. Features such as toolbar customization, localization beyond English, and a custom print workflow are separate product decisions. [Mac keyboard shortcuts](https://support.apple.com/en-us/102650) · [Apple printing guidance](https://developer.apple.com/design/human-interface-guidelines/printing)

## Live checks still needed

- Observe Edit and Window while typing and switching focus among the document, sidebar, Find, and Settings.
- Walk the toolbar, sidebar, document, Find, and Settings with VoiceOver and Full Keyboard Access. Confirm the heading announcement after a jump and no-match feedback.
- Check the smallest window at maximum text size with Increase Contrast, Reduce Transparency, and Reduce Motion enabled.
- Open the Help book through the menu and search for a topic. Check the system print panel and pagination in Read, Edit, and Source, and repeat the launch check on macOS 26.
