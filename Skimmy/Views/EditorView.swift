import SwiftUI

struct EditorView: View {
    @Binding var text: String
    @EnvironmentObject var fontSizeManager: FontSizeManager

    var body: some View {
        MarkdownTextView(text: $text, fontSize: fontSizeManager.fontSize)
    }
}
