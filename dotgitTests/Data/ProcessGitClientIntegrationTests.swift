import Foundation
import Testing
@testable import dotgit

@Suite("ProcessGitClient against real git", .tags(.data))
struct ProcessGitClientIntegrationTests {
    // MARK: - Private

    private func makeFixture() async throws -> GitFixture? {
        guard let fixture = GitFixture() else {
            return nil
        }

        try await fixture.create()

        return fixture
    }

    // MARK: - Tests

    @Test("reads a real repository's branch, remote and upstream")
    func readsRealRepository() async throws {
        guard let fixture = try await makeFixture() else {
            return
        }

        defer { fixture.remove() }

        let snapshot = try await fixture.client.snapshot(at: fixture.workingCopy)

        #expect(snapshot.currentBranch == "main")
        #expect(snapshot.upstreamBranch == "origin/main")
        #expect(snapshot.defaultRemoteName == "origin")
        #expect(snapshot.workingTree.isClean)
    }

    @Test("separates a real modification from a real untracked file")
    func separatesRealChanges() async throws {
        guard let fixture = try await makeFixture() else {
            return
        }

        defer { fixture.remove() }
        try fixture.write("second\n", to: "README.md")
        try fixture.write("notes\n", to: "Notes.md")

        let snapshot = try await fixture.client.snapshot(at: fixture.workingCopy)

        #expect(snapshot.workingTree.trackedChanges == [GitFileChange(path: "README.md", status: .modified)])
        #expect(snapshot.workingTree.untrackedPaths == ["Notes.md"])
    }

    @Test("commits a real deletion through the tracked-changes staging")
    func commitsRealDeletion() async throws {
        guard let fixture = try await makeFixture() else {
            return
        }

        defer { fixture.remove() }
        try fixture.write("second\n", to: "Extra.md")
        try await fixture.git(["add", "Extra.md"], at: fixture.workingCopy)
        try await fixture.git(["commit", "--message", "Add Extra"], at: fixture.workingCopy)
        try fixture.delete("Extra.md")

        try await fixture.client.stageTrackedChanges(at: fixture.workingCopy)
        try await fixture.client.commit(message: "WIP 2026-09-23 10:00:00", at: fixture.workingCopy)

        let snapshot = try await fixture.client.snapshot(at: fixture.workingCopy)
        #expect(snapshot.workingTree.isClean)
        #expect(snapshot.aheadCount == 2)
    }

    @Test("leaves an untracked file out of an automatic WIP commit")
    func leavesUntrackedOutOfCommit() async throws {
        guard let fixture = try await makeFixture() else {
            return
        }

        defer { fixture.remove() }
        try fixture.write("second\n", to: "README.md")
        try fixture.write("notes\n", to: "Notes.md")

        try await fixture.client.stageTrackedChanges(at: fixture.workingCopy)
        try await fixture.client.commit(message: "WIP", at: fixture.workingCopy)

        let snapshot = try await fixture.client.snapshot(at: fixture.workingCopy)
        #expect(snapshot.workingTree.untrackedPaths == ["Notes.md"])
    }

    @Test("never stages a file git is told to ignore")
    func neverStagesIgnoredFile() async throws {
        guard let fixture = try await makeFixture() else {
            return
        }

        defer { fixture.remove() }
        try fixture.write("build/\n", to: ".gitignore")
        try FileManager.default.createDirectory(
            at: fixture.workingCopy.appending(path: "build"),
            withIntermediateDirectories: true
        )
        try fixture.write("binary\n", to: "build/output.o")

        let snapshot = try await fixture.client.snapshot(at: fixture.workingCopy)

        #expect(snapshot.workingTree.untrackedPaths == [".gitignore"])
    }

    @Test("pushes the current branch to a real remote and records the commit")
    func pushesToRealRemote() async throws {
        guard let fixture = try await makeFixture() else {
            return
        }

        defer { fixture.remove() }
        try fixture.write("second\n", to: "README.md")
        try await fixture.client.stageTrackedChanges(at: fixture.workingCopy)
        try await fixture.client.commit(message: "WIP", at: fixture.workingCopy)

        try await fixture.client.push(branch: "main", remote: "origin", setUpstream: false, at: fixture.workingCopy)

        let snapshot = try await fixture.client.snapshot(at: fixture.workingCopy)
        #expect(snapshot.aheadCount == 0)
        #expect(try await fixture.client.headCommit(at: fixture.workingCopy) == snapshot.headCommit)
    }

    @Test("reports a branch that was never pushed as local only")
    func reportsLocalOnlyBranch() async throws {
        guard let fixture = try await makeFixture() else {
            return
        }

        defer { fixture.remove() }
        try await fixture.git(["branch", "spike"], at: fixture.workingCopy)

        let snapshot = try await fixture.client.snapshot(at: fixture.workingCopy)

        #expect(snapshot.otherBranchesNeedingPush.map(\.name) == ["spike"])
    }

    @Test("reports unpushed tags against a real remote")
    func reportsUnpushedTags() async throws {
        guard let fixture = try await makeFixture() else {
            return
        }

        defer { fixture.remove() }
        try await fixture.git(["tag", "v1.0"], at: fixture.workingCopy)

        let local = try await fixture.client.localTags(at: fixture.workingCopy)
        let remote = try await fixture.client.remoteTags(remote: "origin", at: fixture.workingCopy)

        #expect(GitRemoteTagParser.unpushedTags(local: local, remote: remote) == ["v1.0"])
    }

    @Test("fast-forwards a real repository that is only behind")
    func fastForwardsRealRepository() async throws {
        guard let fixture = try await makeFixture() else {
            return
        }

        defer { fixture.remove() }
        let clone = fixture.root.appending(path: "clone")
        try await fixture.client.clone(remoteURL: fixture.remote.path(percentEncoded: false), into: clone)
        try fixture.write("second\n", to: "README.md")
        try await fixture.git(["commit", "--all", "--message", "Second"], at: fixture.workingCopy)
        try await fixture.git(["push", "origin", "main"], at: fixture.workingCopy)

        try await fixture.client.fetch(remote: "origin", at: clone)
        try await fixture.client.fastForward(at: clone)

        let snapshot = try await fixture.client.snapshot(at: clone)
        #expect(snapshot.behindCount == 0)
        #expect(try String(contentsOf: clone.appending(path: "README.md"), encoding: .utf8) == "second\n")
    }

    @Test("recognises a real remote refusing the branch, then pushes a new branch with an upstream")
    func pushesAroundProtectedBranch() async throws {
        guard let fixture = try await makeFixture() else {
            return
        }

        defer { fixture.remove() }
        let hook = fixture.remote.appending(path: "hooks/pre-receive")
        try """
        #!/bin/sh
        while read old new ref; do
            [ "$ref" = "refs/heads/main" ] && exit 1
        done
        exit 0
        """.write(to: hook, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o755],
            ofItemAtPath: hook.path(percentEncoded: false)
        )
        try fixture.write("second\n", to: "README.md")
        try await fixture.git(["commit", "--all", "--message", "Second"], at: fixture.workingCopy)

        do {
            try await fixture.client.push(branch: "main", remote: "origin", setUpstream: false, at: fixture.workingCopy)
            Issue.record("Expected the remote to refuse main")
        } catch {
            guard case .branchProtected = error else {
                Issue.record("Expected branchProtected, got \(error)")
                return
            }
        }

        try await fixture.client.createBranch("dotgit/main-20260924-100000", at: fixture.workingCopy)
        try await fixture.client.push(
            branch: "dotgit/main-20260924-100000",
            remote: "origin",
            setUpstream: true,
            at: fixture.workingCopy
        )

        let snapshot = try await fixture.client.snapshot(at: fixture.workingCopy)
        #expect(snapshot.currentBranch == "dotgit/main-20260924-100000")
        #expect(snapshot.upstreamBranch == "origin/dotgit/main-20260924-100000")
        #expect(snapshot.aheadCount == 0)
    }

    @Test("refuses a diverged push instead of forcing it")
    func refusesDivergedPush() async throws {
        guard let fixture = try await makeFixture() else {
            return
        }

        defer { fixture.remove() }
        let clone = fixture.root.appending(path: "clone")
        try await fixture.client.clone(remoteURL: fixture.remote.path(percentEncoded: false), into: clone)
        try await fixture.git(["config", "user.email", "tests@example.com"], at: clone)
        try await fixture.git(["config", "user.name", "dotgit tests"], at: clone)
        try fixture.write("theirs\n", to: "README.md")
        try await fixture.git(["commit", "--all", "--message", "Theirs"], at: fixture.workingCopy)
        try await fixture.git(["push", "origin", "main"], at: fixture.workingCopy)
        try "mine\n".write(to: clone.appending(path: "README.md"), atomically: true, encoding: .utf8)
        try await fixture.git(["commit", "--all", "--message", "Mine"], at: clone)

        await #expect(throws: GitError.diverged) {
            try await fixture.client.push(branch: "main", remote: "origin", setUpstream: false, at: clone)
        }
    }
}
