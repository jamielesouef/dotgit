import Foundation
import Testing
@testable import dotgit

@Suite("WorktreeUseCase", .tags(.domain))
struct WorktreeUseCaseTests {
    // MARK: - Private

    private var main: TrackedRepository {
        RepositoryFixtures.tracked(
            snapshot: RepositoryFixtures.snapshot(
                branch: "main",
                branches: [
                    GitBranchRef(name: "main", upstream: "origin/main", aheadCount: 0, behindCount: 0),
                    GitBranchRef(name: "feature/login", upstream: nil, aheadCount: 0, behindCount: 0),
                    GitBranchRef(name: "spike", upstream: nil, aheadCount: 0, behindCount: 0)
                ]
            )
        )
    }

    private var loginWorktree: TrackedRepository {
        RepositoryFixtures.worktree(
            snapshot: RepositoryFixtures.snapshot(
                branch: "feature/login",
                tracked: [GitFileChange(path: "Login.swift", status: .modified)],
                branches: [
                    GitBranchRef(name: "main", upstream: "origin/main", aheadCount: 0, behindCount: 0),
                    GitBranchRef(name: "feature/login", upstream: nil, aheadCount: 0, behindCount: 0),
                    GitBranchRef(name: "spike", upstream: nil, aheadCount: 0, behindCount: 0)
                ],
                upstream: nil
            )
        )
    }

    // MARK: - Identity

    @Test("gives a worktree its own identity, distinct from its repository")
    func givesWorktreeItsOwnIdentity() {
        #expect(loginWorktree.id != main.id)
        #expect(loginWorktree.id.hasPrefix(main.id))
        #expect(loginWorktree.isWorktree)
    }

    @Test("keeps only the linked worktrees that can be read")
    func keepsReadableLinkedWorktrees() {
        let linked = WorktreeUseCase.linkedWorktrees([
            RepositoryFixtures.gitWorktree("/repo", branch: "main", isMain: true),
            RepositoryFixtures.gitWorktree("/repo-login"),
            RepositoryFixtures.gitWorktree("/repo-gone", isPrunable: true)
        ])

        #expect(linked.map(\.name) == ["repo-login"])
    }

    @Test("finds the main checkout for a folder that is one of its worktrees")
    func findsMainCheckoutForWorktree() {
        let listed = [
            RepositoryFixtures.gitWorktree("/repo", branch: "main", isMain: true),
            RepositoryFixtures.gitWorktree("/repo-login")
        ]

        #expect(WorktreeUseCase.mainCheckout(for: URL(filePath: "/repo-login"), in: listed) == URL(filePath: "/repo"))
        #expect(WorktreeUseCase.mainCheckout(for: URL(filePath: "/repo/"), in: listed) == nil)
    }

    // MARK: - Linking

    @Test("reports a branch checked out in a worktree against the worktree, not the main checkout")
    func reportsBranchAgainstItsWorktree() {
        let linked = WorktreeUseCase.linking(main, to: [loginWorktree])

        #expect(linked.snapshot?.otherBranchesNeedingPush.map(\.name) == ["spike"])
        #expect(linked.worktrees.first?.snapshot?.otherBranchesNeedingPush.isEmpty == true)
    }

    @Test("counts a dirty worktree as local-only work on its clean repository")
    func countsWorktreeWorkOnRepository() {
        let clean = RepositoryFixtures.tracked(snapshot: RepositoryFixtures.snapshot())
        let linked = WorktreeUseCase.linking(clean, to: [loginWorktree])

        #expect(linked.hasOwnLocalOnlyWork == false)
        #expect(linked.hasLocalOnlyWork)
    }

    // MARK: - Selection

    @Test("shows the chosen worktree, falling back to the main checkout when it has gone")
    func choosesCheckout() {
        let linked = WorktreeUseCase.linking(main, to: [loginWorktree])

        #expect(WorktreeUseCase.checkout(in: linked, selectedIdentifier: loginWorktree.id).isWorktree)
        #expect(WorktreeUseCase.checkout(in: linked, selectedIdentifier: "gone").id == main.id)
        #expect(WorktreeUseCase.checkout(in: linked, selectedIdentifier: nil).id == main.id)
    }

    @Test("syncs a repository together with its worktrees unless asked for one checkout")
    func choosesCheckoutsToSync() {
        let linked = WorktreeUseCase.linking(main, to: [loginWorktree])

        let everything = WorktreeUseCase.checkoutsToSync(in: [linked], identifiers: nil, includesWorktrees: true)
        let repository = WorktreeUseCase.checkoutsToSync(in: [linked], identifiers: [main.id], includesWorktrees: true)
        let mainOnly = WorktreeUseCase.checkoutsToSync(in: [linked], identifiers: [main.id], includesWorktrees: false)

        let worktreeOnly = WorktreeUseCase.checkoutsToSync(
            in: [linked],
            identifiers: [loginWorktree.id],
            includesWorktrees: false
        )

        #expect(everything.map(\.id) == [main.id, loginWorktree.id])
        #expect(repository.map(\.id) == [main.id, loginWorktree.id])
        #expect(mainOnly.map(\.id) == [main.id])
        #expect(worktreeOnly.map(\.id) == [loginWorktree.id])
    }

    @Test("names the sync button after the checkout it will sync")
    func namesSyncButton() {
        let linked = WorktreeUseCase.linking(main, to: [loginWorktree])

        #expect(WorktreeUseCase.syncTitle(for: main, in: main) == "Sync")
        #expect(WorktreeUseCase.syncTitle(for: linked, in: linked) == "Sync main checkout only")
        #expect(WorktreeUseCase.syncTitle(for: linked.worktrees[0], in: linked) == "Sync this worktree")
    }

    // MARK: - Filtering

    @Test("keeps a clean repository visible while one of its worktrees has changes")
    func keepsCleanRepositoryWithDirtyWorktree() {
        let clean = RepositoryFixtures.tracked(snapshot: RepositoryFixtures.snapshot())
        let linked = WorktreeUseCase.linking(clean, to: [loginWorktree])

        let visible = RepositoryFilterUseCase.apply(
            to: [linked],
            filter: .dirty,
            showsCleanRepositories: false,
            searchText: "login"
        )

        #expect(visible.map(\.id) == [clean.id])
    }
}
