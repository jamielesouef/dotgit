import SwiftUI

struct LinkedWorktreesView: View {
    // MARK: - Inputs

    let worktrees: [TrackedRepository]

    // MARK: - View

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(worktrees) { worktree in
                WorktreeRowView(worktree: worktree, isLast: worktree.id == worktrees.last?.id)
            }
        }
        .padding(.leading, AppSpacing.xsmall)
        .padding(.top, AppSpacing.xsmall)
    }
}

#if DEBUG
    #Preview("Two worktrees") {
        LinkedWorktreesView(
            worktrees: [
                PreviewGraph.worktree("feature+login", branch: "feature/login", dirty: true),
                PreviewGraph.worktree("hotfix", branch: "hotfix/crash")
            ]
        )
        .padding(AppSpacing.regular)
        .frame(width: 360)
    }

    #Preview("None") {
        LinkedWorktreesView(worktrees: [])
            .padding(AppSpacing.regular)
    }
#endif
