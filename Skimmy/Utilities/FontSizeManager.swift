import SwiftUI

final class FontSizeManager: ObservableObject {
    static let shared = FontSizeManager()

    @Published var fontSize: Double {
        didSet {
            UserDefaults.standard.set(fontSize, forKey: "fontSize")
        }
    }

    private let minSize: Double = 10
    private let maxSize: Double = 32
    private let step: Double = 2

    private init() {
        let stored = UserDefaults.standard.double(forKey: "fontSize")
        self.fontSize = stored > 0 ? stored : 16
    }

    func increase() {
        fontSize = min(fontSize + step, maxSize)
    }

    func decrease() {
        fontSize = max(fontSize - step, minSize)
    }

    func reset() {
        fontSize = 16
    }
}
