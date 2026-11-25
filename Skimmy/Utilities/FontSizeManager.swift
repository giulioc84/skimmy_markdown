import SwiftUI

final class FontSizeManager: ObservableObject {
    static let shared = FontSizeManager()

    @Published private(set) var fontSize: Double {
        didSet {
            UserDefaults.standard.set(fontSize, forKey: "fontSize")
        }
    }

    private let minSize: Double = 10
    private let maxSize: Double = 32
    private let step: Double = 2
    private let defaultSize: Double = 16

    var canIncrease: Bool { fontSize < maxSize }
    var canDecrease: Bool { fontSize > minSize }
    var canReset: Bool { fontSize != defaultSize }

    private init() {
        let stored = UserDefaults.standard.double(forKey: "fontSize")
        fontSize = stored.isFinite && stored > 0 ? min(max(stored, minSize), maxSize) : defaultSize
    }

    func increase() {
        setSize(min(fontSize + step, maxSize))
    }

    func decrease() {
        setSize(max(fontSize - step, minSize))
    }

    func reset() {
        setSize(defaultSize)
    }

    private func setSize(_ size: Double) {
        if fontSize != size {
            fontSize = size
        }
    }
}
