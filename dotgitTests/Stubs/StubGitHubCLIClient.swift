import Foundation
@testable import dotgit

actor StubGitHubCLIClient: GitHubCLIClienting {
    // MARK: - Configuration

    var available = true
    var storedAccounts: [GitHubAccount] = []
    var accountsError: GitHubCLIError?
    var switchFailures: Set<String> = []
    var accessibleRemotes: Set<String> = []
    var signInError: GitHubCLIError?

    // MARK: - Accounts gate

    private var isHoldingAccounts = false
    private var heldAccounts: [CheckedContinuation<Void, Never>] = []
    private var awaitingAccountsRequest: CheckedContinuation<Void, Never>?
    private var hasRequestedAccounts = false

    func holdAccounts() {
        isHoldingAccounts = true
    }

    func releaseAccounts() {
        isHoldingAccounts = false
        heldAccounts.forEach { $0.resume() }
        heldAccounts = []
    }

    func waitUntilAccountsRequested() async {
        guard hasRequestedAccounts == false else {
            return
        }

        await withCheckedContinuation { continuation in
            awaitingAccountsRequest = continuation
        }
    }

    // MARK: - Recording

    private(set) var switchedAccounts: [String] = []
    private(set) var accessChecks: [String] = []
    private(set) var signInCount = 0

    // MARK: - Configuration helpers

    func setAccounts(_ accounts: [GitHubAccount]) {
        storedAccounts = accounts
    }

    func setAccountsError(_ error: GitHubCLIError?) {
        accountsError = error
    }

    func setAvailable(_ available: Bool) {
        self.available = available
    }

    func setSwitchFailures(_ failures: Set<String>) {
        switchFailures = failures
    }

    func setAccessibleRemotes(_ remotes: Set<String>) {
        accessibleRemotes = remotes
    }

    // MARK: - GitHubCLIClienting

    func isAvailable() async -> Bool {
        available
    }

    func accounts() async throws(GitHubCLIError) -> [GitHubAccount] {
        hasRequestedAccounts = true
        awaitingAccountsRequest?.resume()
        awaitingAccountsRequest = nil

        if isHoldingAccounts {
            await withCheckedContinuation { continuation in
                heldAccounts.append(continuation)
            }
        }

        if let accountsError {
            throw accountsError
        }

        return storedAccounts
    }

    func switchAccount(to login: String, host: String) async throws(GitHubCLIError) {
        switchedAccounts.append(login)

        guard switchFailures.contains(login) == false else {
            throw .switchFailed(login)
        }

        storedAccounts = storedAccounts.map {
            GitHubAccount(login: $0.login, host: $0.host, isActive: $0.login == login)
        }
    }

    func hasAccess(toRemoteURL remoteURL: String) async -> Bool {
        accessChecks.append(remoteURL)

        return accessibleRemotes.contains(remoteURL)
    }

    func beginInteractiveSignIn() async throws(GitHubCLIError) {
        signInCount += 1

        if let signInError {
            throw signInError
        }
    }
}
