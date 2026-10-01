import Foundation

enum ReadinessEvaluationUseCase {
    static func report(
        identifier: String,
        snapshot: GitRepositorySnapshot,
        repository: WorkspaceRepository,
        signals: ReadinessCheckSignals
    ) -> ReadinessReport {
        let issues = branchIssues(for: snapshot)
            + workingTreeIssues(for: snapshot)
            + outstandingBranchIssues(for: snapshot)
            + handoffReadinessIssues(snapshot: snapshot, repository: repository, signals: signals)

        return ReadinessReport(
            identifier: identifier,
            currentBranchPushed: snapshot.isDiverged == false && snapshot.aheadCount == 0 && snapshot
                .isDetached == false,
            issues: issues
        )
    }

    // MARK: - Private

    private static func branchIssues(for snapshot: GitRepositorySnapshot) -> [ReadinessIssue] {
        var issues: [ReadinessIssue] = []

        if snapshot.isDetached {
            issues.append(.detachedHead)
        }

        if snapshot.hasRemote == false {
            issues.append(.noRemote)
        }

        if snapshot.isDiverged {
            issues.append(.divergedBranch)
        } else if snapshot.aheadCount > 0 {
            issues.append(.currentBranchNotPushed(snapshot.aheadCount))
        }

        return issues
    }

    private static func workingTreeIssues(for snapshot: GitRepositorySnapshot) -> [ReadinessIssue] {
        var issues: [ReadinessIssue] = []

        if snapshot.workingTree.trackedChanges.isEmpty == false {
            issues.append(.uncommittedChanges(snapshot.workingTree.trackedChanges.count))
        }

        if snapshot.workingTree.untrackedPaths.isEmpty == false {
            issues.append(.untrackedFiles(snapshot.workingTree.untrackedPaths))
        }

        return issues
    }

    private static func outstandingBranchIssues(for snapshot: GitRepositorySnapshot) -> [ReadinessIssue] {
        var issues: [ReadinessIssue] = []
        let outstanding = snapshot.otherBranchesNeedingPush
        let localOnly = outstanding.filter(\.isLocalOnly).map(\.name)
        let unpushed = outstanding.filter { $0.isLocalOnly == false && $0.hasUnpushedCommits }.map(\.name)

        if localOnly.isEmpty == false {
            issues.append(.localOnlyBranches(localOnly))
        }

        if unpushed.isEmpty == false {
            issues.append(.unpushedBranchCommits(unpushed))
        }

        return issues
    }

    private static func handoffReadinessIssues(
        snapshot: GitRepositorySnapshot,
        repository: WorkspaceRepository,
        signals: ReadinessCheckSignals
    ) -> [ReadinessIssue] {
        var issues: [ReadinessIssue] = []

        if signals.unpushedTags.isEmpty == false {
            issues.append(.unpushedTags(signals.unpushedTags))
        }

        if snapshot.submoduleChanges.isEmpty == false {
            issues.append(.submoduleChanges(snapshot.submoduleChanges.map(\.path)))
        }

        if signals.hasSetupInstructions == false {
            issues.append(.missingSetupInstructions)
        }

        if signals.missingConfigurationTemplates.isEmpty == false {
            issues.append(.missingConfigurationTemplates(signals.missingConfigurationTemplates))
        }

        if repository.requiredEnvironmentVariableNames.isEmpty == false {
            issues.append(.requiredEnvironmentVariables(repository.requiredEnvironmentVariableNames))
        }

        return issues
    }
}
