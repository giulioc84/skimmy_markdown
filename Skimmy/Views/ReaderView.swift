import SwiftUI

struct ReaderView: View {
    let text: String
    let scrollProxy: ScrollProxy
    @EnvironmentObject var fontSizeManager: FontSizeManager

    var body: some View {
        MarkdownWebView(
            text: text,
            fontSize: fontSizeManager.fontSize,
            scrollProxy: scrollProxy
        )
    }
}
