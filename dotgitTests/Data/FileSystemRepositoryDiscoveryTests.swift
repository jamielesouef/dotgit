import Foundation
import Testing
@testable import dotgit

@Suite("FileSystemRepositoryDiscovery", .tags(.data))
struct FileSystemRepositoryDiscoveryTests {
    // MARK: - Private

    private let fileManager = FileManager.default

    private func makeTree(_ build: (URL) throws -> Void) throws -> URL {
        let root = URL(filePath: NSTemporaryDirectory()).appending(path: "dotgit-discovery-\(UUID().uuidString)")
        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
        try build(root)

        return root
    }

    private func makeRepository(at url: URL) throws {
        try fileManager.createDirectory(at: url.appending(path: ".git"), withIntermediateDirectories: true)
    }

    private func names(_ found: [DiscoveredRepository]) -> [String] {
        found.map(\.name).sorted()
    }

    // MARK: - Tests

    @Test("finds repositories nested below the scanned folder")
    func findsNestedRepositories() async throws {
        let root = try makeTree { root in
            try makeRepository(at: root.appending(path: "one"))
            try makeRepository(at: root.appending(path: "group/two"))
        }
        defer { try? fileManager.removeItem(at: root) }

        let found = await FileSystemRepositoryDiscovery(fileManager: fileManager)
            .discoverRepositories(in: root, ignoredFolderNames: [], maximumDepth: 5)

        #expect(names(found) == ["one", "two"])
    }

    @Test("stops at the repository instead of walking into its working tree")
    func stopsAtRepositoryBoundary() async throws {
        let root = try makeTree { root in
            let outer = root.appending(path: "outer")
            try makeRepository(at: outer)
            try makeRepository(at: outer.appending(path: "Vendor/inner"))
        }
        defer { try? fileManager.removeItem(at: root) }

        let found = await FileSystemRepositoryDiscovery(fileManager: fileManager)
            .discoverRepositories(in: root, ignoredFolderNames: [], maximumDepth: 5)

        #expect(names(found) == ["outer"])
    }

    @Test("skips the configured ignored folder names")
    func skipsIgnoredFolders() async throws {
        let root = try makeTree { root in
            try makeRepository(at: root.appending(path: "keep"))
            try makeRepository(at: root.appending(path: "node_modules/skip"))
        }
        defer { try? fileManager.removeItem(at: root) }

        let found = await FileSystemRepositoryDiscovery(fileManager: fileManager)
            .discoverRepositories(in: root, ignoredFolderNames: ["node_modules"], maximumDepth: 5)

        #expect(names(found) == ["keep"])
    }

    @Test("respects a .gitignore encountered on the way down")
    func respectsGitignore() async throws {
        let root = try makeTree { root in
            try "Archive/\n".write(to: root.appending(path: ".gitignore"), atomically: true, encoding: .utf8)
            try makeRepository(at: root.appending(path: "keep"))
            try makeRepository(at: root.appending(path: "Archive/old"))
        }
        defer { try? fileManager.removeItem(at: root) }

        let found = await FileSystemRepositoryDiscovery(fileManager: fileManager)
            .discoverRepositories(in: root, ignoredFolderNames: [], maximumDepth: 5)

        #expect(names(found) == ["keep"])
    }

    @Test("stops descending at the requested depth")
    func honoursMaximumDepth() async throws {
        let root = try makeTree { root in
            try makeRepository(at: root.appending(path: "a/b/c/deep"))
        }
        defer { try? fileManager.removeItem(at: root) }

        let found = await FileSystemRepositoryDiscovery(fileManager: fileManager)
            .discoverRepositories(in: root, ignoredFolderNames: [], maximumDepth: 2)

        #expect(found.isEmpty)
    }
}
