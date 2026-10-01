import Foundation

enum ResumeAction: Equatable {
    case clone(URL)
    case fastForward(Int)
    case checkoutHandoffBranch(String)
    case upToDate
    case blockedByLocalChanges(Int)
    case blockedByDivergence
    case handoffBranchMissing(String)
    case noWorkspaceRoot
    case noRemote
    case unreadable

    var isActionable: Bool {
        switch self {
        case .clone,
             .fastForward,
             .checkoutHandoffBranch:
            true
        case .upToDate,
             .blockedByLocalChanges,
             .blockedByDivergence,
             .handoffBranchMissing,
             .noWorkspaceRoot,
             .noRemote,
             .unreadable:
            false
        }
    }

    var isSafeFastForward: Bool {
        switch self {
        case .fastForward:
            true
        case .clone,
             .checkoutHandoffBranch,
             .upToDate,
             .blockedByLocalChanges,
             .blockedByDivergence,
             .handoffBranchMissing,
             .noWorkspaceRoot,
             .noRemote,
             .unreadable:
            false
        }
    }

    var summary: String {
        switch self {
        case let .clone(destination):
            String(localized: "Clone into \(destination.path(percentEncoded: false))")
        case let .fastForward(count):
            String(localized: "Fast-forward \(count) commit(s) from the remote")
        case let .checkoutHandoffBranch(branch):
            String(localized: "Check out \(branch), the branch used on the previous Mac")
        case .upToDate:
            String(localized: "Already up to date")
        case let .blockedByLocalChanges(count):
            String(localized: "\(count) local change(s) would be affected. Review them first.")
        case .blockedByDivergence:
            String(localized: "The branch has diverged from its remote. Resolve it by hand.")
        case let .handoffBranchMissing(branch):
            String(localized: "The branch \(branch) used on the previous Mac is not here yet. Fetch and try again.")
        case .noWorkspaceRoot:
            String(localized: "Set this Mac's workspace root before cloning")
        case .noRemote:
            String(localized: "There is no remote to clone or fetch from")
        case .unreadable:
            String(localized: "The repository could not be read")
        }
    }
}
