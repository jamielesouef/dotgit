import Foundation

struct ResumePlan: Equatable {
    var steps: [ResumeStep]

    static let empty = ResumePlan(steps: [])

    var selectedSteps: [ResumeStep] {
        steps.filter { $0.isSelected && $0.action.isActionable }
    }

    var blockedSteps: [ResumeStep] {
        steps.filter { step in
            switch step.action {
            case .blockedByLocalChanges,
                 .blockedByDivergence,
                 .handoffBranchMissing,
                 .noWorkspaceRoot,
                 .noRemote,
                 .unreadable:
                true
            case .clone,
                 .fastForward,
                 .checkoutHandoffBranch,
                 .upToDate:
                false
            }
        }
    }

    var isEmpty: Bool {
        selectedSteps.isEmpty
    }

    mutating func setSelection(_ isSelected: Bool, for identifier: String) {
        guard let index = steps.firstIndex(where: { $0.identifier == identifier }) else {
            return
        }

        steps[index].isSelected = isSelected
    }
}
