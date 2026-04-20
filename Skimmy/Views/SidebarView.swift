import SwiftUI

private enum SidebarTab: String, CaseIterable {
    case contents = "Contents"
    case links = "Links"
}

struct SidebarView: View, Equatable {
    let headings: [DocumentHeading]
    let links: [DocumentLink]
    let scrollProxy: ScrollProxy?
    let isEditing: Bool

    static func == (lhs: SidebarView, rhs: SidebarView) -> Bool {
        lhs.headings == rhs.headings && lhs.links == rhs.links && lhs.isEditing == rhs.isEditing
    }

    @State private var selectedTab: SidebarTab = .contents

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $selectedTab) {
                ForEach(SidebarTab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 12)
            .padding(.top, 38)
            .padding(.bottom, 8)

            switch selectedTab {
            case .contents:
                contentsTab
            case .links:
                linksTab
            }

            Spacer(minLength: 0)
        }
        .frame(width: 220)
        .frame(maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    @ViewBuilder
    private var contentsTab: some View {
        if headings.isEmpty {
            Text("No headings")
                .font(.system(size: 13))
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 12)
                .padding(.top, 4)
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(headings) { heading in
                        Button {
                            if !isEditing {
                                scrollProxy?.scrollTo(heading.id)
                            }
                        } label: {
                            Text(heading.text)
                                .font(.system(size: 13, weight: weight(for: heading.level)))
                                .lineLimit(2)
                                .truncationMode(.tail)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                        .padding(.vertical, 2)
                        .padding(.leading, 8 + CGFloat(heading.level - 1) * 12)
                        .padding(.trailing, 8)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var linksTab: some View {
        if links.isEmpty {
            Text("No links")
                .font(.system(size: 13))
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 12)
                .padding(.top, 4)
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(links) { link in
                        Button {
                            if let url = URL(string: link.url) {
                                NSWorkspace.shared.open(url)
                            }
                        } label: {
                            HStack(alignment: .top, spacing: 6) {
                                Image(systemName: link.isImage ? "photo" : "link")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 14, alignment: .center)
                                    .padding(.top, 2)

                                VStack(alignment: .leading, spacing: 1) {
                                    Text(link.text.isEmpty ? link.url : link.text)
                                        .font(.system(size: 13))
                                        .lineLimit(2)
                                        .truncationMode(.tail)

                                    if !link.text.isEmpty {
                                        Text(link.url)
                                            .font(.system(size: 10))
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                            .truncationMode(.middle)
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                        .padding(.vertical, 2)
                        .padding(.horizontal, 8)
                    }
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
