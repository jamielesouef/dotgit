import Foundation
import Testing
@testable import dotgit

@Suite("ProcessGitClient", .tags(.data))
struct ProcessGitClientTests {
    // MARK: - Private

    private let directory = URL(filePath: "/tmp/repo")

    private func makeClient(_ runner: StubCommandRunner) -> ProcessGitClient {
        ProcessGitClient(commandRunner: runner, gitPath: "/usr/bin/git")
    }

    private func stubHealthyRepository(_ runner: StubCommandRunner) async {
        await runner.stub(["rev-parse", "--is-inside-work-tree"], output: "true\n")
        await runner.stub(["rev-parse", "--abbrev-ref", "HEAD"], output: "feature/login\n")
        await runner.stub(["rev-parse", "HEAD"], output: "abc123\n")
        await runner.stub(["remote"], output: "origin\n")
        await runner.stub(["config", "--get", "remote.origin.url"], output: "git@github.com:acme/app.git\n")
        await runner.stub(
            ["rev-parse", "--abbrev-ref", "--symbolic-full-name", "@{upstream}"],
            output: "origin/feature/login\n"
        )
        await runner.stub(["rev-list", "--left-right", "--count"], output: "0\t2\n")
        await runner.stub(["status"], output: " M App.swift\0?? Scratch.md\0")
        await runner.stub(
            ["for-each-ref"],
            output: "feature/login\u{1F}origin/feature/login\u{1F}[ahead 2]\nspike\u{1F}\u{1F}\n"
        )
        await runner.stub(["submodule", "status"], output: "")
    }

    // MARK: - snapshot

    @Test("builds a snapshot from the branch, upstream, working tree and branch list")
    func buildsSnapshot() async throws {
        let runner = StubCommandRunner()
        await stubHealthyRepository(runner)

        let snapshot = try await makeClient(runner).snapshot(at: directory)

        #expect(snapshot.currentBranch == "feature/login")
        #expect(snapshot.headCommit == "abc123")
        #expect(snapshot.remoteURL == "git@github.com:acme/app.git")
        #expect(snapshot.upstreamBranch == "origin/feature/login")
        #expect(snapshot.aheadCount == 2)
        #expect(snapshot.behindCount == 0)
        #expect(snapshot.isDirty)
        #expect(snapshot.workingTree.untrackedPaths == ["Scratch.md"])
    }

    @Test("reports another local-only branch as outstanding work on the current branch's snapshot")
    func reportsOtherBranches() async throws {
        let runner = StubCommandRunner()
        await stubHealthyRepository(runner)

        let snapshot = try await makeClient(runner).snapshot(at: directory)

        #expect(snapshot.otherBranchesNeedingPush.map(\.name) == ["spike"])
    }

    @Test("reports a detached head as having no current branch")
    func reportsDetachedHead() async throws {
        let runner = StubCommandRunner()
        await stubHealthyRepository(runner)
        await runner.stub(["rev-parse", "--abbrev-ref", "HEAD"], output: "HEAD\n")

        let snapshot = try await makeClient(runner).snapshot(at: directory)

        #expect(snapshot.isDetached)
    }

    @Test("throws notARepository for a folder git does not recognise")
    func rejectsNonRepository() async {
        let runner = StubCommandRunner()
        await runner.stub(["rev-parse", "--is-inside-work-tree"], output: "", exitCode: 128)

        await #expect(throws: GitError.notARepository("/tmp/repo")) {
            try await makeClient(runner).snapshot(at: directory)
        }
    }

    // MARK: - commit

    @Test("stages tracked changes including deletions without touching untracked files")
    func stagesTrackedOnly() async throws {
        let runner = StubCommandRunner()

        try await makeClient(runner).stageTrackedChanges(at: directory)

        #expect(await runner.argumentLists == [["add", "--update", "--", "."]])
    }

    @Test("refuses to commit when nothing is staged")
    func refusesEmptyCommit() async {
        let runner = StubCommandRunner()
        await runner.stub(["diff", "--cached", "--name-only"], output: "\n")

        await #expect(throws: GitError.nothingToCommit) {
            try await makeClient(runner).commit(message: "WIP", at: directory)
        }
    }

    @Test("commits with the supplied message once something is staged")
    func commitsStagedWork() async throws {
        let runner = StubCommandRunner()
        await runner.stub(["diff", "--cached", "--name-only"], output: "App.swift\n")

        try await makeClient(runner).commit(message: "WIP 2026-09-23", at: directory)

        #expect(await runner.containsArguments(["commit", "--message", "WIP 2026-09-23"]))
    }

    // MARK: - push

    @Test("sets the upstream only when the branch has no push destination yet")
    func setsUpstreamWhenMissing() async throws {
        let runner = StubCommandRunner()

        try await makeClient(runner).push(branch: "spike", remote: "origin", setUpstream: true, at: directory)

        #expect(await runner.containsArguments(["push", "--set-upstream", "origin", "spike"]))
    }

    @Test("surfaces an authentication failure so account fallback can retry it")
    func surfacesAuthFailure() async {
        let runner = StubCommandRunner()
        let message = "remote: Authentication failed"
        await runner.stub(["push"], exitCode: 128, error: message)

        await #expect(throws: GitError.authenticationFailed(message)) {
            try await makeClient(runner).push(branch: "main", remote: "origin", setUpstream: false, at: directory)
        }
    }

    @Test("surfaces a rejected push as divergence rather than forcing it")
    func surfacesDivergence() async {
        let runner = StubCommandRunner()
        await runner.stub(["push"], exitCode: 1, error: "! [rejected] main -> main (non-fast-forward)")

        await #expect(throws: GitError.diverged) {
            try await makeClient(runner).push(branch: "main", remote: "origin", setUpstream: false, at: directory)
        }
    }

    // MARK: - resume

    @Test("fast-forwards only, never merging or rebasing")
    func fastForwardsOnly() async throws {
        let runner = StubCommandRunner()

        try await makeClient(runner).fastForward(at: directory)

        #expect(await runner.argumentLists == [["merge", "--ff-only", "@{upstream}"]])
    }

    @Test("maps a missing git executable to gitUnavailable")
    func mapsMissingGit() async {
        let runner = StubCommandRunner()
        await runner.stub(["fetch"], failure: .executableMissing("/usr/bin/git"))

        await #expect(throws: GitError.gitUnavailable) {
            try await makeClient(runner).fetch(remote: "origin", at: directory)
        }
    }
}
