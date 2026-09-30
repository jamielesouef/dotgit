import Foundation

struct SyncPlan: Equatable {
    let steps: [SyncPlanStep]

    static let empty = SyncPlan(steps: [])

    var actionableSteps: [SyncPlanStep] {
        steps.filter(\.isActionable)
    }

    var blockedSteps: [SyncPlanStep] {
        steps.filter { step in
            switch step.action {
            case .blocked:
                true
            case .commitAndPush,
                 .nothingToDo:
                false
            }
        }
    }

    var hasUntrackedFiles: Bool {
        steps.contains(where: \.hasUntrackedFiles)
    }

    var includesAllUntracked: Bool {
        hasUntrackedFiles && steps.filter(\.hasUntrackedFiles).allSatisfy(\.includesAllUntracked)
    }

    /// Every branch the sync would create on the remote, as "repository: branch".
    var newUpstreamBranches: [String] {
        actionableSteps.flatMap { step in
            step.newUpstreamBranches.map { "\(step.displayName): \($0)" }
        }
    }

    var isEmpty: Bool {
        actionableSteps.isEmpty
    }
}
