import Foundation

struct WorkspacePlan: Equatable {
    let manifestName: String
    let entries: [WorkspacePlanEntry]

    static let empty = WorkspacePlan(manifestName: "", entries: [])

    var cloneCount: Int {
        entries.count(where: \.willClone)
    }

    var updateCount: Int {
        entries.count { entry in
            switch entry.action {
            case .update:
                true
            case .clone,
                 .noWorkspaceRoot,
                 .noRemote:
                false
            }
        }
    }

    var blockedEntries: [WorkspacePlanEntry] {
        entries.filter { $0.action.isActionable == false }
    }
}
