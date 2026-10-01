import Foundation

@MainActor
@Observable
final class OnboardingService: SingleFlightRefreshing {
    // MARK: - State

    enum LoadState: Equatable {
        case checking([StartupStep])
        case blocked([OnboardingRequirement])
        case optional([OnboardingRequirement])
        case ready
    }

    var loadState: LoadState {
        switch (isChecking, requirements.filter(\.isBlocking).isEmpty, requirements.isEmpty) {
        case (true, _, _):
            .checking(startupSteps)
        case (false, false, _):
            .blocked(requirements)
        case (false, true, false):
            .optional(requirements)
        case (false, true, true):
            .ready
        }
    }

    private(set) var availability: ToolAvailability = .unknown
    private(set) var signInError: GitHubCLIError?

    var capabilities: Set<AppCapability> {
        OnboardingRequirementUseCase.capabilities(for: availability)
    }

    var showsOnboarding: Bool {
        isChecking == false
            && OnboardingRequirementUseCase.canSkipOnboarding(
                availability: availability,
                hasCompletedOnboarding: settings.localSettings.hasCompletedOnboarding
            ) == false
    }

    // MARK: - SingleFlightRefreshing

    var refreshTask: Task<Void, Never>?

    // MARK: - Private

    private let gitClient: any GitClienting
    private let gitHubClient: any GitHubCLIClienting
    private let settings: SettingsService

    private var isChecking = true
    private var startupSteps = StartupProgressUseCase.waitingSteps()
    private var requirements: [OnboardingRequirement] = []
    private var hasStarted = false

    // MARK: - Init

    init(gitClient: any GitClienting, gitHubClient: any GitHubCLIClienting, settings: SettingsService) {
        self.gitClient = gitClient
        self.gitHubClient = gitHubClient
        self.settings = settings
    }

    // MARK: - Intent

    func start() async {
        guard hasStarted == false else {
            return
        }

        hasStarted = true
        await refresh()
    }

    func signIn() async {
        signInError = nil

        do {
            try await gitHubClient.beginInteractiveSignIn()
        } catch {
            signInError = error
        }
    }

    func markCompleted() {
        settings.updateLocalSettings { $0.hasCompletedOnboarding = true }
    }

    // MARK: - SingleFlightRefreshing

    func performRefresh() async {
        isChecking = true
        startupSteps = StartupProgressUseCase.waitingSteps()

        async let isGitAvailable = checkGit()
        async let gitHub = checkGitHub()

        let (isGitHubCLIAvailable, accounts) = await gitHub
        let isGitAvailableResult = await isGitAvailable

        guard Task.isCancelled == false else {
            return
        }

        availability = ToolAvailability(
            isGitAvailable: isGitAvailableResult,
            isGitHubCLIAvailable: isGitHubCLIAvailable,
            gitHubAccounts: accounts
        )
        requirements = OnboardingRequirementUseCase.requirements(for: availability)
        isChecking = false
    }

    // MARK: - Startup checks

    private func checkGit() async -> Bool {
        show(StartupProgressUseCase.running(.git))

        let isAvailable = await gitClient.isAvailable()

        guard Task.isCancelled == false else {
            return isAvailable
        }

        show(StartupProgressUseCase.gitChecked(isAvailable: isAvailable))

        return isAvailable
    }

    private func checkGitHub() async -> (isAvailable: Bool, accounts: [GitHubAccount]) {
        show(StartupProgressUseCase.running(.gitHubCLI))

        let isAvailable = await gitHubClient.isAvailable()

        guard Task.isCancelled == false else {
            return (isAvailable, [])
        }

        show(StartupProgressUseCase.gitHubCLIChecked(isAvailable: isAvailable))

        guard isAvailable else {
            show(StartupProgressUseCase.gitHubAccountsChecked(isGitHubCLIAvailable: false, accounts: []))
            return (false, [])
        }

        show(StartupProgressUseCase.running(.gitHubAccounts))

        let accounts = await (try? gitHubClient.accounts()) ?? []

        guard Task.isCancelled == false else {
            return (true, accounts)
        }

        show(StartupProgressUseCase.gitHubAccountsChecked(isGitHubCLIAvailable: true, accounts: accounts))

        return (true, accounts)
    }

    private func show(_ step: StartupStep) {
        startupSteps = StartupProgressUseCase.replacing(step, in: startupSteps)
    }
}
