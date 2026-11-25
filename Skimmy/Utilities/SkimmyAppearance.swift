import AppKit

enum SkimmyAppearance: String {
    case system
    case light
    case dark

    static let storageKey = "appearance"

    @MainActor
    func apply(to application: NSApplication) {
        switch self {
        case .system: application.appearance = nil
        case .light: application.appearance = NSAppearance(named: .aqua)
        case .dark: application.appearance = NSAppearance(named: .darkAqua)
        }
    }
}

final class SkimmyAppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillFinishLaunching(_ notification: Notification) {
        guard let application = notification.object as? NSApplication else { return }
        let savedValue = UserDefaults.standard.string(forKey: SkimmyAppearance.storageKey)
        let appearance = savedValue.flatMap(SkimmyAppearance.init(rawValue:)) ?? .system
        appearance.apply(to: application)
    }
}
