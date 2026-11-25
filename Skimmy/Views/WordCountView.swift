import SwiftUI

struct WordCountView: View {
    let text: String
    @State private var counts: MarkdownCounts?

    var body: some View {
        let count = counts ?? MarkdownCounts(words: 0, characters: 0)
        let words = "\(count.words.formatted()) \(count.words == 1 ? "word" : "words")"
        let characters = "\(count.characters.formatted()) \(count.characters == 1 ? "character" : "characters")"
        Text("\(words) · \(characters)")
            .font(.caption)
            .monospacedDigit()
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.horizontal, 14)
            .padding(.vertical, 5)
            .help("Markdown source count")
            .accessibilityLabel("Markdown source count")
            .accessibilityValue("\(words), \(characters)")
            .opacity(counts == nil ? 0 : 1)
            .accessibilityHidden(counts == nil)
            .task(id: text) { await updateCounts() }
    }

    private func updateCounts() async {
        if counts != nil {
            try? await Task.sleep(for: .milliseconds(100))
        }
        guard !Task.isCancelled else { return }

        let snapshot = text
        let worker = Task.detached(priority: .utility) { MarkdownCounts.count(in: snapshot) }
        let result = await withTaskCancellationHandler {
            await worker.value
        } onCancel: {
            worker.cancel()
        }
        if !Task.isCancelled, let result { counts = result }
    }
}

struct MarkdownCounts {
    let words: Int
    let characters: Int

    static func count(in text: String) -> Self? {
        if let ascii = text.utf8.withContiguousStorageIfAvailable(asciiCounts) ?? nil {
            return ascii
        }

        var words = 0
        var characters = 0
        var insideWord = false
        for character in text {
            if characters.isMultiple(of: 4096) && Task.isCancelled { return nil }
            let isWordCharacter = !character.isWhitespace
            if isWordCharacter && !insideWord { words += 1 }
            insideWord = isWordCharacter
            characters += 1
        }
        return Self(words: words, characters: characters)
    }

    private static func asciiCounts(_ bytes: UnsafeBufferPointer<UInt8>) -> Self? {
        var words = 0
        var characters = bytes.count
        var insideWord = false
        var lastWasCR = false
        for (index, byte) in bytes.enumerated() {
            if byte >= 128 || (index.isMultiple(of: 4096) && Task.isCancelled) { return nil }
            let isWordCharacter = byte != 32 && !(9...13).contains(byte)
            if isWordCharacter && !insideWord { words += 1 }
            // Swift counts CRLF as one Character.
            if lastWasCR && byte == 10 { characters -= 1 }
            insideWord = isWordCharacter
            lastWasCR = byte == 13
        }
        return Self(words: words, characters: characters)
    }
}
