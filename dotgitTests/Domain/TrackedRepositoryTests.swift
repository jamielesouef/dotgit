import Foundation
import Testing
@testable import dotgit

@Suite("TrackedRepository", .tags(.domain))
struct TrackedRepositoryTests {
    @Test("treats a repository missing from this Mac as not cloned rather than removed")
    func reportsNotCloned() {
        let repository = RepositoryFixtures.tracked(path: nil)

        #expect(repository.isCloned == false)
        #expect(repository.status == .notCloned)
        #expect(repository.hasLocalOnlyWork == false)
    }

    @Test("reports the last sync failure ahead of the working tree state")
    func reportsFailureFirst() {
        let repository = RepositoryFixtures.tracked(
            snapshot: RepositoryFixtures.snapshot(),
            outcome: RepositoryFixtures.failure()
        )

        #expect(repository.status == .failed)
    }

    @Test("derives the badge from the snapshot", arguments: [
        (RepositoryFixtures.snapshot(ahead: 1, behind: 1), RepositoryStatus.diverged),
        (RepositoryFixtures.snapshot(tracked: [GitFileChange(path: "A.swift", status: .modified)]), .dirty),
        (RepositoryFixtures.snapshot(ahead: 2), .ahead),
        (RepositoryFixtures.snapshot(behind: 2), .behind),
        (RepositoryFixtures.snapshot(), .clean)
    ])
    func derivesStatus(snapshot: GitRepositorySnapshot, expected: RepositoryStatus) {
        #expect(RepositoryFixtures.tracked(snapshot: snapshot).status == expected)
    }

    @Test("reports a repository it could not read rather than calling it clean")
    func reportsUnreadable() {
        let repository = RepositoryFixtures.tracked(snapshot: nil, readError: .commandFailed("broken"))

        #expect(repository.status == .unreadable)
    }

    @Test("counts an untracked-only working tree as work that exists only on this Mac")
    func countsUntrackedAsLocalOnly() {
        let repository = RepositoryFixtures.tracked(snapshot: RepositoryFixtures.snapshot(untracked: ["Notes.md"]))

        #expect(repository.hasLocalOnlyWork)
    }

    @Test("counts an unpushed side branch as work that exists only on this Mac")
    func countsSideBranchAsLocalOnly() {
        let branches = [GitBranchRef(name: "spike", upstream: nil, aheadCount: 0, behindCount: 0)]
        let repository = RepositoryFixtures.tracked(snapshot: RepositoryFixtures.snapshot(branches: branches))

        #expect(repository.hasLocalOnlyWork)
    }

    @Test("counts a fully pushed repository as having nothing left on this Mac")
    func countsSyncedAsShared() {
        let branches = [GitBranchRef(name: "main", upstream: "origin/main", aheadCount: 0, behindCount: 0)]
        let repository = RepositoryFixtures.tracked(snapshot: RepositoryFixtures.snapshot(branches: branches))

        #expect(repository.hasLocalOnlyWork == false)
    }
}
