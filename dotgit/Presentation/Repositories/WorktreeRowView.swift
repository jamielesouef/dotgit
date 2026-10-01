import SwiftUI

struct WorktreeRowView: View {
    // MARK: - Constants

    private enum Constants {
        static let connectorWidth: CGFloat = 10
        static let connectorLineWidth: CGFloat = 1
    }

    // MARK: - Inputs

    let worktree: TrackedRepository
    let isLast: Bool

    // MARK: - View

    var body: some View {
        HStack(alignment: .top, spacing: AppSpacing.xsmall) {
            WorktreeConnector(isLast: isLast)
                .stroke(.tertiary, lineWidth: Constants.connectorLineWidth)
                .frame(width: Constants.connectorWidth)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: AppSpacing.small) {
                    WorktreeLabel(name: worktree.worktree?.name ?? worktree.name)
                        .font(.caption.weight(.medium))
                        .layoutPriority(1)

                    RepositoryStatusBadge(status: worktree.status)

                    if let branch = worktree.currentBranchName {
                        Text(branch)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }

                if let changes = changeDescription {
                    Text(changes)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.bottom, isLast ? 0 : AppSpacing.xsmall)
        }
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Helpers

    private var changeDescription: String? {
        guard let workingTree = worktree.snapshot?.workingTree, workingTree.isClean == false else {
            return nil
        }

        return String(
            localized: "\(workingTree.trackedChanges.count) changed, \(workingTree.untrackedPaths.count) untracked"
        )
    }
}

#if DEBUG
    #Preview("Dirty, clean and unreadable") {
        VStack(alignment: .leading, spacing: 0) {
            WorktreeRowView(
                worktree: PreviewGraph.worktree("feature+login", branch: "feature/login", dirty: true),
                isLast: false
            )
            WorktreeRowView(worktree: PreviewGraph.worktree("hotfix", branch: "hotfix/crash"), isLast: false)
            WorktreeRowView(worktree: PreviewGraph.worktree("gone", branch: nil, readable: false), isLast: true)
        }
        .padding(AppSpacing.regular)
        .frame(width: 360)
    }

    #Preview("Long names") {
        WorktreeRowView(
            worktree: PreviewGraph.worktree(
                "an-extremely-long-worktree-folder-name-from-an-agent",
                branch: "feature/NAT-2938-add-viewer-count-live-badge-to-the-player",
                dirty: true
            ),
            isLast: true
        )
        .padding(AppSpacing.regular)
        .frame(width: 320)
    }
#endif
