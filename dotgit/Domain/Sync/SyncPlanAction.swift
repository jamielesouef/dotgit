import Foundation

enum SyncPlanAction: Equatable {
    case commitAndPush(willCommit: Bool, setsUpstream: Bool)
    case nothingToDo
    case blocked(SyncFailure)

    var isActionable: Bool {
        switch self {
        case .commitAndPush:
            true
        case .nothingToDo,
             .blocked:
            false
        }
    }

    var summary: String {
        switch self {
        case .commitAndPush(true, true):
            String(localized: "Commit work in progress, then push and set the upstream")
        case .commitAndPush(true, false):
            String(localized: "Commit work in progress, then push")
        case .commitAndPush(false, true):
            String(localized: "Push and set the upstream")
        case .commitAndPush(false, false):
            String(localized: "Push the current branch")
        case .nothingToDo:
            String(localized: "Already up to date")
        case let .blocked(failure):
            failure.message
        }
    }
}
