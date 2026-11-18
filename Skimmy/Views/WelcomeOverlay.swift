import SwiftUI

struct WelcomeOverlay: View {
    var onStartWriting: () -> Void

    private var recentURLs: [URL] {
        Array(NSDocumentController.shared.recentDocumentURLs.prefix(6))
    }

    var body: some View {
        VStack(spacing: 26) {
            VStack(spacing: 8) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 104, height: 104)
                    .accessibilityHidden(true)

                Text("Skimmy")
                    .font(.system(size: 30, weight: .bold))

                Text("Open a Markdown file, or start writing.")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 10) {
                Button("New Document", action: onStartWriting)
                    .buttonStyle(.glassProminent)
                    .keyboardShortcut(.defaultAction)

                Button("Open…") {
                    NSDocumentController.shared.openDocument(nil)
                }
                .buttonStyle(.glass)
            }
            .controlSize(.extraLarge)

            if !recentURLs.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Recent")
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .padding(.leading, 14)

                    VStack(spacing: 2) {
                        ForEach(recentURLs, id: \.self) { url in
                            RecentRow(url: url)
                        }
                    }
                    .padding(6)
                    .glassEffect(.regular, in: .rect(cornerRadius: 18))
                }
                .frame(maxWidth: 520)
            }
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct RecentRow: View {
    let url: URL
    @State private var isHovered = false

    private var folder: String {
        (url.deletingLastPathComponent().path as NSString).abbreviatingWithTildeInPath
    }

    var body: some View {
        Button {
            NSDocumentController.shared.openDocument(withContentsOf: url, display: true) { _, _, _ in }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "doc.text")
                    .foregroundStyle(isHovered ? Color.accentColor : Color.secondary)
                Text(url.lastPathComponent)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                Spacer(minLength: 12)
                Text(folder)
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.head)
            }
            .padding(.horizontal, 12)
            .frame(minHeight: 38)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(isHovered ? Color.accentColor.opacity(0.12) : Color.clear)
        )
        .onHover { isHovered = $0 }
    }
}
