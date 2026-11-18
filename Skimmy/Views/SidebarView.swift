import SwiftUI

private enum SidebarTab: String, CaseIterable {
    case contents = "Contents"
    case links = "Links"
}

struct SidebarView: View {
    let session: DocumentSession
    let fileURL: URL?
    @State private var selectedTab: SidebarTab = .contents

    var body: some View {
        VStack(spacing: 0) {
            Picker("Sidebar section", selection: $selectedTab) {
                ForEach(SidebarTab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            switch selectedTab {
            case .contents:
                OutlineList(outline: session.outline, session: session)
            case .links:
                LinkList(outline: session.outline, fileURL: fileURL)
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }
}

private struct OutlineList: View {
    @ObservedObject var outline: DocumentParser
    let session: DocumentSession

    var body: some View {
        if outline.headings.isEmpty {
            EmptyHint(text: "Headings you write with # show up here.")
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    // Lazy: a long document can have thousands of headings.
                    LazyVStack(alignment: .leading, spacing: 1) {
                        ForEach(outline.headings) { heading in
                            let isActive = heading.id == outline.activeHeadingID
                            SidebarRow(isActive: isActive) {
                                session.jump(toLine: heading.lineIndex)
                            } label: {
                                Text(heading.text)
                                    .font(.system(size: 13, weight: weight(for: heading.level)))
                                    .foregroundStyle(isActive ? Color.accentColor : Color.primary)
                                    .lineLimit(2)
                                    .padding(.leading, CGFloat(heading.level - 1) * 12)
                            }
                            .id(heading.id)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.bottom, 12)
                }
                .onChange(of: outline.activeHeadingID) { _, id in
                    guard let id else { return }
                    withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo(id) }
                }
            }
        }
    }

    private func weight(for level: Int) -> Font.Weight {
        switch level {
        case 1: .bold
        case 2: .semibold
        default: .regular
        }
    }
}

private struct LinkList: View {
    @ObservedObject var outline: DocumentParser
    let fileURL: URL?

    var body: some View {
        if outline.links.isEmpty {
            EmptyHint(text: "Links and images in the document show up here.")
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 1) {
                    ForEach(outline.links) { link in
                        SidebarRow(isActive: false) {
                            LinkOpener.open(link.url, relativeTo: fileURL)
                        } label: {
                            HStack(alignment: .top, spacing: 7) {
                                Image(systemName: link.isImage ? "photo" : "link")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 14)
                                    .padding(.top, 2)

                                VStack(alignment: .leading, spacing: 1) {
                                    Text(link.text.isEmpty ? link.url : link.text)
                                        .font(.system(size: 13))
                                        .lineLimit(2)

                                    if !link.text.isEmpty {
                                        Text(link.url)
                                            .font(.system(size: 11))
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                            .truncationMode(.middle)
                                    }
                                }
                            }
                        }
                        .help(link.url)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 12)
            }
        }
    }
}

private struct SidebarRow<Content: View>: View {
    let isActive: Bool
    let action: () -> Void
    let label: Content
    @State private var isHovered = false

    init(isActive: Bool, action: @escaping () -> Void, @ViewBuilder label: () -> Content) {
        self.isActive = isActive
        self.action = action
        self.label = label()
    }

    private var fill: Color {
        if isActive { return Color.accentColor.opacity(0.16) }
        return isHovered ? Color.primary.opacity(0.07) : Color.clear
    }

    var body: some View {
        Button(action: action) {
            label
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 5)
                .padding(.horizontal, 8)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(fill))
        .onHover { isHovered = $0 }
    }
}

private struct EmptyHint: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 12))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.top, 6)
        Spacer(minLength: 0)
    }
}
