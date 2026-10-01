import Foundation
import Testing
@testable import dotgit

@Suite("Worktrees in the repositories and sync services", .tags(.service))
struct WorktreeServiceTests {
    // MARK: - Private

    @MainActor
    private func makeRepositoryWithWorktree(_ harness: ServiceHarness) async -> (main: URL, worktree: URL) {
        let main = await harness.addRepository(
            "a",
            name: "app",
            snapshot: RepositoryFixtures.snapshot(branch: "main")
        )

        let worktree = harness.makeDirectory("app-login")

        await harness.gitClient.setSnapshot(
            RepositoryFixtures.snapshot(
                branch: "feature/login",
                tracked: [GitFileChange(path: "Login.swift", status: .modified)],
                upstream: "origin/feature/login"
            ),
            at: worktree
        )

        await harness.gitClient.setWorktrees(
            [
                RepositoryFixtures.gitWorktree(main.path(percentEncoded: false), branch: "main", isMain: true),
                RepositoryFixtures.gitWorktree(worktree.path(percentEncoded: false))
            ],
            at: main
        )

        return (main, worktree)
    }

    // MARK: - Loading

    @Test("lists a repository's worktrees under it rather than as repositories of their own")
    @MainActor
    func listsWorktreesUnderRepository() async {
        let harness = ServiceHarness()
        let (_, worktree) = await makeRepositoryWithWorktree(harness)

        await harness.repositories.start()

        #expect(harness.repositories.repositories.count == 1)
        #expect(harness.repositories.repositories.first?.worktrees.map(\.localPath) == [worktree])
        #expect(harness.repositories.repositories.first?.worktrees.first?.status == .dirty)
    }

    @Test("finds a worktree by its own identifier")
    @MainActor
    func findsWorktreeByIdentifier() async {
        let harness = ServiceHarness()
        _ = await makeRepositoryWithWorktree(harness)
        await harness.repositories.start()

        let identifier = harness.repositories.repositories[0].worktrees[0].id

        #expect(harness.repositories.repository(identifier: identifier)?.isWorktree == true)
    }

    @Test("keeps the worktrees when a repository's settings change")
    @MainActor
    func keepsWorktreesOnUpdate() async {
        let harness = ServiceHarness()
        _ = await makeRepositoryWithWorktree(harness)
        await harness.repositories.start()
        var shared = harness.repositories.repositories[0].shared
        shared.wipCommitPrefixOverride = "SAVE"

        harness.repositories.update(shared)

        #expect(harness.repositories.repositories[0].worktrees.count == 1)
        #expect(harness.repositories.repositories[0].worktrees[0].shared.wipCommitPrefixOverride == "SAVE")
    }

    @Test("tracks the main checkout when a worktree folder is added")
    @MainActor
    func addsMainCheckoutForWorktreeFolder() async {
        let harness = ServiceHarness()
        await harness.repositories.start()
        let main = harness.makeDirectory("tool")
        let worktree = harness.makeDirectory("tool-spike")
        await harness.gitClient.setSnapshot(RepositoryFixtures.snapshot(), at: main)
        await harness.gitClient.setSnapshot(RepositoryFixtures.snapshot(branch: "spike"), at: worktree)

        await harness.gitClient.setWorktrees(
            [
                RepositoryFixtures.gitWorktree(main.path(percentEncoded: false), branch: "main", isMain: true),
                RepositoryFixtures.gitWorktree(worktree.path(percentEncoded: false))
            ],
            at: worktree
        )

        await harness.repositories.addRepository(at: worktree)

        #expect(harness.repositories.repositories.first?.localPath?.lastPathComponent == "tool")
    }

    // MARK: - Sync

    @Test("syncs a repository's worktrees with it, each in its own folder")
    @MainActor
    func syncsWorktreesWithRepository() async {
        let harness = ServiceHarness()
        let (main, worktree) = await makeRepositoryWithWorktree(harness)
        await harness.gitClient.setSnapshot(RepositoryFixtures.snapshot(branch: "feature/app", ahead: 1), at: main)
        await harness.repositories.start()
        harness.settings.updatePreferences { $0.requiresSyncConfirmation = false }
        let service = harness.makeSync()

        await service.review(identifiers: ["a"])

        #expect(await harness.syncEngine.requests.map(\.directory).contains(worktree))
    }

    @Test("syncs only the chosen worktree when asked for that checkout alone")
    @MainActor
    func syncsChosenWorktreeAlone() async {
        let harness = ServiceHarness()
        let (_, worktree) = await makeRepositoryWithWorktree(harness)
        await harness.repositories.start()
        harness.settings.updatePreferences { $0.requiresSyncConfirmation = false }
        let service = harness.makeSync()
        let identifier = harness.repositories.repositories[0].worktrees[0].id

        await service.review(identifiers: [identifier], includesWorktrees: false)

        #expect(await harness.syncEngine.requests.map(\.directory) == [worktree])
        #expect(await harness.syncEngine.requests.first?.branch == "feature/login")
    }
}
