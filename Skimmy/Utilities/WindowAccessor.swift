import SwiftUI

struct WindowAccessor: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            guard let window = view.window else { return }
            window.representedURL = nil
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            window.toolbar?.isVisible = false
            window.isOpaque = true
            window.backgroundColor = .windowBackgroundColor

        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
    }
}
