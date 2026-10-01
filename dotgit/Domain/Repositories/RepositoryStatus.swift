import Foundation

enum RepositoryStatus: String, Equatable, CaseIterable {
    case notCloned
    case loading
    case failed
    case diverged
    case dirty
    case ahead
    case behind
    case clean
    case unreadable

    var title: String {
        switch self {
        case .notCloned:
            String(localized: "Not cloned")
        case .loading:
            String(localized: "Reading")
        case .failed:
            String(localized: "Failed")
        case .diverged:
            String(localized: "Diverged")
        case .dirty:
            String(localized: "Local changes")
        case .ahead:
            String(localized: "Ahead")
        case .behind:
            String(localized: "Behind")
        case .clean:
            String(localized: "In sync")
        case .unreadable:
            String(localized: "Unreadable")
        }
    }

    var symbolName: String {
        switch self {
        case .notCloned:
            "icloud.and.arrow.down"
        case .loading:
            "circle.dotted"
        case .failed:
            "exclamationmark.triangle.fill"
        case .diverged:
            "arrow.triangle.branch"
        case .dirty:
            "pencil.circle.fill"
        case .ahead:
            "arrow.up.circle.fill"
        case .behind:
            "arrow.down.circle.fill"
        case .clean:
            "checkmark.circle.fill"
        case .unreadable:
            "questionmark.circle"
        }
    }
}
