import SwiftUI

struct WelcomeOverlay: View {
    var onStartEditing: () -> Void

    private var recentURLs: [URL] {
        Array(NSDocumentController.shared.recentDocumentURLs.prefix(10))
    }

    var body: some View {
        ViewThatFits(in: .vertical) {
            welcome
            ScrollView { welcome }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var welcome: some View {
        VStack(spacing: 20) {
            VStack(spacing: 8) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 72, height: 72)
                    .accessibilityHidden(true)

                Text("Skimmy")
                    .font(.largeTitle.weight(.semibold))
                    .accessibilityAddTraits(.isHeader)
            }

            HStack {
                Button("Open File…") {
                    NSDocumentController.shared.openDocument(nil)
                }
                .buttonStyle(.bordered)

                Button("Start Writing", action: onStartEditing)
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
            }
            .controlSize(.large)

            let documents = recentURLs
            if !documents.isEmpty {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Recent Documents")
                        .font(.headline)
                        .accessibilityAddTraits(.isHeader)
                        .padding(.bottom, 3)

                    ForEach(documents, id: \.self) { url in
                        Button {
                            openDocument(url)
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "doc.text")
                                    .foregroundStyle(.secondary)
                                    .accessibilityHidden(true)

                                Text(url.lastPathComponent)
                                    .lineLimit(1)
                                    .truncationMode(.middle)

                                Spacer(minLength: 12)

                                Text((url.deletingLastPathComponent().path as NSString).abbreviatingWithTildeInPath)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(url.lastPathComponent)
                        .accessibilityValue(url.deletingLastPathComponent().path)
                        .help(url.path)
                        .padding(.vertical, 3)
                    }
                }
                .frame(maxWidth: 460)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
    }

    private func openDocument(_ url: URL) {
        NSDocumentController.shared.openDocument(withContentsOf: url, display: true) { _, _, error in
            guard let error else { return }
            let nsError = error as NSError
            if nsError.domain == NSCocoaErrorDomain && nsError.code == NSUserCancelledError { return }
            NSApp.presentError(error)
        }
    }
}
