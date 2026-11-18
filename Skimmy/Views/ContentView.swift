import SwiftUI

struct ContentView: View {
    @Binding var document: MarkdownDocument
    let fileURL: URL?
    @EnvironmentObject var fontSizeManager: FontSizeManager
    @EnvironmentObject var sidebarStateManager: SidebarStateManager
    @StateObject private var session = DocumentSession()
    @AppStorage("splitFraction") private var splitFraction = 0.5

    private var sidebarVisibility: Binding<NavigationSplitViewVisibility> {
        Binding(
            get: { sidebarStateManager.isVisible ? .all : .detailOnly },
            set: { sidebarStateManager.isVisible = $0 != .detailOnly }
        )
    }

    var body: some View {
        NavigationSplitView(columnVisibility: sidebarVisibility) {
            SidebarView(session: session, fileURL: fileURL)
                .navigationSplitViewColumnWidth(min: 200, ideal: 240, max: 380)
        } detail: {
            detail
                .toolbar { toolbarContent }
        }
        .focusedSceneObject(session)
        .onAppear {
            session.start(text: document.text, fileURL: fileURL)
        }
        .onChange(of: document.text) { _, newValue in
            session.outline.textDidChange(newValue)
            if !newValue.isEmpty && session.showsWelcome {
                session.showsWelcome = false
            }
        }
        .onChange(of: fileURL) { _, newValue in
            session.fileURL = newValue
        }
        .frame(minWidth: 640, minHeight: 420)
    }

    // MARK: - Detail

    private var surface: Color { Color(nsColor: .textBackgroundColor) }

    @ViewBuilder
    private var detail: some View {
        if session.showsWelcome {
            WelcomeOverlay(onStartWriting: { session.startWriting() })
                .background(surface.ignoresSafeArea())
        } else {
            panes
                .background(surface.ignoresSafeArea())
                .overlay(alignment: .top) {
                    // Soft edge where text scrolls up towards the toolbar.
                    LinearGradient(colors: [surface, surface.opacity(0)], startPoint: .top, endPoint: .bottom)
                        .frame(height: 14)
                        .allowsHitTesting(false)
                }
                .overlay(alignment: .bottomTrailing) {
                    StatusPill(outline: session.outline)
                        .padding(12)
                }
                .overlay(alignment: .topTrailing) {
                    if session.isFindBarVisible {
                        FindBarView(session: session, finder: session.finder)
                            .padding(.top, 8)
                            .padding(.trailing, 12)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }
        }
    }

    private var panes: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                if session.mode.showsEditor {
                    MarkdownTextView(
                        text: $document.text,
                        fontSize: fontSizeManager.fontSize,
                        controller: session.editor
                    )
                    .frame(width: session.mode == .split ? editorWidth(in: geometry.size.width) : nil)
                }
                if session.mode == .split {
                    SplitDivider(fraction: $splitFraction, totalWidth: geometry.size.width)
                }
                if session.mode.showsPreview {
                    MarkdownWebView(
                        text: document.text,
                        fontSize: fontSizeManager.fontSize,
                        controller: session.preview
                    )
                }
            }
        }
    }

    private func editorWidth(in total: CGFloat) -> CGFloat {
        let clamped = min(SplitDivider.range.upperBound, max(SplitDivider.range.lowerBound, splitFraction))
        return ((total - SplitDivider.width) * clamped).rounded()
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            Picker("View", selection: $session.mode) {
                ForEach(ViewMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .help("Read, Split or Edit (⌘1, ⌘2, ⌘3)")
        }

        ToolbarItemGroup(placement: .primaryAction) {
            Button {
                fontSizeManager.decrease()
            } label: {
                Label("Smaller Text", systemImage: "textformat.size.smaller")
            }
            .help("Smaller text (⌘-)")

            Button {
                fontSizeManager.increase()
            } label: {
                Label("Larger Text", systemImage: "textformat.size.larger")
            }
            .help("Larger text (⌘=)")

            Button {
                session.find()
            } label: {
                Label("Find", systemImage: "magnifyingglass")
            }
            .help("Find (⌘F)")
        }
    }
}

/// The draggable line between editor and preview. Double-click to reset to half and half.
private struct SplitDivider: View {
    static let width: CGFloat = 9
    static let range: ClosedRange<Double> = 0.25...0.75

    @Binding var fraction: Double
    let totalWidth: CGFloat
    @State private var fractionAtDragStart: Double?

    var body: some View {
        Rectangle()
            .fill(Color(nsColor: .separatorColor))
            .frame(width: 1)
            .frame(maxHeight: .infinity)
            .frame(width: Self.width)
            .contentShape(Rectangle())
            .onHover { inside in
                if inside {
                    NSCursor.resizeLeftRight.push()
                } else {
                    NSCursor.pop()
                }
            }
            .gesture(
                DragGesture(minimumDistance: 1, coordinateSpace: .global)
                    .onChanged { value in
                        let start = fractionAtDragStart ?? fraction
                        fractionAtDragStart = start
                        guard totalWidth > 0 else { return }
                        let proposed = start + Double(value.translation.width / totalWidth)
                        fraction = min(Self.range.upperBound, max(Self.range.lowerBound, proposed))
                    }
                    .onEnded { _ in fractionAtDragStart = nil }
            )
            .onTapGesture(count: 2) { fraction = 0.5 }
            .accessibilityLabel("Resize editor and preview")
    }
}
