import Foundation

struct WorkspacePlanEntry: Equatable, Identifiable {
    enum Action: Equatable {
        case clone(URL)
        case update(URL)
        case noWorkspaceRoot
        case noRemote

        var isActionable: Bool {
            switch self {
            case .clone,
                 .update:
                true
            case .noWorkspaceRoot,
                 .noRemote:
                false
            }
        }

        var summary: String {
            switch self {
            case let .clone(destination):
                String(localized: "Clone into \(destination.path(percentEncoded: false))")
            case let .update(destination):
                String(localized: "Already at \(destination.path(percentEncoded: false))")
            case .noWorkspaceRoot:
                String(localized: "Set this Mac's workspace root before cloning")
            case .noRemote:
                String(localized: "The manifest records no remote to clone from")
            }
        }
    }

    let identifier: String
    let name: String
    let action: Action

    var id: String {
        identifier
    }

    var willClone: Bool {
        switch action {
        case .clone:
            true
        case .update,
             .noWorkspaceRoot,
             .noRemote:
            false
        }
    }
}
