import Foundation

struct GitRepositorySnapshot: Equatable {
    let currentBranch: String?
    let headCommit: String?
    let defaultRemoteName: String?
    let remoteURL: String?
    let upstreamBranch: String?
    let aheadCount: Int
    let behindCount: Int
    let workingTree: GitWorkingTreeStatus
    let branches: [GitBranchRef]
    let submoduleChanges: [GitSubmoduleChange]
    var branchesOwnedElsewhere: Set<String> = []

    var isDetached: Bool {
        currentBranch == nil
    }

    var isDirty: Bool {
        workingTree.isClean == false
    }

    var hasRemote: Bool {
        defaultRemoteName != nil
    }

    var hasUpstream: Bool {
        upstreamBranch != nil
    }

    var isDiverged: Bool {
        aheadCount > 0 && behindCount > 0
    }

    var otherBranchesNeedingPush: [GitBranchRef] {
        branches.filter { branch in
            branch.name != currentBranch
                && branchesOwnedElsewhere.contains(branch.name) == false
                && (branch.isLocalOnly || branch.hasUnpushedCommits)
        }
    }

    static let empty = GitRepositorySnapshot(
        currentBranch: nil,
        headCommit: nil,
        defaultRemoteName: nil,
        remoteURL: nil,
        upstreamBranch: nil,
        aheadCount: 0,
        behindCount: 0,
        workingTree: .clean,
        branches: [],
        submoduleChanges: []
    )
}
