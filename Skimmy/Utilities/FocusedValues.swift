import SwiftUI

@MainActor
@Observable
final class DocumentMenuTarget {
    enum Action {
        case toggleEditing
        case showFind
        case nextMatch
        case previousMatch
        case setSidebarVisible(Bool)
    }

    struct Availability: Equatable {
        var canEdit: Bool
        var canFind: Bool
        var canNavigateMatches: Bool
        var isSidebarVisible = false

        static let none = Self(canEdit: false, canFind: false, canNavigateMatches: false)
    }

    private(set) var canEdit = false
    private(set) var canFind = false
    private(set) var canNavigateMatches = false
    private(set) var isSidebarVisible = false

    @ObservationIgnored
    private var handle: (Action) -> Void = { _ in }

    func configure(_ availability: Availability, perform: @escaping (Action) -> Void) {
        handle = perform
        if canEdit != availability.canEdit { canEdit = availability.canEdit }
        if canFind != availability.canFind { canFind = availability.canFind }
        if canNavigateMatches != availability.canNavigateMatches { canNavigateMatches = availability.canNavigateMatches }
        if isSidebarVisible != availability.isSidebarVisible { isSidebarVisible = availability.isSidebarVisible }
    }

    func clear() {
        configure(.none) { _ in }
    }

    func perform(_ action: Action) {
        let enabled: Bool
        switch action {
        case .toggleEditing:
            enabled = canEdit
        case .showFind, .setSidebarVisible:
            enabled = canFind
        case .nextMatch, .previousMatch:
            enabled = canNavigateMatches
        }
        if enabled { handle(action) }
    }
}
