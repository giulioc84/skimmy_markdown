import SwiftUI

struct WelcomeOverlay: View {
    var onStartEditing: () -> Void

    private var recentURLs: [URL] {
        Array(NSDocumentController.shared.recentDocumentURLs.prefix(10))
    }

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "doc.richtext")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("Skimmy")
                .font(.largeTitle)
                .fontWeight(.medium)

            if recentURLs.isEmpty {
                Text("Open a Markdown file or start writing")
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Recent Documents")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                        .padding(.bottom, 4)

                    ForEach(recentURLs, id: \.self) { url in
                        Button(action: { openDocument(url) }) {
                            HStack {
                                Image(systemName: "doc.text")
                                    .foregroundStyle(.secondary)
                                Text(url.lastPathComponent)
                                    .lineLimit(1)
                                Spacer()
                                Text(url.deletingLastPathComponent().path)
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                                    .lineLimit(1)
                            }
                        }
                        .buttonStyle(.plain)
                        .padding(.vertical, 2)
                    }
                }
                .frame(maxWidth: 500)
            }

            Button("New Document") {
                onStartEditing()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            Spacer()
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func openDocument(_ url: URL) {
        NSDocumentController.shared.openDocument(
            withContentsOf: url,
            display: true
        ) { _, _, _ in }
    }
}
