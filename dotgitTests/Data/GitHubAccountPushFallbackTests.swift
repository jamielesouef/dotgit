import Foundation
import Testing
@testable import dotgit

@Suite("GitHubAccountPushFallback", .tags(.data))
struct GitHubAccountPushFallbackTests {
    // MARK: - Private

    private let directory = URL(filePath: "/tmp/repo")

    private var accounts: [GitHubAccount] {
        [
            GitHubAccount(login: "jamie", host: "github.com", isActive: true),
            GitHubAccount(login: "acme-bot", host: "github.com", isActive: false),
            GitHubAccount(login: "work", host: "github.com", isActive: false)
        ]
    }

    private func context(
        remoteURL: String? = "https://github.com/acme/app.git",
        preferred: String? = nil
    ) -> PushAttemptContext {
        PushAttemptContext(
            directory: directory,
            branch: "feature/login",
            remote: "origin",
            remoteURL: remoteURL,
            setsUpstream: false,
            preferredAccount: preferred
        )
    }

    // MARK: - Tests

    @Test("explains that account switching does not apply to an SSH remote")
    func explainsSSHRemote() async {
        let git = StubGitClient()
        let githubClient = StubGitHubCLIClient()
        let fallback = GitHubAccountPushFallback(gitClient: git, gitHubClient: githubClient)

        let result = await fallback.retryPush(context(remoteURL: "git@github.com:acme/app.git"))

        #expect(result ==
            .notApplicable(AccountFallbackUseCase.inapplicableExplanation(for: "git@github.com:acme/app.git")))
        #expect(await git.calls.isEmpty)
    }

    @Test("explains that fallback is unavailable without the GitHub CLI")
    func explainsMissingCLI() async {
        let githubClient = StubGitHubCLIClient()
        await githubClient.setAvailable(false)
        let fallback = GitHubAccountPushFallback(gitClient: StubGitClient(), gitHubClient: githubClient)

        #expect(await fallback.retryPush(context()) == .notApplicable(GitHubCLIError.notInstalled.message))
    }

    @Test("pushes with the first other account that works")
    func pushesWithAnotherAccount() async {
        let git = StubGitClient()
        let githubClient = StubGitHubCLIClient()
        await githubClient.setAccounts(accounts)
        let fallback = GitHubAccountPushFallback(gitClient: git, gitHubClient: githubClient)

        let result = await fallback.retryPush(context())

        #expect(result == .succeeded(
            account: "acme-bot",
            attempts: [AccountFallbackAttempt(account: "acme-bot", failureMessage: nil)]
        ))
        #expect(await git.pushes.count == 1)
    }

    @Test("tries the repository's preferred account before the others")
    func triesPreferredAccountFirst() async {
        let githubClient = StubGitHubCLIClient()
        await githubClient.setAccounts(accounts)
        let fallback = GitHubAccountPushFallback(gitClient: StubGitClient(), gitHubClient: githubClient)

        _ = await fallback.retryPush(context(preferred: "work"))

        #expect(await githubClient.switchedAccounts.first == "work")
    }

    @Test("restores the account that was active before the retries succeeded")
    func restoresAccountAfterSuccess() async {
        let githubClient = StubGitHubCLIClient()
        await githubClient.setAccounts(accounts)
        let fallback = GitHubAccountPushFallback(gitClient: StubGitClient(), gitHubClient: githubClient)

        _ = await fallback.retryPush(context())

        #expect(await githubClient.switchedAccounts.last == "jamie")
    }

    @Test("restores the account that was active even when every retry failed")
    func restoresAccountAfterFailure() async {
        let git = StubGitClient()
        await git.setPushFailures([.authenticationFailed("no"), .authenticationFailed("no")])
        let githubClient = StubGitHubCLIClient()
        await githubClient.setAccounts(accounts)
        let fallback = GitHubAccountPushFallback(gitClient: git, gitHubClient: githubClient)

        let result = await fallback.retryPush(context())

        #expect(result.attempts.count == 2)
        #expect(result.attempts.allSatisfy { $0.succeeded == false })
        #expect(await githubClient.switchedAccounts.last == "jamie")
    }

    @Test("records an account whose switch itself failed and moves on")
    func recordsSwitchFailure() async {
        let githubClient = StubGitHubCLIClient()
        await githubClient.setAccounts(accounts)
        await githubClient.setSwitchFailures(["acme-bot"])
        let fallback = GitHubAccountPushFallback(gitClient: StubGitClient(), gitHubClient: githubClient)

        let result = await fallback.retryPush(context())

        #expect(result == .succeeded(
            account: "work",
            attempts: [
                AccountFallbackAttempt(
                    account: "acme-bot",
                    failureMessage: GitHubCLIError.switchFailed("acme-bot").message
                ),
                AccountFallbackAttempt(account: "work", failureMessage: nil)
            ]
        ))
    }

    @Test("reports that there was nobody else to try when only one account is signed in")
    func reportsNoOtherAccounts() async {
        let githubClient = StubGitHubCLIClient()
        await githubClient.setAccounts([GitHubAccount(login: "jamie", host: "github.com", isActive: true)])
        let fallback = GitHubAccountPushFallback(gitClient: StubGitClient(), gitHubClient: githubClient)

        #expect(await fallback.retryPush(context()) == .exhausted([]))
    }
}
