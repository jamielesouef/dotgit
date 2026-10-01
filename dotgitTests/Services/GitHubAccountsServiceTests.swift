import Foundation
import Testing
@testable import dotgit

@Suite("GitHubAccountsService", .tags(.service))
struct GitHubAccountsServiceTests {
    // MARK: - Private

    private var accounts: [GitHubAccount] {
        [
            GitHubAccount(login: "jamie", host: "github.com", isActive: true),
            GitHubAccount(login: "acme-bot", host: "github.com", isActive: false)
        ]
    }

    // MARK: - Tests

    @Test("shows the signed-in accounts and which one is active")
    @MainActor
    func showsAccounts() async {
        let harness = ServiceHarness()
        await harness.gitHubClient.setAccounts(accounts)
        let service = harness.makeAccounts()

        await service.start()

        #expect(service.loadState == .loaded(accounts))
        #expect(service.activeAccount?.login == "jamie")
    }

    @Test("reports the GitHub CLI as unavailable rather than showing an empty list")
    @MainActor
    func reportsUnavailableCLI() async {
        let harness = ServiceHarness()
        await harness.gitHubClient.setAvailable(false)
        let service = harness.makeAccounts()

        await service.start()

        #expect(service.loadState == .unavailable(.notInstalled))
    }

    @Test("reports a signed-out CLI separately from a missing one")
    @MainActor
    func reportsSignedOutCLI() async {
        let harness = ServiceHarness()
        await harness.gitHubClient.setAccountsError(.notAuthenticated)
        let service = harness.makeAccounts()

        await service.start()

        #expect(service.loadState == .unavailable(.notAuthenticated))
    }

    @Test("switches the active account and reloads")
    @MainActor
    func switchesAccount() async {
        let harness = ServiceHarness()
        await harness.gitHubClient.setAccounts(accounts)
        let service = harness.makeAccounts()
        await service.start()

        await service.switchTo(GitHubAccount(login: "acme-bot", host: "github.com", isActive: false))

        #expect(service.activeAccount?.login == "acme-bot")
        #expect(service.switchingAccount == nil)
    }

    @Test("surfaces a failed account switch")
    @MainActor
    func surfacesSwitchFailure() async {
        let harness = ServiceHarness()
        await harness.gitHubClient.setAccounts(accounts)
        await harness.gitHubClient.setSwitchFailures(["acme-bot"])
        let service = harness.makeAccounts()
        await service.start()

        await service.switchTo(GitHubAccount(login: "acme-bot", host: "github.com", isActive: false))

        #expect(service.lastSwitchFailure == GitHubCLIError.switchFailed("acme-bot").message)
    }

    @Test("associates a repository with a preferred account in the shared workspace")
    @MainActor
    func associatesPreferredAccount() async {
        let harness = ServiceHarness()
        await harness.addRepository("a", name: "app", snapshot: RepositoryFixtures.snapshot())
        await harness.repositories.start()
        let service = harness.makeAccounts()

        guard let repository = harness.repositories.repositories.first else {
            Issue.record("expected a repository")
            return
        }

        service.associate("acme-bot", with: repository)

        #expect(harness.sharedStore.repositories.first?.preferredGitHubAccount == "acme-bot")
    }

    @Test("explains that account switching does not apply to an SSH remote")
    @MainActor
    func explainsSSHRemote() async {
        let harness = ServiceHarness()
        await harness.addRepository("a", name: "app", snapshot: RepositoryFixtures.snapshot())
        await harness.repositories.start()
        let service = harness.makeAccounts()

        guard let repository = harness.repositories.repositories.first else {
            Issue.record("expected a repository")
            return
        }

        #expect(service.inapplicabilityExplanation(for: repository)?.contains("SSH") == true)
    }

    @Test("writes the fallback and access-check settings to the shared preferences")
    @MainActor
    func writesAccountSettings() {
        let harness = ServiceHarness()
        let service = harness.makeAccounts()

        service.setFallbackEnabled(false)
        service.setAccessChecksEnabled(true)

        #expect(harness.settings.preferences.accountFallbackEnabled == false)
        #expect(harness.settings.preferences.accountAccessChecksEnabled)
    }
}
