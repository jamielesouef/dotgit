import Foundation
import Testing
@testable import dotgit

@Suite("RepositorySortUseCase", .tags(.domain))
struct RepositorySortUseCaseTests {
    // MARK: - Private

    private let alpha = RepositoryFixtures.tracked(
        "a",
        name: "Alpha",
        path: "/z/alpha",
        snapshot: RepositoryFixtures.snapshot(ahead: 1),
        lastSynced: Date(timeIntervalSince1970: 100)
    )
    private let beta = RepositoryFixtures.tracked(
        "b",
        name: "beta",
        path: "/a/beta",
        snapshot: RepositoryFixtures.snapshot(tracked: [GitFileChange(path: "A", status: .modified)]),
        lastSynced: Date(timeIntervalSince1970: 300)
    )
    private let gamma = RepositoryFixtures.tracked(
        "c",
        name: "Gamma",
        path: "/m/gamma",
        snapshot: RepositoryFixtures.snapshot()
    )

    private var all: [TrackedRepository] {
        [gamma, alpha, beta]
    }

    // MARK: - Tests

    @Test("sorts by name without letting case decide the order")
    func sortsByName() {
        #expect(RepositorySortUseCase.sorted(all, by: .name).map(\.name) == ["Alpha", "beta", "Gamma"])
    }

    @Test("sorts by local path")
    func sortsByPath() {
        #expect(RepositorySortUseCase.sorted(all, by: .path).map(\.name) == ["beta", "Gamma", "Alpha"])
    }

    @Test("sorts the most recently synced first and never-synced last")
    func sortsByLastSynced() {
        #expect(RepositorySortUseCase.sorted(all, by: .lastSynced).map(\.name) == ["beta", "Alpha", "Gamma"])
    }

    @Test("sorts the repositories needing attention above the settled ones")
    func sortsByStatus() {
        #expect(RepositorySortUseCase.sorted(all, by: .status).map(\.name) == ["beta", "Alpha", "Gamma"])
    }
}
