import Foundation

struct SyncPlanStep: Equatable, Identifiable {
    let identifier: String
    let repositoryName: String
    let branch: String?
    let action: SyncPlanAction
    let trackedChanges: [GitFileChange]
    let selectableUntrackedPaths: [String]
    let includedUntrackedPaths: [String]
    let outstandingBranches: [GitBranchRef]
    let submoduleChanges: [GitSubmoduleChange]
    var worktreeName: String?
    var branchesToPush: [GitBranchRef] = []

    var id: String {
        identifier
    }

    var displayName: String {
        guard let worktreeName else {
            return repositoryName
        }

        return String(localized: "\(repositoryName) › \(worktreeName)")
    }

    var hasUntrackedFiles: Bool {
        selectableUntrackedPaths.isEmpty == false
    }

    var includesAllUntracked: Bool {
        hasUntrackedFiles && Set(includedUntrackedPaths) == Set(selectableUntrackedPaths)
    }

    var isActionable: Bool {
        action.isActionable
    }

    var newUpstreamBranches: [String] {
        let others = branchesToPush.filter(\.isLocalOnly).map(\.name)

        guard case .commitAndPush(_, setsUpstream: true) = action, let branch else {
            return others
        }

        return [branch] + others
    }
}
