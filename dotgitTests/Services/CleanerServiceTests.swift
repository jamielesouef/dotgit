import Foundation
import Testing
@testable import dotgit

@Suite("CleanerService", .tags(.service))
struct CleanerServiceTests {
    // MARK: - Private

    private var runtime: SimulatorRuntime {
        SimulatorRuntime(
            identifier: "R1",
            name: "iOS 18.0",
            version: "18.0",
            build: "22A",
            sizeBytes: 7_000_000_000,
            isDeletable: true,
            path: "/Library/Developer/CoreSimulator/Images/abc.dmg"
        )
    }

    private var bundledRuntime: SimulatorRuntime {
        SimulatorRuntime(
            identifier: "R2",
            name: "iOS 17.0",
            version: "17.0",
            build: "21A",
            sizeBytes: 1,
            isDeletable: false,
            path: nil
        )
    }

    private var derived: DerivedDataEntry {
        DerivedDataEntry(
            url: URL(filePath: "/Users/jamie/Library/Developer/Xcode/DerivedData/app-abc"),
            name: "app-abc",
            sizeBytes: 3_000_000_000,
            source: .defaultLocation
        )
    }

    // MARK: - Tests

    @Test("shows the storage used by runtimes and Derived Data")
    @MainActor
    func showsStorage() async {
        let harness = ServiceHarness()
        await harness.runtimeProvider.setRuntimes([runtime])
        await harness.derivedDataProvider.setEntries([derived])
        let service = harness.makeCleaner()

        await service.start()

        #expect(service.items.count == 2)
        #expect(service.loadState == .loaded(service.items))
    }

    @Test("shows only the categories the settings chose")
    @MainActor
    func showsChosenCategories() async {
        let harness = ServiceHarness()
        harness.settings.updateLocalSettings { $0.defaultCleanupCategories = [.derivedData] }
        await harness.runtimeProvider.setRuntimes([runtime])
        await harness.derivedDataProvider.setEntries([derived])
        let service = harness.makeCleaner()

        await service.start()

        #expect(service.items.map(\.category) == [.derivedData])
    }

    @Test("passes this Mac's Derived Data preferences to the provider")
    @MainActor
    func passesDerivedDataPreferences() async {
        let harness = ServiceHarness()
        await harness.addRepository("a", name: "app", snapshot: RepositoryFixtures.snapshot())
        await harness.repositories.start()
        harness.settings.updateLocalSettings { $0.includesDefaultDerivedData = false }
        let service = harness.makeCleaner()

        await service.start()

        #expect(await harness.derivedDataProvider.lastIncludesDefault == false)
        #expect(await harness.derivedDataProvider.lastProjectRoots.count == 1)
    }

    @Test("shows nothing selected until the review chooses items")
    @MainActor
    func startsWithNothingSelected() async {
        let harness = ServiceHarness()
        await harness.runtimeProvider.setRuntimes([runtime])
        let service = harness.makeCleaner()
        await service.start()

        #expect(service.plan.isEmpty)
        #expect(service.plan.totalBytes == 0)
    }

    @Test("shows the space the selected items would recover")
    @MainActor
    func showsSelectedSize() async {
        let harness = ServiceHarness()
        await harness.runtimeProvider.setRuntimes([runtime])
        await harness.derivedDataProvider.setEntries([derived])
        let service = harness.makeCleaner()
        await service.start()

        for item in service.items {
            service.toggle(item)
        }

        #expect(service.plan.totalBytes == 10_000_000_000)
    }

    @Test("will not select an item it refuses to delete")
    @MainActor
    func refusesToSelectProtectedItem() async {
        let harness = ServiceHarness()
        await harness.runtimeProvider.setRuntimes([bundledRuntime])
        let service = harness.makeCleaner()
        await service.start()

        guard let item = service.items.first else {
            Issue.record("expected an item")
            return
        }

        service.toggle(item)

        #expect(service.isSelected(item) == false)
    }

    @Test("removes runtimes through simctl and Derived Data through the file system")
    @MainActor
    func removesEachTargetCorrectly() async {
        let harness = ServiceHarness()
        await harness.runtimeProvider.setRuntimes([runtime])
        await harness.derivedDataProvider.setEntries([derived])
        let service = harness.makeCleaner()
        await service.start()

        for item in service.items {
            service.toggle(item)
        }

        await service.removeSelected()

        #expect(await harness.runtimeProvider.deleted == ["R1"])
        #expect(await harness.derivedDataProvider.removed == [derived.url])
        #expect(service.lastOutcomes.contains { $0.succeeded == false } == false)
    }

    @Test("reports a removal that failed")
    @MainActor
    func reportsRemovalFailure() async {
        let harness = ServiceHarness()
        await harness.runtimeProvider.setRuntimes([runtime])
        await harness.runtimeProvider.setDeleteFailures(["R1"])
        let service = harness.makeCleaner()
        await service.start()

        guard let item = service.items.first else {
            Issue.record("expected an item")
            return
        }

        service.toggle(item)
        await service.removeSelected()

        #expect(service.lastOutcomes.first?.succeeded == false)
    }

    @Test("removes nothing when nothing is selected")
    @MainActor
    func removesNothingWithoutSelection() async {
        let harness = ServiceHarness()
        await harness.runtimeProvider.setRuntimes([runtime])
        let service = harness.makeCleaner()
        await service.start()

        await service.removeSelected()

        #expect(await harness.runtimeProvider.deleted.isEmpty)
    }

    @Test("turning a category off removes it from the review")
    @MainActor
    func turningOffCategoryHidesIt() async {
        let harness = ServiceHarness()
        await harness.runtimeProvider.setRuntimes([runtime])
        await harness.derivedDataProvider.setEntries([derived])
        let service = harness.makeCleaner()
        await service.start()

        service.setCategory(.simulatorRuntimes, isEnabled: false)

        #expect(service.items.map(\.category) == [.derivedData])
    }
}
