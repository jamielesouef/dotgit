import Foundation

enum SyncPlanUseCase {
    static func plan(
        for repositories: [TrackedRepository],
        untrackedSelections: [String: Set<String>],
        createsUpstreams: Bool = true
    ) -> SyncPlan {
        SyncPlan(
            steps: repositories.map { repository in
                step(
                    for: repository,
                    includedUntrackedPaths: untrackedSelections[repository.id] ?? [],
                    createsUpstreams: createsUpstreams
                )
            }
        )
    }

    static func step(
        for repository: TrackedRepository,
        includedUntrackedPaths: Set<String>,
        createsUpstreams: Bool = true
    ) -> SyncPlanStep {
        let snapshot = repository.snapshot
        let untracked = snapshot?.workingTree.untrackedPaths ?? []
        let included = untracked.filter { includedUntrackedPaths.contains($0) }
        let otherBranches = snapshot?.otherBranchesNeedingPush ?? []

        let branchesToPush = otherBranches.filter { branch in
            isPushable(branch, in: repository.shared, createsUpstreams: createsUpstreams)
        }

        return SyncPlanStep(
            identifier: repository.id,
            repositoryName: repository.name,
            branch: snapshot?.currentBranch,
            action: action(
                for: repository,
                includedUntrackedCount: included.count,
                pushesOtherBranches: branchesToPush.isEmpty == false,
                createsUpstreams: createsUpstreams
            ),
            trackedChanges: snapshot?.workingTree.trackedChanges ?? [],
            selectableUntrackedPaths: untracked,
            includedUntrackedPaths: included,
            outstandingBranches: otherBranches.filter { branchesToPush.contains($0) == false },
            submoduleChanges: snapshot?.submoduleChanges ?? [],
            worktreeName: repository.worktree?.name,
            branchesToPush: branchesToPush
        )
    }

    // MARK: - Helpers

    /// A branch that is not checked out cannot take a WIP commit, so it goes up as
    /// it is. One that is behind its upstream would be refused, so it stays a warning.
    private static func isPushable(
        _ branch: GitBranchRef,
        in repository: WorkspaceRepository,
        createsUpstreams: Bool
    ) -> Bool {
        guard BranchSyncPolicyUseCase.isSyncAllowed(branch: branch.name, in: repository) else {
            return false
        }
        guard branch.isLocalOnly else {
            return branch.hasUnpushedCommits && branch.behindCount == 0
        }

        return createsUpstreams
    }

    private static func action(
        for repository: TrackedRepository,
        includedUntrackedCount: Int,
        pushesOtherBranches: Bool,
        createsUpstreams: Bool
    ) -> SyncPlanAction {
        guard repository.isCloned else {
            return .blocked(.notClonedLocally)
        }

        if let readError = repository.readError {
            return .blocked(.git(String(describing: readError)))
        }

        guard let snapshot = repository.snapshot else {
            return .blocked(.git(String(localized: "The repository could not be read.")))
        }

        if let reason = BranchSyncPolicyUseCase.blockedReason(
            branch: snapshot.currentBranch,
            repository: repository.shared
        ) {
            return .blocked(reason)
        }

        guard snapshot.hasRemote else {
            return .blocked(.noRemote)
        }
        guard snapshot.isDiverged == false else {
            return .blocked(.diverged)
        }

        let willCommit = snapshot.workingTree.hasTrackedChanges || includedUntrackedCount > 0
        let setsUpstream = snapshot.hasUpstream == false

        guard setsUpstream == false || createsUpstreams else {
            return .blocked(.noUpstream)
        }
        guard willCommit || setsUpstream || snapshot.aheadCount > 0 || pushesOtherBranches else {
            return .nothingToDo
        }

        return .commitAndPush(willCommit: willCommit, setsUpstream: setsUpstream)
    }
}
