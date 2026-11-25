# Relative Markdown links

Planned. Follow links such as `[Decisions](./notes.md#decisions)` from a saved Markdown document. Open the destination in a native Skimmy document window and jump to the heading when it has loaded.

Resolve the path against the directory of the current document. Route opening through the native document controller so normal macOS file access, open-window reuse, and error handling apply. A missing file, non-Markdown destination, or unsaved source document needs a clear explanation. Same-document links and ordinary web links keep their current behavior.

Verify sibling paths, subfolders, paths containing spaces or non-ASCII characters, links with and without fragments, missing headings, missing files, and destinations already open in another window. Check keyboard activation in Read and Edit, and confirm that following a link leaves both files byte-identical.
