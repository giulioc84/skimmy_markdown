import SwiftUI

enum MarkdownFormat: String {
    case paragraph, heading1, heading2, heading3, heading4, heading5, heading6
    case bold, italic, code, unorderedList, orderedList, link, unlink
}

struct FormattingToolbar: View {
    let onFormat: (MarkdownFormat, String?, String?) -> Void
    let loadLinkContext: (@escaping ([String: String]) -> Void) -> Void
    @State private var linkDraft: LinkDraft?
    @State private var pendingLinkEdit: (format: MarkdownFormat, address: String?, text: String?)?
    @State private var isLinkUnavailable = false

    var body: some View {
        Menu {
            Section {
                Button("Bold", systemImage: "bold") { onFormat(.bold, nil, nil) }
                Button("Italic", systemImage: "italic") { onFormat(.italic, nil, nil) }
                Button("Inline Code", systemImage: "chevron.left.forwardslash.chevron.right") { onFormat(.code, nil, nil) }
                Button("Link…", systemImage: "link") {
                    loadLinkContext { context in
                        guard let text = context["text"] else {
                            isLinkUnavailable = true
                            return
                        }
                        linkDraft = LinkDraft(address: context["url"] ?? "", text: text, isExisting: context["url"] != nil)
                    }
                }
            }
            Section {
                Button("Body Text") { onFormat(.paragraph, nil, nil) }
                Menu("Heading") {
                    ForEach(Array(headings.enumerated()), id: \.offset) { index, format in
                        Button("Heading \(index + 1)") { onFormat(format, nil, nil) }
                    }
                }
                Button("Bulleted List", systemImage: "list.bullet") { onFormat(.unorderedList, nil, nil) }
                Button("Numbered List", systemImage: "list.number") { onFormat(.orderedList, nil, nil) }
            }
        } label: {
            Label("Format", systemImage: "textformat")
        }
        .help("Format Markdown")
        .accessibilityLabel("Format Markdown")
        .sheet(item: $linkDraft, onDismiss: submitLinkEdit) { draft in
            LinkEditor(draft: draft) { format, address, text in
                pendingLinkEdit = (format, address, text)
                linkDraft = nil
            }
        }
        .alert("Choose a location for the link", isPresented: $isLinkUnavailable) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Place the cursor or select text within one paragraph, outside inline code.")
        }
    }

    private func submitLinkEdit() {
        guard let edit = pendingLinkEdit else { return }
        pendingLinkEdit = nil
        onFormat(edit.format, edit.address, edit.text)
    }

    private let headings: [MarkdownFormat] = [.heading1, .heading2, .heading3, .heading4, .heading5, .heading6]
}

private struct LinkDraft: Identifiable {
    let id = UUID()
    var address: String
    var text: String
    let isExisting: Bool

    var destination: String? {
        let value = address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard value.rangeOfCharacter(from: .whitespacesAndNewlines.union(.controlCharacters)) == nil else { return nil }
        if value.hasPrefix("#") { return value }
        guard let components = URLComponents(string: value) else { return nil }
        switch components.scheme?.lowercased() {
        case "https", "http": return components.host?.isEmpty == false ? value : nil
        case "mailto": return components.path.isEmpty ? nil : value
        default: return nil
        }
    }
}

private struct LinkEditor: View {
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isAddressFocused: Bool
    @State var draft: LinkDraft
    let submit: (MarkdownFormat, String?, String?) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(draft.isExisting ? "Edit Link" : "Insert Link")
                .font(.headline)
            Form {
                TextField("Address", text: $draft.address, prompt: Text("https://example.com"))
                    .focused($isAddressFocused)
                TextField("Text", text: $draft.text)
            }
            if !draft.address.isEmpty && draft.destination == nil {
                Text("Enter a web address, an email link, or a heading link such as #notes.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            HStack {
                if draft.isExisting {
                    Button("Remove Link") { submit(.unlink, nil, nil) }
                }
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button(draft.isExisting ? "Apply" : "Insert") {
                    if let destination = draft.destination { submit(.link, destination, draft.text) }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(draft.destination == nil)
            }
        }
        .padding(20)
        .frame(width: 390)
        .onAppear { isAddressFocused = true }
    }
}
