import SwiftUI

struct SkimmySettingsView: View {
    @AppStorage(SkimmyAppearance.storageKey) private var appearance: SkimmyAppearance = .system

    var body: some View {
        Form {
            Picker("Appearance", selection: $appearance) {
                Text("System").tag(SkimmyAppearance.system)
                Text("Light").tag(SkimmyAppearance.light)
                Text("Dark").tag(SkimmyAppearance.dark)
            }
            .pickerStyle(.inline)
            .accessibilityHint("System follows your Mac’s appearance setting.")
        }
        .padding(24)
        .frame(minWidth: 320)
        .onChange(of: appearance) { _, selection in
            selection.apply(to: NSApplication.shared)
        }
    }
}
