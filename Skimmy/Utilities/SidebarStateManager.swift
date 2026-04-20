import SwiftUI

final class SidebarStateManager: ObservableObject {
    static let shared = SidebarStateManager()

    @Published var isVisible: Bool {
        didSet {
            UserDefaults.standard.set(isVisible, forKey: "sidebarVisible")
        }
    }

    private init() {
        // UserDefaults.bool returns false for unset keys, which is our desired default
        self.isVisible = UserDefaults.standard.bool(forKey: "sidebarVisible")
    }

    func toggle() {
        withAnimation(.easeOut(duration: 0.2)) {
            isVisible.toggle()
        }
    }
}
