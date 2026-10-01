import Foundation

@MainActor
@Observable
final class GitHubAccountsService: SingleFlightRefreshing {
    // MARK: - State

    enum LoadState: Equatable {
        case loading
        case unavailable(GitHubCLIError)
        case empty
        case loaded([GitHubAccount])
    }

    var loadState: LoadState {
        switch (isLoading, error, accounts.isEmpty) {
        case (true, _, true):
            .loading
        case let (_, error?, _):
            .unavailable(error)
        case (_, nil, true):
            .empty
        case (_, nil, false):
            .loaded(accounts)
        }
    }

    private(set) var accounts: [GitHubAccount] = []
    private(set) var switchingAccount: String?
    private(set) var lastSwitchFailure: String?

    var activeAccount: GitHubAccount? {
        accounts.first(where: \.isActive)
    }

    // MARK: - SingleFlightRefreshing

    var refreshTask: Task<Void, Never>?

    // MARK: - Private

    private let client: any GitHubCLIClienting
    private let repositories: RepositoriesService
    private let settings: SettingsService

    private var isLoading = false
    private var error: GitHubCLIError?
    private var hasStarted = false

    // MARK: - Init

    init(client: any GitHubCLIClienting, repositories: RepositoriesService, settings: SettingsService) {
        self.client = client
        self.repositories = repositories
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

    func switchTo(_ account: GitHubAccount) async {
        switchingAccount = account.login
        lastSwitchFailure = nil

        do {
            try await client.switchAccount(to: account.login, host: account.host)
        } catch {
            lastSwitchFailure = error.message
        }

        switchingAccount = nil
        await refresh()
    }

    func associate(_ login: String?, with repository: TrackedRepository) {
        guard repository.shared.preferredGitHubAccount != login else {
            return
        }

        var shared = repository.shared
        shared.preferredGitHubAccount = login
        repositories.update(shared)
    }

    func inapplicabilityExplanation(for repository: TrackedRepository) -> String? {
        let remoteURL = repository.snapshot?.remoteURL ?? repository.shared.remoteURL

        guard AccountFallbackUseCase.appliesToRemote(remoteURL) == false else {
            return nil
        }

        return AccountFallbackUseCase.inapplicableExplanation(for: remoteURL)
    }

    func setFallbackEnabled(_ isEnabled: Bool) {
        settings.updatePreferences { $0.accountFallbackEnabled = isEnabled }
    }

    func setAccessChecksEnabled(_ isEnabled: Bool) {
        settings.updatePreferences { $0.accountAccessChecksEnabled = isEnabled }
    }

    // MARK: - SingleFlightRefreshing

    func performRefresh() async {
        isLoading = true
        error = nil

        guard await client.isAvailable() else {
            guard Task.isCancelled == false else {
                return
            }

            accounts = []
            error = .notInstalled
            isLoading = false
            return
        }

        let fetched: [GitHubAccount]

        do {
            fetched = try await client.accounts()
        } catch {
            guard Task.isCancelled == false else {
                return
            }

            accounts = []
            self.error = error
            isLoading = false
            return
        }

        guard Task.isCancelled == false else {
            return
        }

        accounts = fetched
        isLoading = false
    }
}
