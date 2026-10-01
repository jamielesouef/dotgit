import Foundation
import Testing
@testable import dotgit

@Suite("Worktrees against real git", .tags(.data))
struct ProcessGitClientWorktreeIntegrationTests {
    // MARK: - Private

    private func makeFixtureWithWorktree() async throws -> (fixture: GitFixture, worktree: URL)? {
        guard let fixture = GitFixture() else {
            return nil
        }

        try await fixture.create()

        let worktree = fixture.root.appending(path: "app-login")

        try await fixture.git(
            ["worktree", "add", "-b", "feature/login", worktree.path(percentEncoded: false)],
            at: fixture.workingCopy
        )

        return (fixture, worktree)
    }

    // MARK: - Tests

    @Test("lists the main checkout and a real linked worktree with its branch")
    func listsRealWorktrees() async throws {
        guard let (fixture, _) = try await makeFixtureWithWorktree() else {
            return
        }

        defer { fixture.remove() }

        let worktrees = try await fixture.client.worktrees(at: fixture.workingCopy)

        #expect(worktrees.map(\.name) == ["app", "app-login"])
        #expect(worktrees.map(\.isMain) == [true, false])
        #expect(worktrees.map(\.branch) == ["main", "feature/login"])
        #expect(WorktreeUseCase.linkedWorktrees(worktrees).map(\.name) == ["app-login"])
    }

    @Test("reads a real worktree's own branch and changes, separate from the main checkout")
    func readsRealWorktreeSnapshot() async throws {
        guard let (fixture, worktree) = try await makeFixtureWithWorktree() else {
            return
        }

        defer { fixture.remove() }
        try "login\n".write(to: worktree.appending(path: "README.md"), atomically: true, encoding: .utf8)

        let worktreeSnapshot = try await fixture.client.snapshot(at: worktree)
        let mainSnapshot = try await fixture.client.snapshot(at: fixture.workingCopy)

        #expect(worktreeSnapshot.currentBranch == "feature/login")
        #expect(worktreeSnapshot.isDirty)
        #expect(mainSnapshot.currentBranch == "main")
        #expect(mainSnapshot.workingTree.isClean)
    }

    @Test("finds the main checkout from inside a real worktree")
    func findsMainFromWorktree() async throws {
        guard let (fixture, worktree) = try await makeFixtureWithWorktree() else {
            return
        }

        defer { fixture.remove() }

        let worktrees = try await fixture.client.worktrees(at: worktree)
        let main = WorktreeUseCase.mainCheckout(for: worktree.resolvingSymlinksInPath(), in: worktrees)

        #expect(main?.lastPathComponent == "app")
    }

    @Test("does not discover a real worktree as a repository of its own")
    func skipsRealWorktreeInDiscovery() async throws {
        guard let (fixture, _) = try await makeFixtureWithWorktree() else {
            return
        }

        defer { fixture.remove() }

        let found = await FileSystemRepositoryDiscovery(fileManager: .default)
            .discoverRepositories(in: fixture.root, ignoredFolderNames: [], maximumDepth: 3)

        #expect(found.map(\.name) == ["app"])
    }
}
