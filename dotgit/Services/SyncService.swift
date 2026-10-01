import Foundation

@MainActor
@Observable
final class SyncService {
    // MARK: - State

    enum Phase: Equatable {
        case idle
        case reviewing(SyncPlan)
        case confirmingUpstreams(SyncPlan)
        case running(SyncProgress)
        case finished(SyncSummary)
    }

    private(set) var phase: Phase = .idle
    private(set) var untrackedSelections: [String: Set<String>] = [:]

    var reviewPlan: SyncPlan? {
        switch phase {
        case let .reviewing(plan),
             let .confirmingUpstreams(plan):
            plan
        case .idle,
             .running,
             .finished:
            nil
        }
    }

    var upstreamConfirmationPlan: SyncPlan? {
        guard case let .confirmingUpstreams(plan) = phase else {
            return nil
        }

        return plan
    }

    var isRunningOrFinished: Bool {
        switch phase {
        case .running,
             .finished:
            true
        case .idle,
             .reviewing,
             .confirmingUpstreams:
            false
        }
    }

    // MARK: - Private

    private let engine: any RepositorySyncPerforming
    private let repositories: RepositoriesService
    private let settings: SettingsService
    private let clock: any Clocking

    private var runTask: Task<Void, Never>?

    // MARK: - Init

    init(
        engine: any RepositorySyncPerforming,
        repositories: RepositoriesService,
        settings: SettingsService,
        clock: any Clocking
    ) {
        self.engine = engine
        self.repositories = repositories
        self.settings = settings
        self.clock = clock
    }

    // MARK: - Intent

    func review(identifiers: Set<String>?, includesWorktrees: Bool = true) async {
        let selected = WorktreeUseCase.checkoutsToSync(
            in: repositories.repositories,
            identifiers: identifiers,
            includesWorktrees: includesWorktrees
        )

        untrackedSelections = UntrackedSelectionUseCase.startingSelections(
            for: selected,
            existing: untrackedSelections,
            includesByDefault: settings.preferences.includesUntrackedFilesByDefault
        )

        let plan = SyncPlanUseCase.plan(for: selected, untrackedSelections: untrackedSelections)

        guard settings.preferences.requiresSyncConfirmation else {
            phase = .reviewing(plan)
            await run()
            return
        }

        phase = .reviewing(plan)
    }

    func setUntracked(_ path: String, isSelected: Bool, for identifier: String) {
        guard isUntrackedSelected(path, for: identifier) != isSelected else {
            return
        }

        var paths = untrackedSelections[identifier] ?? []

        if isSelected {
            paths.insert(path)
        } else {
            paths.remove(path)
        }

        untrackedSelections[identifier] = paths
        refreshReview()
    }

    func setAllUntracked(isSelected: Bool, for identifier: String? = nil) {
        guard let plan = reviewPlan else {
            return
        }

        let steps = plan.steps.filter { identifier == nil || $0.identifier == identifier }

        let selections = UntrackedSelectionUseCase.selectingAll(
            isSelected,
            in: steps,
            existing: untrackedSelections
        )

        guard selections != untrackedSelections else {
            return
        }

        untrackedSelections = selections
        refreshReview()
    }

    func isUntrackedSelected(_ path: String, for identifier: String) -> Bool {
        untrackedSelections[identifier]?.contains(path) == true
    }

    func cancelReview() {
        guard reviewPlan != nil else {
            return
        }

        phase = .idle
    }

    func cancelUpstreamConfirmation() {
        guard let plan = upstreamConfirmationPlan else {
            return
        }

        phase = .reviewing(plan)
    }

    /// Declining still pushes everything that already has an upstream. Branches that
    /// only exist on this Mac stay there, and are reported as not pushed.
    func confirmUpstreams(creates: Bool) async {
        guard let plan = upstreamConfirmationPlan else {
            return
        }

        await start(creates ? plan : replanned(plan, createsUpstreams: false))
    }

    func dismissSummary() {
        guard case .finished = phase else {
            return
        }

        phase = .idle
    }

    func cancelRun() {
        runTask?.cancel()
        runTask = nil
        phase = .idle
    }

    func run() async {
        guard case let .reviewing(plan) = phase else {
            return
        }

        // The gate lives here rather than in the review sheet, so it still fires
        // when confirmation is off and `review` runs straight through.
        guard settings.preferences.asksBeforeCreatingUpstream == false || plan.newUpstreamBranches.isEmpty else {
            phase = .confirmingUpstreams(plan)
            return
        }

        await start(plan)
    }

    // MARK: - Helpers

    private func start(_ plan: SyncPlan) async {
        runTask?.cancel()
        let task = Task { [weak self] in
            guard let self else {
                return
            }

            await execute(plan)
        }
        runTask = task
        await task.value
    }

    private func refreshReview() {
        guard case let .reviewing(plan) = phase else {
            return
        }

        phase = .reviewing(replanned(plan, createsUpstreams: true))
    }

    private func replanned(_ plan: SyncPlan, createsUpstreams: Bool) -> SyncPlan {
        let selected = repositories.allCheckouts.filter { repository in
            plan.steps.contains { $0.identifier == repository.id }
        }

        return SyncPlanUseCase.plan(
            for: selected,
            untrackedSelections: untrackedSelections,
            createsUpstreams: createsUpstreams
        )
    }

    private func execute(_ plan: SyncPlan) async {
        let steps = plan.actionableSteps
        var outcomes: [RepositorySyncOutcome] = plan.blockedSteps.map(blockedOutcome)

        phase = .running(SyncProgress(
            total: steps.count,
            completed: 0,
            currentRepositoryName: steps.first?.displayName
        ))

        for (index, step) in steps.enumerated() {
            guard Task.isCancelled == false else {
                break
            }

            phase = .running(SyncProgress(
                total: steps.count,
                completed: index,
                currentRepositoryName: step.displayName
            ))

            guard let request = request(for: step) else {
                outcomes.append(
                    RepositorySyncOutcome(
                        identifier: step.identifier,
                        result: .failed(.notClonedLocally),
                        finishedAt: clock.now()
                    )
                )
                continue
            }

            let report = await engine.sync(request)
            outcomes.append(report.outcome(finishedAt: clock.now()))
        }

        phase = .running(SyncProgress(total: steps.count, completed: steps.count, currentRepositoryName: nil))
        await repositories.apply(outcomes)
        phase = .finished(SyncSummary(outcomes: outcomes))
    }

    private func blockedOutcome(_ step: SyncPlanStep) -> RepositorySyncOutcome {
        guard case let .blocked(failure) = step.action else {
            return RepositorySyncOutcome(
                identifier: step.identifier,
                result: .skipped(String(localized: "Already up to date")),
                finishedAt: clock.now()
            )
        }

        return RepositorySyncOutcome(identifier: step.identifier, result: .failed(failure), finishedAt: clock.now())
    }

    private func request(for step: SyncPlanStep) -> RepositorySyncRequest? {
        guard case let .commitAndPush(willCommit, setsUpstream) = step.action,
              let repository = repositories.repository(identifier: step.identifier),
              let directory = repository.localPath,
              let branch = step.branch,
              let remote = repository.snapshot?.defaultRemoteName
        else {
            return nil
        }

        return RepositorySyncRequest(
            identifier: step.identifier,
            directory: directory,
            branch: branch,
            protectedBranchFallback: ProtectedBranchFallbackUseCase.branchName(
                for: branch,
                timestamp: clock.now(),
                timeZone: clock.timeZone
            ),
            remote: remote,
            remoteURL: repository.snapshot?.remoteURL,
            setsUpstream: setsUpstream,
            willCommit: willCommit,
            untrackedPathsToInclude: step.includedUntrackedPaths,
            commitMessage: WIPCommitMessageUseCase.message(
                repositoryOverride: repository.shared.wipCommitPrefixOverride,
                appWide: settings.preferences.wipCommitPrefix,
                timestamp: clock.now(),
                timeZone: clock.timeZone,
                appendsTimestamp: WIPCommitMessageUseCase.appendsTimestamp(
                    appWide: settings.preferences.appendsTimestampToWIPCommit,
                    repositoryOmits: repository.shared.omitsTimestampFromWIPCommit
                )
            ),
            preferredAccount: repository.shared.preferredGitHubAccount,
            checksAccountAccess: settings.preferences.accountAccessChecksEnabled,
            fallbackEnabled: settings.preferences.accountFallbackEnabled,
            additionalBranches: step.branchesToPush
        )
    }
}
