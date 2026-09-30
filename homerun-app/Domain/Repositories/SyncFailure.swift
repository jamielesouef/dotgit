import Foundation

enum SyncFailure: Error, Equatable {
    case authentication(String)
    case diverged
    case protectedBranchFallbackFailed(branch: String, fallback: String, detail: String)
    case noRemote
    case noUpstream
    case branchNotAllowed(String)
    case detachedHead
    case notClonedLocally
    case accountAccessDenied(String)
    case branchesNotPushed([String])
    case git(String)

    var message: String {
        switch self {
        case let .authentication(detail):
            String(localized: "Authentication failed: \(detail)")
        case .diverged:
            String(localized: "The branch has diverged from its remote. Resolve it by hand.")
        case let .protectedBranchFallbackFailed(branch, fallback, detail):
            String(
                localized: "The remote refuses pushes to \(branch), and pushing \(fallback) instead also failed: \(detail)"
            )
        case .noRemote:
            String(localized: "No push destination is configured.")
        case .noUpstream:
            String(localized: "The branch has no upstream yet.")
        case let .branchNotAllowed(branch):
            String(localized: "Syncing \(branch) is turned off for this repository.")
        case .detachedHead:
            String(localized: "HEAD is detached, so there is no branch to push.")
        case .notClonedLocally:
            String(localized: "This repository is not cloned on this Mac.")
        case let .accountAccessDenied(account):
            String(localized: "The account \(account) cannot reach this repository.")
        case let .branchesNotPushed(branches):
            String(
                localized: "The current branch was pushed, but these branches were not: \(branches.joined(separator: ", "))"
            )
        case let .git(detail):
            detail
        }
    }
}
