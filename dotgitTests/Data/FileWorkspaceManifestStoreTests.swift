import Foundation
import Testing
@testable import dotgit

@Suite("FileWorkspaceManifestStore", .tags(.data))
struct FileWorkspaceManifestStoreTests {
    // MARK: - Private

    private func temporaryURL() -> URL {
        URL(filePath: NSTemporaryDirectory()).appending(path: "dotgit-manifest-\(UUID().uuidString).json")
    }

    // MARK: - Tests

    @Test("writes a manifest another Mac can read back")
    func roundTripsToDisk() async throws {
        let url = temporaryURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let store = FileWorkspaceManifestStore()
        let manifest = WorkspaceManifest.make(name: "Work", repositories: [RepositoryFixtures.shared()])

        try await store.save(manifest, to: url)

        #expect(try await store.load(from: url) == manifest)
    }

    @Test("reports a manifest that is not there")
    func reportsMissingFile() async {
        let url = temporaryURL()

        await #expect(throws: WorkspaceManifestError.fileUnreadable(url.path(percentEncoded: false))) {
            try await FileWorkspaceManifestStore().load(from: url)
        }
    }

    @Test("refuses a manifest written by a newer build rather than guessing")
    func refusesNewerVersion() async throws {
        let url = temporaryURL()
        defer { try? FileManager.default.removeItem(at: url) }
        try #"{"version": 99, "name": "Work", "repositories": []}"#.write(to: url, atomically: true, encoding: .utf8)

        await #expect(throws: WorkspaceManifestError.unsupportedVersion(99)) {
            try await FileWorkspaceManifestStore().load(from: url)
        }
    }

    @Test("reports a manifest it cannot parse")
    func reportsMalformedManifest() async throws {
        let url = temporaryURL()
        defer { try? FileManager.default.removeItem(at: url) }
        try "not json".write(to: url, atomically: true, encoding: .utf8)

        await #expect(throws: WorkspaceManifestError.self) {
            try await FileWorkspaceManifestStore().load(from: url)
        }
    }
}
