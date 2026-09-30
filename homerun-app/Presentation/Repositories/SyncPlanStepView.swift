import SwiftUI

struct SyncPlanStepView: View {
    // MARK: - Inputs

    let step: SyncPlanStep
    let onUntrackedChange: (String, Bool) -> Void
    let onSelectAllUntracked: (Bool) -> Void

    // MARK: - View

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.small) {
            header
            trackedChanges
            untrackedFiles
            warnings
        }
        .padding(AppSpacing.medium)
        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: AppSpacing.small))
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xsmall) {
            HStack {
                Text(step.repositoryName)
                    .font(.headline)
                    .lineLimit(2)

                Spacer(minLength: AppSpacing.small)

                if let branch = step.branch {
                    Label(branch, systemImage: "arrow.triangle.branch")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            if let worktreeName = step.worktreeName {
                WorktreeLabel(name: worktreeName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(step.action.summary)
                .font(.callout)
                .foregroundStyle(step.isActionable ? Color.primary : Color.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Changes

    @ViewBuilder
    private var trackedChanges: some View {
        if step.trackedChanges.isEmpty == false {
            VStack(alignment: .leading, spacing: AppSpacing.xsmall) {
                Text(String(localized: "Tracked changes, included automatically"))
                    .font(.caption.weight(.semibold))

                ForEach(step.trackedChanges) { change in
                    Label("\(change.status.rawValue): \(change.path)", systemImage: "doc.text")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
        }
    }

    @ViewBuilder
    private var untrackedFiles: some View {
        if step.selectableUntrackedPaths.isEmpty == false {
            VStack(alignment: .leading, spacing: AppSpacing.xsmall) {
                HStack {
                    Text(String(localized: "Untracked files, only if you pick them"))
                        .font(.caption.weight(.semibold))

                    Spacer(minLength: AppSpacing.small)

                    Button(UntrackedSelectionUseCase
                        .stepSelectAllTitle(isEverythingSelected: step.includesAllUntracked)) {
                            onSelectAllUntracked(step.includesAllUntracked == false)
                        }
                        .buttonStyle(.link)
                        .font(.caption)
                }

                ForEach(step.selectableUntrackedPaths, id: \.self) { path in
                    UntrackedPathToggle(
                        path: path,
                        isSelected: step.includedUntrackedPaths.contains(path)
                    ) { isSelected in
                        onUntrackedChange(path, isSelected)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var warnings: some View {
        if step.isActionable, step.branchesToPush.isEmpty == false {
            Label(
                String(localized: "Also pushes: \(step.branchesToPush.map(\.name).joined(separator: ", "))"),
                systemImage: "arrow.up.circle"
            )
            .font(.caption)
            .foregroundStyle(.secondary)
        }

        if step.isActionable, step.newUpstreamBranches.isEmpty == false {
            Label(
                String(localized: "New on the remote: \(step.newUpstreamBranches.joined(separator: ", "))"),
                systemImage: "plus.circle"
            )
            .font(.caption)
            .foregroundStyle(.secondary)
        }

        if step.outstandingBranches.isEmpty == false {
            Label(
                String(
                    localized: "Other branches still unsynced: \(step.outstandingBranches.map(\.name).joined(separator: ", "))"
                ),
                systemImage: "arrow.triangle.branch"
            )
            .font(.caption)
            .foregroundStyle(.orange)
        }

        if step.submoduleChanges.isEmpty == false {
            Label(
                String(
                    localized: "Submodules need attention: \(step.submoduleChanges.map(\.path).joined(separator: ", "))"
                ),
                systemImage: "shippingbox"
            )
            .font(.caption)
            .foregroundStyle(.orange)
        }
    }
}

#if DEBUG
    #Preview("Commit and push") {
        SyncPlanStepView(
            step: SyncPlanStep(
                identifier: "a",
                repositoryName: "app",
                branch: "feature/login",
                action: .commitAndPush(willCommit: true, setsUpstream: false),
                trackedChanges: [
                    GitFileChange(path: "Sources/Login.swift", status: .modified),
                    GitFileChange(path: "Sources/Removed.swift", status: .deleted)
                ],
                selectableUntrackedPaths: ["Notes.md", "Scratch.swift"],
                includedUntrackedPaths: ["Notes.md"],
                outstandingBranches: [GitBranchRef(
                    name: "old-spike",
                    upstream: "origin/old-spike",
                    aheadCount: 2,
                    behindCount: 1
                )],
                submoduleChanges: [GitSubmoduleChange(path: "Vendor/Lib", kind: .commitDiffers)],
                branchesToPush: [
                    GitBranchRef(name: "spike", upstream: nil, aheadCount: 0, behindCount: 0),
                    GitBranchRef(
                        name: "feature/settings",
                        upstream: "origin/feature/settings",
                        aheadCount: 3,
                        behindCount: 0
                    )
                ]
            ),
            onUntrackedChange: { _, _ in },
            onSelectAllUntracked: { _ in }
        )
        .padding()
        .frame(width: 560)
    }

    #Preview("Every untracked file picked, long paths") {
        SyncPlanStepView(
            step: SyncPlanStep(
                identifier: "c",
                repositoryName: "app",
                branch: "feature/login",
                action: .commitAndPush(willCommit: true, setsUpstream: true),
                trackedChanges: [],
                selectableUntrackedPaths: [
                    "Sources/Features/Authentication/Presentation/AnExtremelyLongViewName.swift",
                    "Notes.md"
                ],
                includedUntrackedPaths: [
                    "Sources/Features/Authentication/Presentation/AnExtremelyLongViewName.swift",
                    "Notes.md"
                ],
                outstandingBranches: [],
                submoduleChanges: []
            ),
            onUntrackedChange: { _, _ in },
            onSelectAllUntracked: { _ in }
        )
        .padding()
        .frame(width: 560)
    }

    #Preview("Blocked") {
        SyncPlanStepView(
            step: SyncPlanStep(
                identifier: "b",
                repositoryName: "a-very-long-repository-name-that-needs-to-wrap-somewhere",
                branch: "main",
                action: .blocked(.branchNotAllowed("main")),
                trackedChanges: [],
                selectableUntrackedPaths: [],
                includedUntrackedPaths: [],
                outstandingBranches: [],
                submoduleChanges: []
            ),
            onUntrackedChange: { _, _ in },
            onSelectAllUntracked: { _ in }
        )
        .padding()
        .frame(width: 560)
    }
#endif
