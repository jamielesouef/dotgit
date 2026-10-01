import Foundation

@MainActor
@Observable
final class ResumeService {
    // MARK: - State

    enum Phase: Equatable {
        case idle
        case reviewing(ResumePlan)
        case running(SyncProgress)
        case finished(ResumeSummary)
    }

    private(set) var phase: Phase = .idle

    var reviewPlan: ResumePlan? {
        guard case let .reviewing(plan) = phase else {
            return nil
        }

        return plan
    }

    var offersToOpenProjects: Bool {
        settings.preferences.offersToOpenProjectAfterResume
    }

    // MARK: - Private

    private let gitClient: any GitClienting
    private let repositories: RepositoriesService
    private let settings: SettingsService
    private let projectOpener: any ProjectOpening

    private var runTask: Task<Void, Never>?

    // MARK: - Init

    init(
        gitClient: any GitClienting,
        repositories: RepositoriesService,
        settings: SettingsService,
        projectOpener: any ProjectOpening
    ) {
        self.gitClient = gitClient
        self.repositories = repositories
        self.settings = settings
        self.projectOpener = projectOpener
    }

    // MARK: - Intent

    func prepare() {
        phase = .reviewing(
            ResumePlanUseCase.plan(
                for: repositories.repositories,
                workspaceRoot: settings.localSettings.workspaceRoot,
                preselectsSafeFastForward: settings.preferences.preselectsSafeFastForward
            )
        )
    }

    func setSelection(_ isSelected: Bool, for identifier: String) {
        guard case let .reviewing(plan) = phase else {
            return
        }

        var updated = plan
        updated.setSelection(isSelected, for: identifier)

        guard updated != plan else {
            return
        }

        phase = .reviewing(updated)
    }

    func cancelReview() {
        phase = .idle
    }

    func dismissSummary() {
        phase = .idle
    }

    func run() async {
        guard case let .reviewing(plan) = phase else {
            return
        }

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

    func open(_ outcome: ResumeOutcome) async -> Bool {
        guard let url = outcome.openableURL else {
            return false
        }

        let applicationPath = settings.localSettings.preferredOpenApplicationPath

        return await projectOpener.open(url, withApplicationAt: applicationPath.map { URL(filePath: $0) })
    }

    // MARK: - Helpers

    private func execute(_ plan: ResumePlan) async {
        let steps = plan.selectedSteps
        var outcomes: [ResumeOutcome] = []

        phase = .running(SyncProgress(total: steps.count, completed: 0, currentRepositoryName: steps.first?.name))

        for (index, step) in steps.enumerated() {
            guard Task.isCancelled == false else {
                break
            }

            phase = .running(SyncProgress(total: steps.count, completed: index, currentRepositoryName: step.name))
            await outcomes.append(perform(step))
        }

        phase = .running(SyncProgress(total: steps.count, completed: steps.count, currentRepositoryName: nil))
        await repositories.refresh()
        phase = .finished(ResumeSummary(outcomes: outcomes))
    }

    private func perform(_ step: ResumeStep) async -> ResumeOutcome {
        switch step.action {
        case let .clone(destination):
            await clone(step, to: destination)
        case .fastForward:
            await fastForward(step)
        case let .checkoutHandoffBranch(branch):
            await checkout(step, branch: branch)
        case .upToDate,
             .blockedByLocalChanges,
             .blockedByDivergence,
             .handoffBranchMissing,
             .noWorkspaceRoot,
             .noRemote,
             .unreadable:
            ResumeOutcome(
                identifier: step.identifier,
                name: step.name,
                openableURL: nil,
                failureMessage: step.action.summary
            )
        }
    }

    private func clone(_ step: ResumeStep, to destination: URL) async -> ResumeOutcome {
        guard let repository = repositories.repository(identifier: step.identifier),
              let remoteURL = repository.shared.remoteURL
        else {
            return failure(step, message: SyncFailure.noRemote.message)
        }

        do {
            try await gitClient.clone(remoteURL: remoteURL, into: destination)
        } catch {
            return failure(step, message: String(describing: error))
        }

        settings.recordLocalPath(destination, for: step.identifier)

        guard let branch = step.handoff?.branch, await gitClient.branchExists(branch, at: destination) else {
            return ResumeOutcome(
                identifier: step.identifier,
                name: step.name,
                openableURL: destination,
                failureMessage: nil
            )
        }

        try? await gitClient.checkout(branch: branch, at: destination)

        return ResumeOutcome(
            identifier: step.identifier,
            name: step.name,
            openableURL: destination,
            failureMessage: nil
        )
    }

    private func fastForward(_ step: ResumeStep) async -> ResumeOutcome {
        guard let repository = repositories.repository(identifier: step.identifier),
              let directory = repository.localPath,
              let remote = repository.snapshot?.defaultRemoteName
        else {
            return failure(step, message: SyncFailure.notClonedLocally.message)
        }

        do {
            try await gitClient.fetch(remote: remote, at: directory)
            try await gitClient.fastForward(at: directory)
        } catch {
            return failure(step, message: String(describing: error))
        }

        return ResumeOutcome(identifier: step.identifier, name: step.name, openableURL: directory, failureMessage: nil)
    }

    private func checkout(_ step: ResumeStep, branch: String) async -> ResumeOutcome {
        guard let repository = repositories.repository(identifier: step.identifier),
              let directory = repository.localPath
        else {
            return failure(step, message: SyncFailure.notClonedLocally.message)
        }

        do {
            try await gitClient.checkout(branch: branch, at: directory)
        } catch {
            return failure(step, message: String(describing: error))
        }

        return ResumeOutcome(identifier: step.identifier, name: step.name, openableURL: directory, failureMessage: nil)
    }

    private func failure(_ step: ResumeStep, message: String) -> ResumeOutcome {
        ResumeOutcome(identifier: step.identifier, name: step.name, openableURL: nil, failureMessage: message)
    }
}
