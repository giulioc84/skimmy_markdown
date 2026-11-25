import SwiftUI

private enum SidebarTab: String, CaseIterable {
    case contents = "Contents"
    case links = "Links"
}

struct SidebarView: View {
    let headings: [DocumentHeading]
    let links: [DocumentLink]
    let canJumpToHeading: Bool
    let onHeading: (DocumentHeading) -> Void
    let onLink: (String) -> Void

    @State private var selectedTab: SidebarTab = .contents

    var body: some View {
        VStack(spacing: 4) {
            Picker("Sidebar view", selection: $selectedTab) {
                ForEach(SidebarTab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            .padding(.horizontal, 10)
            .padding(.top, 8)

            switch selectedTab {
            case .contents:
                contentsTab
            case .links:
                linksTab
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Document navigation")
    }

    @ViewBuilder
    private var contentsTab: some View {
        if headings.isEmpty {
            emptyLabel("No headings")
        } else {
            if !canJumpToHeading {
                emptyLabel("Switch to Read or Edit to jump to a heading.")
            }
            List(headings) { heading in
                Button {
                    onHeading(heading)
                } label: {
                    Text(heading.text)
                        .fontWeight(heading.level == 1 ? .semibold : .regular)
                        .lineLimit(2)
                        .padding(.leading, CGFloat(heading.level - 1) * 10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(!canJumpToHeading)
                .accessibilityHint("Jumps to this heading", isEnabled: canJumpToHeading)
                .help(heading.text)
            }
            .listStyle(.sidebar)
            .accessibilityLabel("Document headings")
        }
    }

    @ViewBuilder
    private var linksTab: some View {
        if links.isEmpty {
            emptyLabel("No links")
        } else {
            List(links) { link in
                let enabled = canFollow(link.url)
                Button {
                    onLink(link.url)
                } label: {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: link.isImage ? "photo" : "link")
                            .foregroundStyle(.secondary)
                            .accessibilityHidden(true)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(link.text.isEmpty ? link.url : link.text)
                                .lineLimit(2)

                            if !link.text.isEmpty {
                                Text(link.url)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(!enabled)
                .accessibilityLabel(link.text.isEmpty ? link.url : link.text)
                .accessibilityHint(
                    link.url.hasPrefix("#") ? "Jumps to a section in this document" : "Opens this link",
                    isEnabled: enabled
                )
                .help(link.url)
            }
            .listStyle(.sidebar)
            .accessibilityLabel("Document links")
        }
    }

    private func canFollow(_ destination: String) -> Bool {
        if destination.hasPrefix("#") { return canJumpToHeading }
        guard let scheme = URL(string: destination)?.scheme?.lowercased() else { return false }
        return MarkdownWebView.externalSchemes.contains(scheme)
    }

    private func emptyLabel(_ title: String) -> some View {
        Text(title)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
    }
}
