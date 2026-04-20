import SwiftUI

struct ToggleEditModeKey: FocusedValueKey {
    typealias Value = () -> Void
}

struct ToggleFindBarKey: FocusedValueKey {
    typealias Value = () -> Void
}

struct SaveDocumentKey: FocusedValueKey {
    typealias Value = () -> Void
}

extension FocusedValues {
    var toggleEditMode: (() -> Void)? {
        get { self[ToggleEditModeKey.self] }
        set { self[ToggleEditModeKey.self] = newValue }
    }

    var toggleFindBar: (() -> Void)? {
        get { self[ToggleFindBarKey.self] }
        set { self[ToggleFindBarKey.self] = newValue }
    }

    var saveDocument: (() -> Void)? {
        get { self[SaveDocumentKey.self] }
        set { self[SaveDocumentKey.self] = newValue }
    }
}
