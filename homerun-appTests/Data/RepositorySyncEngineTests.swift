import Foundation
import Testing
@testable import homerun_app

@Suite("RepositorySyncEngine", .tags(.data))
struct RepositorySyncEngineTests {
    // MARK: - Private

    private let directory = URL(filePath: "/tmp/repo")

    private func request(
        willCommit: Bool = true,
        untracked: [String] = [],
        setsUpstream: Bool = false,
        remoteURL: String? = "https://github.com/acme/app.git",
        checksAccess: Bool = false,
        fallbackEnabled: Bool = true,
        preferredAccount: String? = nil,
        additionalBranches: [GitBranchRef] = []
    ) -> RepositorySyncRequest {
        RepositorySyncRequest(
            identifier: "app",
            directory: directory,
            branch: "feature/login",
            protectedBranchFallback: "homerun/feature/login-20260923-100000",
            remote: "origin",
            remoteURL: remoteURL,
            setsUpstream: setsUpstream,
            willCommit: willCommit,
            untrackedPathsToInclude: untracked,
            commitMessage: "WIP 2026-09-23 10:00:00",
            preferredAccount: preferredAccount,
            checksAccountAccess: checksAccess,
            fallbackEnabled: fallbackEnabled,
            additionalBranches: additionalBranches
        )
    }

    private func makeEngine(
        git: StubGitClient = StubGitClient(),
        githubClient: StubGitHubCLIClient = StubGitHubCLIClient(),
        fallback: StubPushFallback = StubPushFallback()
    ) -> RepositorySyncEngine {
        RepositorySyncEngine(gitClient: git, gitHubClient: githubClient, pushFallback: fallback)
    }

    // MARK: - Commit and push

    @Test("stages tracked changes, commits with the WIP message, then pushes the current branch")
    func commitsThenPushes() async {
        let git = StubGitClient()
        await git.setHead("newhead")

        let report = await makeEngine(git: git).sync(request())

        #expect(await git.calls == ["stageTracked", "commit", "push"])
        #expect(await git.commitMessages == ["WIP 2026-09-23 10:00:00"])
        #expect(report.result == .succeeded(commit: "newhead", branch: "feature/login"))
        #expect(report.committed)
    }

    @Test("stages only the untracked files the review selected")
    func stagesSelectedUntrackedOnly() async {
        let git = StubGitClient()

        _ = await makeEngine(git: git).sync(request(untracked: ["Notes.md"]))

        #expect(await git.stagedPaths == [["Notes.md"]])
    }

    @Test("pushes without committing when there was nothing to commit")
    func pushesWithoutCommitting() async {
        let git = StubGitClient()
        await git.setCommitError(.nothingToCommit)

        let report = await makeEngine(git: git).sync(request())

        #expect(report.committed == false)
        #expect(await git.calls.contains("push"))
        #expect(report.result == .succeeded(commit: "head0001", branch: "feature/login"))
    }

    @Test("never pushes when the commit itself failed")
    func stopsOnCommitFailure() async {
        let git = StubGitClient()
        await git.setCommitError(.commandFailed("index locked"))

        let report = await makeEngine(git: git).sync(request())

        #expect(await git.calls.contains("push") == false)
        #expect(report.result == .failed(.git(String(describing: GitError.commandFailed("index locked")))))
    }

    @Test("pushes only, with no staging, when the plan asked for a push")
    func pushesOnly() async {
        let git = StubGitClient()

        _ = await makeEngine(git: git).sync(request(willCommit: false))

        #expect(await git.calls == ["push"])
    }

    // MARK: - Other branches

    private let otherBranches = [
        GitBranchRef(name: "spike", upstream: nil, aheadCount: 0, behindCount: 0),
        GitBranchRef(name: "feature/ahead", upstream: "origin/feature/ahead", aheadCount: 2, behindCount: 0)
    ]

    @Test("pushes the other branches after the current one, creating an upstream only where there is none")
    func pushesOtherBranches() async {
        let git = StubGitClient()

        let report = await makeEngine(git: git).sync(request(additionalBranches: otherBranches))

        let pushes = await git.pushes
        #expect(pushes.map(\.branch) == ["feature/login", "spike", "feature/ahead"])
        #expect(pushes.map(\.setUpstream) == [false, true, false])
        #expect(report.result == .succeeded(commit: "head0001", branch: "feature/login"))
    }

    @Test("reports the other branches that did not push, without branching off them")
    func reportsOtherBranchFailures() async {
        let git = StubGitClient()
        await git.setPushFailure(.branchProtected("GH006"), forBranch: "spike")

        let report = await makeEngine(git: git).sync(request(additionalBranches: otherBranches))

        #expect(report.result == .failed(.branchesNotPushed(["spike"])))
        #expect(await git.calls.contains("createBranch") == false)
        #expect(await git.pushes.map(\.branch) == ["feature/login", "spike", "feature/ahead"])
    }

    @Test("retries another branch through the account fallback when authentication fails")
    func retriesOtherBranchThroughFallback() async {
        let git = StubGitClient()
        await git.setPushFailure(.authenticationFailed("denied"), forBranch: "spike")
        let fallback = StubPushFallback(result: .succeeded(account: "acme-bot", attempts: []))

        let report = await makeEngine(git: git, fallback: fallback)
            .sync(request(additionalBranches: otherBranches))

        #expect(report.result == .succeeded(commit: "head0001", branch: "feature/login"))
        #expect(await fallback.contexts.map(\.branch) == ["spike"])
        #expect(await fallback.contexts.first?.setsUpstream == true)
    }

    @Test("leaves the other branches alone when the current branch failed to push")
    func skipsOtherBranchesAfterFailure() async {
        let git = StubGitClient()
        await git.setPushFailures([.diverged])

        _ = await makeEngine(git: git).sync(request(additionalBranches: otherBranches))

        #expect(await git.pushes.map(\.branch) == ["feature/login"])
    }

    // MARK: - Failures

    @Test("reports a diverged branch rather than force-pushing it")
    func reportsDivergence() async {
        let git = StubGitClient()
        await git.setPushFailures([.diverged])

        #expect(await makeEngine(git: git).sync(request()).result == .failed(.diverged))
    }

    // MARK: - Protected branches

    @Test("pushes the work to a new upstream branch when the remote protects the current one")
    func pushesProtectedBranchToFallback() async {
        let git = StubGitClient()
        await git.setPushFailures([.branchProtected("GH006: Protected branch update failed")])

        let report = await makeEngine(git: git).sync(request())

        #expect(await git.calls == ["stageTracked", "commit", "push", "createBranch", "push"])
        #expect(await git.createdBranches == ["homerun/feature/login-20260923-100000"])
        #expect(await git.pushes.last?.branch == "homerun/feature/login-20260923-100000")
        #expect(await git.pushes.last?.setUpstream == true)
        #expect(report.branch == "homerun/feature/login-20260923-100000")
        #expect(report.result == .succeeded(commit: "head0001", branch: "homerun/feature/login-20260923-100000"))
        #expect(report.committed)
    }

    @Test("reports both branches when the fallback branch could not be pushed either")
    func reportsFailedFallbackPush() async {
        let git = StubGitClient()
        await git.setPushFailures([.branchProtected("GH013"), .authenticationFailed("denied")])

        let report = await makeEngine(git: git).sync(request())

        #expect(report.result == .failed(.protectedBranchFallbackFailed(
            branch: "feature/login",
            fallback: "homerun/feature/login-20260923-100000",
            detail: String(describing: GitError.authenticationFailed("denied"))
        )))
    }

    @Test("does not push when the fallback branch could not be created")
    func stopsWhenFallbackBranchCannotBeCreated() async {
        let git = StubGitClient()
        await git.setPushFailures([.branchProtected("GH006")])
        await git.setCreateBranchError(.commandFailed("already exists"))

        let report = await makeEngine(git: git).sync(request())

        #expect(await git.pushes.count == 1)
        #expect(report.outcome(finishedAt: .now).didFail)
    }

    @Test("does not retry with another account when fallback is switched off")
    func skipsFallbackWhenDisabled() async {
        let git = StubGitClient()
        await git.setPushFailures([.authenticationFailed("denied")])
        let fallback = StubPushFallback()

        let report = await makeEngine(git: git, fallback: fallback).sync(request(fallbackEnabled: false))

        #expect(report.result == .failed(.authentication("denied")))
        #expect(await fallback.contexts.isEmpty)
    }

    @Test("retries a failed push through the account fallback when it is enabled")
    func retriesThroughFallback() async {
        let git = StubGitClient()
        await git.setPushFailures([.authenticationFailed("denied")])
        let fallback = StubPushFallback(result: .succeeded(account: "acme-bot", attempts: []))

        let report = await makeEngine(git: git, fallback: fallback).sync(request(preferredAccount: "acme-bot"))

        #expect(report.result == .succeeded(commit: "head0001", branch: "feature/login"))
        #expect(await fallback.contexts.first?.preferredAccount == "acme-bot")
    }

    @Test("keeps the original authentication failure when every account was exhausted")
    func keepsFailureWhenExhausted() async {
        let git = StubGitClient()
        await git.setPushFailures([.authenticationFailed("denied")])
        let attempts = [AccountFallbackAttempt(account: "acme-bot", failureMessage: "denied")]
        let fallback = StubPushFallback(result: .exhausted(attempts))

        let report = await makeEngine(git: git, fallback: fallback).sync(request())

        #expect(report.result == .failed(.authentication("denied")))
        #expect(report.fallback == .exhausted(attempts))
    }

    // MARK: - Access checks

    @Test("stops before committing when the account cannot reach the repository")
    func stopsWhenAccessDenied() async {
        let git = StubGitClient()
        let githubClient = StubGitHubCLIClient()
        await githubClient.setAccounts([GitHubAccount(login: "jamie", host: "github.com", isActive: true)])

        let report = await makeEngine(git: git, githubClient: githubClient).sync(request(checksAccess: true))

        #expect(report.result == .failed(.accountAccessDenied("jamie")))
        #expect(await git.calls.isEmpty)
    }

    @Test("syncs normally when the access check passes")
    func syncsWhenAccessGranted() async {
        let git = StubGitClient()
        let githubClient = StubGitHubCLIClient()
        await githubClient.setAccessibleRemotes(["https://github.com/acme/app.git"])

        let report = await makeEngine(git: git, githubClient: githubClient).sync(request(checksAccess: true))

        #expect(report.result == .succeeded(commit: "head0001", branch: "feature/login"))
    }

    @Test("skips the access check for a remote the GitHub CLI does not authenticate")
    func skipsAccessCheckForSSH() async {
        let git = StubGitClient()
        let githubClient = StubGitHubCLIClient()

        let report = await makeEngine(git: git, githubClient: githubClient).sync(request(
            remoteURL: "git@github.com:acme/app.git",
            checksAccess: true
        ))

        #expect(report.result == .succeeded(commit: "head0001", branch: "feature/login"))
        #expect(await githubClient.accessChecks.isEmpty)
    }
}
