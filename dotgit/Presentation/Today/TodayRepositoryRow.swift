import SwiftUI

struct TodayRepositoryRow: View {
    // MARK: - Inputs

    let repository: TrackedRepository
    let report: ReadinessReport?
    let syncAction: () -> Void

    // MARK: - View

    var body: some View {
        HStack(alignment: .top, spacing: AppSpacing.medium) {
            VStack(alignment: .leading, spacing: AppSpacing.xsmall) {
                Text(repository.name)
                    .font(.body.weight(.medium))
                    .lineLimit(2)

                HStack(spacing: AppSpacing.small) {
                    RepositoryStatusBadge(status: repository.status)

                    if let branch = repository.snapshot?.currentBranch {
                        Label(branch, systemImage: "arrow.triangle.branch")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                if repository.worktrees.isEmpty == false {
                    LinkedWorktreesView(worktrees: repository.worktrees)
                }

                if let report, report.isReadyToResume == false {
                    Text(String(localized: "\(report.issueCount) thing(s) would stop this continuing elsewhere."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: AppSpacing.small)

            Button(String(localized: "Sync"), action: syncAction)
                .disabled(repository.isCloned == false)
        }
        .padding(AppSpacing.medium)
        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: AppSpacing.small))
    }
}

#if DEBUG
    #Preview("Dirty with issues") {
        TodayRepositoryRow(
            repository: TrackedRepository(
                shared: PreviewGraph.sampleRepositories[0],
                localPath: URL(filePath: "/Users/preview/Developer/app"),
                snapshot: PreviewGraph.snapshot(branch: "feature/login", ahead: 3)
            ),
            report: ReadinessReport(
                identifier: "a",
                currentBranchPushed: false,
                issues: [.untrackedFiles(["Notes.md"])]
            ),
            syncAction: {}
        )
        .padding()
        .frame(width: 520)
    }

    #Preview("Clean, with a dirty worktree") {
        TodayRepositoryRow(repository: PreviewGraph.repositoryWithWorktrees, report: nil, syncAction: {})
            .padding()
            .frame(width: 520)
    }

    #Preview("Not cloned, long name") {
        TodayRepositoryRow(
            repository: TrackedRepository(
                shared: WorkspaceRepository(
                    identifier: "x",
                    name: "an-extremely-long-repository-name-that-wraps-onto-several-lines"
                )
            ),
            report: nil,
            syncAction: {}
        )
        .padding()
        .frame(width: 520)
    }
#endif
