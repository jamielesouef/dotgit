import Foundation
import Testing
@testable import dotgit

@Suite("CleanerService set-to-value intents", .tags(.service))
struct CleanerServiceIntentTests {
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

    @Test("selecting an item twice leaves it selected")
    @MainActor
    func selectingTwiceKeepsSelection() async {
        let harness = ServiceHarness()
        await harness.runtimeProvider.setRuntimes([runtime])
        let service = harness.makeCleaner()
        await service.start()

        guard let item = service.items.first else {
            Issue.record("expected an item")
            return
        }

        service.setSelected(true, for: item)
        service.setSelected(true, for: item)

        #expect(service.isSelected(item))
    }

    @Test("deselecting an item clears it from the plan")
    @MainActor
    func deselectingClearsPlan() async {
        let harness = ServiceHarness()
        await harness.runtimeProvider.setRuntimes([runtime])
        let service = harness.makeCleaner()
        await service.start()

        guard let item = service.items.first else {
            Issue.record("expected an item")
            return
        }

        service.setSelected(true, for: item)
        service.setSelected(false, for: item)

        #expect(service.plan.isEmpty)
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

        service.setSelected(true, for: item)

        #expect(service.isSelected(item) == false)
    }

    @Test("applying a category that is already on does not rescan")
    @MainActor
    func applyingUnchangedCategoryDoesNotRescan() async {
        let harness = ServiceHarness()
        await harness.runtimeProvider.setRuntimes([runtime])
        let service = harness.makeCleaner()
        await service.start()
        await harness.runtimeProvider.setRuntimes([])

        await service.applyCategory(.simulatorRuntimes, isEnabled: true)

        #expect(service.items.map(\.category) == [.simulatorRuntimes])
    }

    @Test("applying a category that changed rescans")
    @MainActor
    func applyingChangedCategoryRescans() async {
        let harness = ServiceHarness()
        await harness.runtimeProvider.setRuntimes([runtime])
        await harness.derivedDataProvider.setEntries([derived])
        let service = harness.makeCleaner()
        await service.start()

        await service.applyCategory(.simulatorRuntimes, isEnabled: false)

        #expect(service.items.map(\.category) == [.derivedData])
    }
}
