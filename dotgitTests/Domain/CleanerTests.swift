import Foundation
import Testing
@testable import dotgit

@Suite("CleanupSafetyUseCase", .tags(.domain))
struct CleanupSafetyUseCaseTests {
    @Test("refuses anything inside an Xcode installation", arguments: [
        "/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform",
        "/Applications/Xcode-beta.app/Contents/Developer",
        "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk",
        "/Library/Developer/SDKs/MacOSX.sdk"
    ])
    func refusesXcodePaths(path: String) {
        #expect(CleanupSafetyUseCase.isDeletable(path: path) == false)
    }

    @Test("refuses the root of the file system")
    func refusesRoot() {
        #expect(CleanupSafetyUseCase.isDeletable(path: "/") == false)
        #expect(CleanupSafetyUseCase.isDeletable(path: "") == false)
    }

    @Test("allows a Derived Data folder")
    func allowsDerivedData() {
        #expect(CleanupSafetyUseCase.isDeletable(path: "/Users/jamie/Library/Developer/Xcode/DerivedData/app-abc"))
    }

    @Test("allows a downloaded simulator runtime image")
    func allowsRuntimeImage() {
        let runtime = SimulatorRuntime(
            identifier: "A",
            name: "iOS 18.0",
            version: "18.0",
            build: "22A",
            sizeBytes: 1,
            isDeletable: true,
            path: "/Library/Developer/CoreSimulator/Images/abc.dmg"
        )

        #expect(CleanupSafetyUseCase.isDeletable(runtime))
    }

    @Test("refuses a runtime simctl says is bundled with Xcode")
    func refusesBundledRuntime() {
        let runtime = SimulatorRuntime(
            identifier: "A",
            name: "iOS 18.0",
            version: "18.0",
            build: "22A",
            sizeBytes: 1,
            isDeletable: false,
            path: nil
        )

        #expect(CleanupSafetyUseCase.isDeletable(runtime) == false)
    }
}

@Suite("CleanupPlanUseCase", .tags(.domain))
struct CleanupPlanUseCaseTests {
    // MARK: - Private

    private let runtime = SimulatorRuntime(
        identifier: "R1",
        name: "iOS 18.0",
        version: "18.0",
        build: "22A",
        sizeBytes: 7_000_000_000,
        isDeletable: true,
        path: "/Library/Developer/CoreSimulator/Images/abc.dmg"
    )
    private let derived = DerivedDataEntry(
        url: URL(filePath: "/Users/jamie/Library/Developer/Xcode/DerivedData/app-abc"),
        name: "app-abc",
        sizeBytes: 3_000_000_000,
        source: .defaultLocation
    )

    // MARK: - Tests

    @Test("shows only the categories the review asked for")
    func showsChosenCategoriesOnly() {
        let items = CleanupPlanUseCase.items(runtimes: [runtime], derivedData: [derived], categories: [.derivedData])

        #expect(items.map(\.category) == [.derivedData])
    }

    @Test("shows the exact items and the space they would recover")
    func showsExactItemsAndSize() {
        let plan = CleanupPlanUseCase.plan(
            runtimes: [runtime],
            derivedData: [derived],
            categories: [.simulatorRuntimes, .derivedData],
            selectedIdentifiers: ["runtime:R1", "derived:/Users/jamie/Library/Developer/Xcode/DerivedData/app-abc"]
        )

        #expect(plan.items.count == 2)
        #expect(plan.totalBytes == 10_000_000_000)
        #expect(plan.formattedTotal.isEmpty == false)
    }

    @Test("includes only what was selected")
    func includesSelectionOnly() {
        let plan = CleanupPlanUseCase.plan(
            runtimes: [runtime],
            derivedData: [derived],
            categories: [.simulatorRuntimes, .derivedData],
            selectedIdentifiers: ["runtime:R1"]
        )

        #expect(plan.items.map(\.id) == ["runtime:R1"])
        #expect(plan.totalBytes == 7_000_000_000)
    }

    @Test("marks an item dotgit refuses to delete")
    func marksProtectedItem() {
        let bundled = SimulatorRuntime(
            identifier: "R2",
            name: "iOS 17.0",
            version: "17.0",
            build: "21A",
            sizeBytes: 1,
            isDeletable: false,
            path: nil
        )

        let items = CleanupPlanUseCase.items(runtimes: [bundled], derivedData: [], categories: [.simulatorRuntimes])

        #expect(items.first?.isDeletable == false)
    }
}

@Suite("SimulatorRuntimeParser", .tags(.data))
struct SimulatorRuntimeParserTests {
    private let json = """
    {
      "A1": {
        "build": "22A3351",
        "deletable": true,
        "name": "iOS 18.0",
        "path": "/Library/Developer/CoreSimulator/Images/A1.dmg",
        "runtimeIdentifier": "com.apple.CoreSimulator.SimRuntime.iOS-18-0",
        "sizeBytes": 7000000000,
        "version": "18.0"
      },
      "B2": {
        "build": "21F79",
        "deletable": false,
        "name": "iOS 17.5",
        "sizeBytes": 1000,
        "version": "17.5"
      }
    }
    """

    @Test("reads the storage each installed runtime uses")
    func readsSizes() {
        let runtimes = SimulatorRuntimeParser.parse(json)

        #expect(runtimes.map(\.sizeBytes) == [7_000_000_000, 1000])
    }

    @Test("keeps whether simctl considers the runtime removable")
    func keepsDeletableFlag() {
        let runtimes = SimulatorRuntimeParser.parse(json)

        #expect(runtimes.first?.isDeletable == true)
        #expect(runtimes.last?.isDeletable == false)
    }

    @Test("returns nothing for output it cannot read")
    func handlesUnreadableOutput() {
        #expect(SimulatorRuntimeParser.parse("not json").isEmpty)
    }
}
