import Foundation
import Testing
@testable import dotgit

@Suite("RepositoryFilterUseCase", .tags(.domain))
struct RepositoryFilterUseCaseTests {
    // MARK: - Private

    private let dirty = RepositoryFixtures.tracked(
        "dirty",
        name: "dirty",
        snapshot: RepositoryFixtures.snapshot(tracked: [GitFileChange(path: "A.swift", status: .modified)])
    )
    private let clean = RepositoryFixtures.tracked("clean", name: "clean", snapshot: RepositoryFixtures.snapshot())
    private let ahead = RepositoryFixtures.tracked(
        "ahead",
        name: "ahead",
        snapshot: RepositoryFixtures.snapshot(ahead: 3)
    )
    private let behind = RepositoryFixtures.tracked(
        "behind",
        name: "behind",
        snapshot: RepositoryFixtures.snapshot(behind: 3)
    )
    private let failed = RepositoryFixtures.tracked(
        "failed",
        name: "failed",
        snapshot: RepositoryFixtures.snapshot(),
        outcome: RepositoryFixtures.failure("failed")
    )

    private var all: [TrackedRepository] {
        [dirty, clean, ahead, behind, failed]
    }

    // MARK: - matches

    @Test("keeps only the repositories the chosen status describes", arguments: [
        (RepositoryStatusFilter.dirty, ["dirty"]),
        (.clean, ["clean"]),
        (.ahead, ["ahead"]),
        (.behind, ["behind"]),
        (.failed, ["failed"])
    ])
    func filtersByStatus(filter: RepositoryStatusFilter, expected: [String]) {
        let result = RepositoryFilterUseCase.apply(
            to: all,
            filter: filter,
            showsCleanRepositories: true,
            searchText: ""
        )

        #expect(result.map(\.name) == expected)
    }

    @Test("keeps everything under the all filter")
    func keepsEverything() {
        let result = RepositoryFilterUseCase.apply(to: all, filter: .all, showsCleanRepositories: true, searchText: "")

        #expect(result.count == all.count)
    }

    @Test("hides fully synced repositories when the dashboard asks it to")
    func hidesCleanRepositories() {
        let result = RepositoryFilterUseCase.apply(to: all, filter: .all, showsCleanRepositories: false, searchText: "")

        #expect(result.map(\.name).contains("clean") == false)
        #expect(result.count == all.count - 1)
    }

    @Test("narrows by name regardless of case")
    func narrowsBySearch() {
        let result = RepositoryFilterUseCase.apply(
            to: all,
            filter: .all,
            showsCleanRepositories: true,
            searchText: " DIRT "
        )

        #expect(result.map(\.name) == ["dirty"])
    }

    @Test("treats an unreadable repository as failed so it is not lost")
    func treatsUnreadableAsFailed() {
        let unreadable = RepositoryFixtures.tracked("u", name: "u", readError: .commandFailed("broken"))
        let result = RepositoryFilterUseCase.apply(
            to: [unreadable],
            filter: .failed,
            showsCleanRepositories: true,
            searchText: ""
        )

        #expect(result.count == 1)
    }
}
