import Foundation

struct RepositorySyncEngine: RepositorySyncPerforming {
    // MARK: - Private

    private let gitClient: any GitClienting
    private let gitHubClient: any GitHubCLIClienting
    private let pushFallback: any PushFallbackPerforming

    // MARK: - Init

    init(
        gitClient: any GitClienting,
        gitHubClient: any GitHubCLIClienting,
        pushFallback: any PushFallbackPerforming
    ) {
        self.gitClient = gitClient
        self.gitHubClient = gitHubClient
        self.pushFallback = pushFallback
    }

    // MARK: - RepositorySyncPerforming

    func sync(_ request: RepositorySyncRequest) async -> RepositorySyncReport {
        let report = await syncCurrentBranch(request)

        return await pushAdditionalBranches(request, after: report)
    }

    // MARK: - Helpers

    private enum CommitOutcome {
        case committed
        case nothingStaged
        case failed(SyncFailure)
    }

    private func syncCurrentBranch(_ request: RepositorySyncRequest) async -> RepositorySyncReport {
        if let denial = await accessDenial(for: request) {
            return report(request, result: .failed(denial), committed: false)
        }

        guard request.willCommit else {
            return await push(request, committed: false)
        }

        switch await commit(request) {
        case .committed:
            return await push(request, committed: true)
        case .nothingStaged:
            return await push(request, committed: false)
        case let .failed(failure):
            return report(request, result: .failed(failure), committed: false)
        }
    }

    /// Branches that are not checked out go up as they are, once the current one is
    /// safely pushed. Their failures skip `handle(_:)`: the protected-branch fallback
    /// checks out a new branch, which is wrong for a branch nobody is on.
    private func pushAdditionalBranches(
        _ request: RepositorySyncRequest,
        after report: RepositorySyncReport
    ) async -> RepositorySyncReport {
        guard case .succeeded = report.result, request.additionalBranches.isEmpty == false else {
            return report
        }

        var failed: [String] = []

        for branch in request.additionalBranches {
            guard Task.isCancelled == false else {
                failed.append(branch.name)
                continue
            }

            if await push(branch, request: request) == false {
                failed.append(branch.name)
            }
        }

        guard failed.isEmpty == false else {
            return report
        }

        return RepositorySyncReport(
            identifier: report.identifier,
            branch: report.branch,
            result: .failed(.branchesNotPushed(failed)),
            fallback: report.fallback,
            committed: report.committed
        )
    }

    private func push(_ branch: GitBranchRef, request: RepositorySyncRequest) async -> Bool {
        do {
            try await gitClient.push(
                branch: branch.name,
                remote: request.remote,
                setUpstream: branch.isLocalOnly,
                at: request.directory
            )
        } catch {
            AppLog.error("Could not push \(branch.name) on \(request.identifier): \(String(describing: error))")

            guard case .authenticationFailed = error, request.fallbackEnabled else {
                return false
            }

            // The fallback restores the original account after each retry, so every
            // branch that needed it has to go through it again.
            let context = PushAttemptContext(
                directory: request.directory,
                branch: branch.name,
                remote: request.remote,
                remoteURL: request.remoteURL,
                setsUpstream: branch.isLocalOnly,
                preferredAccount: request.preferredAccount
            )

            switch await pushFallback.retryPush(context) {
            case .succeeded:
                return true
            case .notApplicable,
                 .exhausted:
                return false
            }
        }

        return true
    }

    private func accessDenial(for request: RepositorySyncRequest) async -> SyncFailure? {
        guard request.checksAccountAccess, let remoteURL = request.remoteURL else {
            return nil
        }
        guard AccountFallbackUseCase.appliesToRemote(remoteURL), await gitHubClient.isAvailable() else {
            return nil
        }
        guard await gitHubClient.hasAccess(toRemoteURL: remoteURL) == false else {
            return nil
        }

        let accounts = try? await gitHubClient.accounts()
        let active = accounts.flatMap { AccountFallbackUseCase.accountToRestore(from: $0) }

        return .accountAccessDenied(active ?? request.preferredAccount ?? remoteURL)
    }

    private func commit(_ request: RepositorySyncRequest) async -> CommitOutcome {
        do {
            try await gitClient.stageTrackedChanges(at: request.directory)
            try await gitClient.stage(paths: request.untrackedPathsToInclude, at: request.directory)
            try await gitClient.commit(message: request.commitMessage, at: request.directory)
        } catch {
            guard error != .nothingToCommit else {
                return .nothingStaged
            }

            return .failed(.git(String(describing: error)))
        }

        return .committed
    }

    private func push(_ request: RepositorySyncRequest, committed: Bool) async -> RepositorySyncReport {
        do {
            try await gitClient.push(
                branch: request.branch,
                remote: request.remote,
                setUpstream: request.setsUpstream,
                at: request.directory
            )
        } catch {
            return await handle(error, request: request, committed: committed)
        }

        return await report(
            request,
            result: .succeeded(commit: headCommit(request), branch: request.branch),
            committed: committed
        )
    }

    private func handle(
        _ error: GitError,
        request: RepositorySyncRequest,
        committed: Bool
    ) async -> RepositorySyncReport {
        switch error {
        case let .authenticationFailed(detail):
            await retryWithFallback(request, committed: committed, detail: detail)
        case .branchProtected:
            await pushToFallbackBranch(request, committed: committed)
        case .diverged:
            report(request, result: .failed(.diverged), committed: committed)
        case .noRemoteConfigured:
            report(request, result: .failed(.noRemote), committed: committed)
        case .noUpstreamConfigured:
            report(request, result: .failed(.noUpstream), committed: committed)
        case .gitUnavailable,
             .notARepository,
             .commandFailed,
             .nothingToCommit,
             .cancelled:
            report(request, result: .failed(.git(String(describing: error))), committed: committed)
        }
    }

    /// The remote refused the branch itself, so the work goes up on a new branch
    /// instead. Switching to it locally means the next sync follows it too.
    private func pushToFallbackBranch(_ request: RepositorySyncRequest, committed: Bool) async -> RepositorySyncReport {
        let fallback = request.protectedBranchFallback

        do {
            try await gitClient.createBranch(fallback, at: request.directory)
            try await gitClient.push(branch: fallback, remote: request.remote, setUpstream: true, at: request.directory)
        } catch {
            let failure = SyncFailure.protectedBranchFallbackFailed(
                branch: request.branch,
                fallback: fallback,
                detail: String(describing: error)
            )

            return report(request, result: .failed(failure), committed: committed)
        }

        AppLog.info("\(request.branch) is protected on \(request.identifier), pushed \(fallback) instead")

        return await report(
            request,
            branch: fallback,
            result: .succeeded(commit: headCommit(request), branch: fallback),
            committed: committed
        )
    }

    private func retryWithFallback(
        _ request: RepositorySyncRequest,
        committed: Bool,
        detail: String
    ) async -> RepositorySyncReport {
        guard request.fallbackEnabled else {
            return report(request, result: .failed(.authentication(detail)), committed: committed)
        }

        let context = PushAttemptContext(
            directory: request.directory,
            branch: request.branch,
            remote: request.remote,
            remoteURL: request.remoteURL,
            setsUpstream: request.setsUpstream,
            preferredAccount: request.preferredAccount
        )

        let fallback = await pushFallback.retryPush(context)

        switch fallback {
        case let .succeeded(account, _):
            AppLog.info("Pushed \(request.identifier) using the GitHub account \(account)")
            return await report(
                request,
                result: .succeeded(commit: headCommit(request), branch: request.branch),
                committed: committed,
                fallback: fallback
            )
        case .notApplicable,
             .exhausted:
            return report(request, result: .failed(.authentication(detail)), committed: committed, fallback: fallback)
        }
    }

    private func headCommit(_ request: RepositorySyncRequest) async -> String? {
        try? await gitClient.headCommit(at: request.directory)
    }

    private func report(
        _ request: RepositorySyncRequest,
        branch: String? = nil,
        result: RepositorySyncOutcome.Result,
        committed: Bool,
        fallback: AccountFallbackResult? = nil
    ) -> RepositorySyncReport {
        RepositorySyncReport(
            identifier: request.identifier,
            branch: branch ?? request.branch,
            result: result,
            fallback: fallback,
            committed: committed
        )
    }
}
