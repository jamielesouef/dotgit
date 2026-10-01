import Foundation

enum ResumePlanUseCase {
    static func plan(
        for repositories: [TrackedRepository],
        workspaceRoot: URL?,
        preselectsSafeFastForward: Bool
    ) -> ResumePlan {
        ResumePlan(
            steps: repositories.map {
                step(for: $0, workspaceRoot: workspaceRoot, preselectsSafeFastForward: preselectsSafeFastForward)
            }
        )
    }

    static func step(
        for repository: TrackedRepository,
        workspaceRoot: URL?,
        preselectsSafeFastForward: Bool
    ) -> ResumeStep {
        let action = action(for: repository, workspaceRoot: workspaceRoot)

        return ResumeStep(
            identifier: repository.id,
            name: repository.name,
            action: action,
            handoff: repository.shared.handoff,
            isSelected: isPreselected(action, preselectsSafeFastForward: preselectsSafeFastForward)
        )
    }

    static func isPreselected(_ action: ResumeAction, preselectsSafeFastForward: Bool) -> Bool {
        guard action.isSafeFastForward == false else {
            return preselectsSafeFastForward
        }

        return action.isActionable
    }

    // MARK: - Helpers

    private static func action(for repository: TrackedRepository, workspaceRoot: URL?) -> ResumeAction {
        guard repository.isCloned else {
            return cloneAction(for: repository, workspaceRoot: workspaceRoot)
        }
        guard repository.readError == nil, let snapshot = repository.snapshot else {
            return .unreadable
        }
        guard snapshot.isDirty == false else {
            return .blockedByLocalChanges(snapshot.workingTree.trackedChanges.count + snapshot.workingTree
                .untrackedPaths.count)
        }
        guard snapshot.isDiverged == false else {
            return .blockedByDivergence
        }

        if let handoffAction = handoffAction(for: repository, snapshot: snapshot) {
            return handoffAction
        }

        guard snapshot.behindCount == 0 else {
            return .fastForward(snapshot.behindCount)
        }

        return .upToDate
    }

    private static func cloneAction(for repository: TrackedRepository, workspaceRoot: URL?) -> ResumeAction {
        guard let remoteURL = repository.shared.remoteURL, remoteURL.isEmpty == false else {
            return .noRemote
        }
        guard let workspaceRoot else {
            return .noWorkspaceRoot
        }

        let entry = WorkspaceManifestEntry(repository.shared)

        return .clone(WorkspacePlanUseCase.destination(for: entry, workspaceRoot: workspaceRoot))
    }

    private static func handoffAction(
        for repository: TrackedRepository,
        snapshot: GitRepositorySnapshot
    ) -> ResumeAction? {
        guard let handoff = repository.shared.handoff, handoff.branch != snapshot.currentBranch else {
            return nil
        }
        guard snapshot.branches.contains(where: { $0.name == handoff.branch }) else {
            return .handoffBranchMissing(handoff.branch)
        }

        return .checkoutHandoffBranch(handoff.branch)
    }
}
