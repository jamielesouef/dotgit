import Foundation

enum BranchSyncPolicyUseCase {
    static let protectedBranchNames = ["main", "master"]

    static func protectedBranchesPresent(in snapshot: GitRepositorySnapshot?) -> [String] {
        guard let snapshot else {
            return protectedBranchNames
        }

        var present = Set(snapshot.branches.map(\.name))

        if let currentBranch = snapshot.currentBranch {
            present.insert(currentBranch)
        }

        return protectedBranchNames.filter { present.contains($0) }
    }

    static func isSyncAllowed(branch: String, in repository: WorkspaceRepository) -> Bool {
        switch branch {
        case "main":
            repository.allowsMainBranchSync
        case "master":
            repository.allowsMasterBranchSync
        default:
            true
        }
    }

    static func setSyncAllowed(_ isAllowed: Bool, branch: String, in repository: inout WorkspaceRepository) {
        switch branch {
        case "main":
            repository.allowsMainBranchSync = isAllowed
        case "master":
            repository.allowsMasterBranchSync = isAllowed
        default:
            break
        }
    }

    static func blockedReason(branch: String?, repository: WorkspaceRepository) -> SyncFailure? {
        guard let branch else {
            return .detachedHead
        }

        switch branch {
        case "main" where repository.allowsMainBranchSync == false:
            return .branchNotAllowed(branch)
        case "master" where repository.allowsMasterBranchSync == false:
            return .branchNotAllowed(branch)
        default:
            return nil
        }
    }
}
