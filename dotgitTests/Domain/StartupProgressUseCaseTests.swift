import Foundation
import Testing
@testable import dotgit

@Suite("StartupProgressUseCase", .tags(.domain))
struct StartupProgressUseCaseTests {
    // MARK: - Private

    private func account(_ login: String, isActive: Bool = false) -> GitHubAccount {
        GitHubAccount(login: login, host: "github.com", isActive: isActive)
    }

    // MARK: - Tests

    @Test("lists every check as waiting before anything has run")
    func listsEveryCheckAsWaiting() {
        let steps = StartupProgressUseCase.waitingSteps()

        #expect(steps.map(\.check) == StartupCheck.allCases)
        #expect(steps.allSatisfy { $0.status == .waiting })
    }

    @Test("fails the launch on a missing git because nothing works without it")
    func failsOnMissingGit() {
        #expect(StartupProgressUseCase.gitChecked(isAvailable: false).status == .failed)
        #expect(StartupProgressUseCase.gitChecked(isAvailable: true).status == .passed)
    }

    @Test("only warns about a missing GitHub CLI because it is optional")
    func warnsOnMissingGitHubCLI() {
        #expect(StartupProgressUseCase.gitHubCLIChecked(isAvailable: false).status == .warning)
        #expect(StartupProgressUseCase.gitHubCLIChecked(isAvailable: true).status == .passed)
    }

    @Test("skips the sign-in check when there is no GitHub CLI to ask")
    func skipsSignInWithoutGitHubCLI() {
        let step = StartupProgressUseCase.gitHubAccountsChecked(
            isGitHubCLIAvailable: false,
            accounts: [account("jamie")]
        )

        #expect(step.status == .skipped)
    }

    @Test("warns when the GitHub CLI is installed but nobody is signed in")
    func warnsWhenSignedOut() {
        let step = StartupProgressUseCase.gitHubAccountsChecked(isGitHubCLIAvailable: true, accounts: [])

        #expect(step.status == .warning)
    }

    @Test("names every signed-in account and which one is active")
    func namesSignedInAccounts() {
        let step = StartupProgressUseCase.gitHubAccountsChecked(
            isGitHubCLIAvailable: true,
            accounts: [account("jamie", isActive: true), account("work")]
        )

        #expect(step.status == .passed)
        #expect(step.detail.contains("jamie (active)"))
        #expect(step.detail.contains("work"))
        #expect(step.detail.contains("work (active)") == false)
    }

    @Test("replaces only the step for the same check, keeping the order")
    func replacesOnlyTheMatchingStep() {
        let steps = StartupProgressUseCase.replacing(
            StartupProgressUseCase.running(.gitHubCLI),
            in: StartupProgressUseCase.waitingSteps()
        )

        #expect(steps.map(\.status) == [.waiting, .running, .waiting])
        #expect(steps.map(\.check) == StartupCheck.allCases)
    }
}
