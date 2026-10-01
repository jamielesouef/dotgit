import Foundation
import Testing
@testable import dotgit

@Suite("RepositoriesService loading", .tags(.service))
struct RepositoriesServiceLoadingTests {
    @Test("reports an empty shared workspace rather than a loading state that never ends")
    @MainActor
    func reportsEmptyWorkspace() async {
        let harness = ServiceHarness()

        await harness.repositories.start()

        #expect(harness.repositories.loadState == .empty)
    }

    @Test("joins the shared entry to this Mac's checkout and its snapshot")
    @MainActor
    func joinsSharedAndLocal() async {
        let harness = ServiceHarness()
        await harness.addRepository("a", name: "app", snapshot: RepositoryFixtures.snapshot(ahead: 2))

        await harness.repositories.start()

        #expect(harness.repositories.repositories.first?.status == .ahead)
        #expect(harness.repositories.repositories.first?.isCloned == true)
    }

    @Test("treats a shared entry with no checkout here as not cloned, keeping it in the workspace")
    @MainActor
    func keepsUnclonedEntries() async {
        let harness = ServiceHarness()
        harness.addUnclonedRepository("a", name: "app")

        await harness.repositories.start()

        #expect(harness.repositories.repositories.first?.status == .notCloned)
        #expect(harness.sharedStore.repositories.count == 1)
    }

    @Test("records a repository it could not read rather than dropping it")
    @MainActor
    func recordsUnreadableRepository() async {
        let harness = ServiceHarness()
        await harness.addRepository("a", name: "app", snapshot: nil)

        await harness.repositories.start()

        #expect(harness.repositories.repositories.first?.status == .unreadable)
    }

    @Test("reports which repositories it is reading while the workspace loads")
    @MainActor
    func reportsReadingProgress() async {
        let harness = ServiceHarness()
        await harness.addRepository("a", name: "app", snapshot: RepositoryFixtures.snapshot())
        await harness.addRepository("b", name: "web", snapshot: RepositoryFixtures.snapshot())
        await harness.gitClient.holdSnapshots()

        let starting = Task { await harness.repositories.start() }
        await harness.gitClient.waitUntilSnapshotRequested()

        #expect(
            harness.repositories.loadState ==
                .loading(RepositoryLoadProgress(total: 2, completed: 0, reading: ["app", "web"]))
        )

        await harness.gitClient.releaseSnapshots()
        await starting.value

        #expect(harness.repositories.repositories.map(\.name) == ["app", "web"])
    }

    @Test("keeps the workspace order when more repositories load than are read at once")
    @MainActor
    func keepsOrderWhenReadingConcurrently() async {
        let harness = ServiceHarness()
        let names = (0 ..< AppConstants.concurrentRepositoryReads * 2 + 1).map { "repo\($0)" }

        for name in names {
            await harness.addRepository(name, name: name, snapshot: RepositoryFixtures.snapshot())
        }

        await harness.repositories.start()

        #expect(harness.repositories.repositories.map(\.name) == names)
        #expect(harness.repositories.repositories.allSatisfy { $0.status == .clean })
    }

    @Test("surfaces a shared store failure")
    @MainActor
    func surfacesStoreFailure() async {
        let harness = ServiceHarness()
        harness.sharedStore.loadFailure = .fetchFailed("offline")

        await harness.repositories.start()

        #expect(harness.repositories.loadState == .error(.fetchFailed("offline")))
    }
}
