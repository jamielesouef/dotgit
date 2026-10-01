import SwiftUI

struct RepositoryRowView: View {
    // MARK: - Inputs

    let repository: TrackedRepository

    // MARK: - View

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xsmall) {
            Text(repository.name)
                .font(.body.weight(.medium))
                .lineLimit(1)
                .truncationMode(.middle)

            HStack(spacing: AppSpacing.small) {
                RepositoryStatusBadge(status: repository.status)

                if let branch = repository.snapshot?.currentBranch {
                    Text(branch)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            if let changes = changeDescription {
                Text(changes)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let counts = divergenceDescription {
                Text(counts)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if repository.worktrees.isEmpty == false {
                LinkedWorktreesView(worktrees: repository.worktrees)
            }
        }
        .padding(.vertical, AppSpacing.xsmall)
    }

    // MARK: - Helpers

    private var changeDescription: String? {
        guard let workingTree = repository.snapshot?.workingTree, workingTree.isClean == false else {
            return nil
        }

        return String(
            localized: "\(workingTree.trackedChanges.count) changed, \(workingTree.untrackedPaths.count) untracked"
        )
    }

    private var divergenceDescription: String? {
        guard let snapshot = repository.snapshot, snapshot.aheadCount > 0 || snapshot.behindCount > 0 else {
            return nil
        }

        return String(localized: "\(snapshot.aheadCount) ahead, \(snapshot.behindCount) behind")
    }
}

#if DEBUG
    #Preview("Statuses") {
        List {
            RepositoryRowView(
                repository: TrackedRepository(
                    shared: PreviewGraph.sampleRepositories[0],
                    localPath: URL(filePath: "/dev/app"),
                    snapshot: PreviewGraph.snapshot(branch: "feature/login", ahead: 3, behind: 1)
                )
            )
            RepositoryRowView(
                repository: TrackedRepository(
                    shared: PreviewGraph.sampleRepositories[1],
                    localPath: URL(filePath: "/dev/tooling"),
                    snapshot: PreviewGraph.snapshot(branch: "main")
                )
            )
            RepositoryRowView(repository: TrackedRepository(shared: PreviewGraph.sampleRepositories[2]))
        }
        .frame(width: 320, height: 240)
    }

    #Preview("With worktrees") {
        List {
            RepositoryRowView(repository: PreviewGraph.repositoryWithWorktrees)
        }
        .frame(width: 340, height: 180)
    }

    #Preview("Still being read") {
        List {
            RepositoryRowView(
                repository: TrackedRepository(
                    shared: PreviewGraph.sampleRepositories[0],
                    localPath: URL(filePath: "/dev/app"),
                    isLoadingSnapshot: true
                )
            )
        }
        .frame(width: 320, height: 100)
    }

    #Preview("Long name") {
        List {
            RepositoryRowView(
                repository: TrackedRepository(
                    shared: WorkspaceRepository(
                        identifier: "x",
                        name: "an-extremely-long-repository-name-that-will-not-fit-in-the-sidebar"
                    ),
                    localPath: URL(filePath: "/dev/long"),
                    snapshot: PreviewGraph.snapshot(branch: "feature/a-very-long-branch-name", ahead: 12)
                )
            )
        }
        .frame(width: 320, height: 140)
    }
#endif
