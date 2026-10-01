import Foundation
import Testing
@testable import dotgit

@Suite("SimctlRuntimeProvider", .tags(.data))
struct SimctlRuntimeProviderTests {
    @Test("asks simctl for the installed runtimes as JSON")
    func asksSimctlForJSON() async {
        let runner = StubCommandRunner()
        await runner.stub(
            ["simctl", "runtime", "list"],
            output: #"{"A1":{"name":"iOS 18.0","sizeBytes":5,"deletable":true}}"#
        )

        let runtimes = await SimctlRuntimeProvider(commandRunner: runner, xcrunPath: "/usr/bin/xcrun").runtimes()

        #expect(runtimes.map(\.name) == ["iOS 18.0"])
        #expect(await runner.containsArguments(["simctl", "runtime", "list", "--json"]))
    }

    @Test("removes a runtime through simctl rather than the file system")
    func removesThroughSimctl() async throws {
        let runner = StubCommandRunner()

        try await SimctlRuntimeProvider(commandRunner: runner, xcrunPath: "/usr/bin/xcrun").delete(identifier: "A1")

        #expect(await runner.argumentLists == [["simctl", "runtime", "delete", "A1"]])
    }

    @Test("reports what simctl said when a removal fails")
    func reportsRemovalFailure() async {
        let runner = StubCommandRunner()
        await runner.stub(["simctl", "runtime", "delete"], exitCode: 1, error: "runtime in use")

        await #expect(throws: CleanupError.removalFailed("runtime in use")) {
            try await SimctlRuntimeProvider(commandRunner: runner, xcrunPath: "/usr/bin/xcrun").delete(identifier: "A1")
        }
    }
}

@Suite("FileSystemDerivedDataProvider", .tags(.data))
struct FileSystemDerivedDataProviderTests {
    // MARK: - Private

    private let fileManager = FileManager.default

    private func makeRoot() throws -> URL {
        let root = URL(filePath: NSTemporaryDirectory()).appending(path: "dotgit-derived-\(UUID().uuidString)")
        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)

        return root
    }

    private func makeFolder(_ url: URL, bytes: Int) throws {
        try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        try Data(repeating: 0, count: bytes).write(to: url.appending(path: "payload.bin"))
    }

    // MARK: - Tests

    @Test("measures the default location, project folders and custom paths separately")
    func measuresEachSource() async throws {
        let root = try makeRoot()
        defer { try? fileManager.removeItem(at: root) }
        let defaultLocation = root.appending(path: "DefaultDerivedData")
        try makeFolder(defaultLocation.appending(path: "app-abc"), bytes: 2048)
        let project = root.appending(path: "project")
        try makeFolder(project.appending(path: "DerivedData"), bytes: 1024)
        let custom = root.appending(path: "custom")
        try makeFolder(custom, bytes: 512)

        let entries = await FileSystemDerivedDataProvider(
            fileManager: fileManager,
            defaultDerivedDataURL: defaultLocation
        )
        .entries(includesDefaultLocation: true, projectRoots: [project], customPaths: [custom])

        #expect(entries.map(\.source) == [.defaultLocation, .projectSpecific, .custom])
        #expect(entries.allSatisfy { $0.sizeBytes > 0 })
    }

    @Test("leaves the default location out when the settings exclude it")
    func excludesDefaultLocation() async throws {
        let root = try makeRoot()
        defer { try? fileManager.removeItem(at: root) }
        let defaultLocation = root.appending(path: "DefaultDerivedData")
        try makeFolder(defaultLocation.appending(path: "app-abc"), bytes: 2048)

        let entries = await FileSystemDerivedDataProvider(
            fileManager: fileManager,
            defaultDerivedDataURL: defaultLocation
        )
        .entries(includesDefaultLocation: false, projectRoots: [], customPaths: [])

        #expect(entries.isEmpty)
    }

    @Test("removes a selected Derived Data folder")
    func removesFolder() async throws {
        let root = try makeRoot()
        defer { try? fileManager.removeItem(at: root) }
        let folder = root.appending(path: "app-abc")
        try makeFolder(folder, bytes: 16)

        try await FileSystemDerivedDataProvider(fileManager: fileManager, defaultDerivedDataURL: root)
            .remove(at: folder)

        #expect(fileManager.fileExists(atPath: folder.path(percentEncoded: false)) == false)
    }

    @Test("refuses to remove anything inside an Xcode installation")
    func refusesXcodeInstallation() async {
        let url = URL(filePath: "/Applications/Xcode.app/Contents/Developer/Platforms")

        await #expect(throws: CleanupError.protectedLocation(url.path(percentEncoded: false))) {
            try await FileSystemDerivedDataProvider(fileManager: FileManager.default, defaultDerivedDataURL: url)
                .remove(at: url)
        }
    }
}
