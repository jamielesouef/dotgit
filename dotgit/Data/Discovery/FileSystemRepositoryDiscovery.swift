import Foundation

struct FileSystemRepositoryDiscovery: @unchecked Sendable, RepositoryDiscovering {
    // MARK: - Private

    private let fileManager: FileManager

    // MARK: - Init

    init(fileManager: FileManager) {
        self.fileManager = fileManager
    }

    // MARK: - RepositoryDiscovering

    @concurrent
    func discoverRepositories(
        in root: URL,
        ignoredFolderNames: Set<String>,
        maximumDepth: Int
    ) async -> [DiscoveredRepository] {
        var found: [DiscoveredRepository] = []
        let options = ScanOptions(maximumDepth: maximumDepth, ignoredFolderNames: ignoredFolderNames)

        scan(
            directory: root.standardizedFileURL,
            depth: 0,
            options: options,
            inheritedRules: .empty,
            found: &found
        )

        return RepositoryMaintenanceUseCase.deduplicated(found)
    }

    // MARK: - Helpers

    private struct ScanOptions {
        let maximumDepth: Int
        let ignoredFolderNames: Set<String>
    }

    private func scan(
        directory: URL,
        depth: Int,
        options: ScanOptions,
        inheritedRules: GitIgnoreRules,
        found: inout [DiscoveredRepository]
    ) {
        guard depth <= options.maximumDepth, Task.isCancelled == false else {
            return
        }
        guard isDirectory(directory) else {
            return
        }
        guard containsGitDirectory(directory) == false else {
            if isLinkedWorktree(directory) == false {
                found.append(DiscoveredRepository(url: directory))
            }

            return
        }

        let rules = inheritedRules.merging(loadRules(in: directory))

        guard let children = try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return
        }

        for child in children.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
            let name = child.lastPathComponent

            guard options.ignoredFolderNames.contains(name) == false else {
                continue
            }
            guard isDirectory(child), isSymbolicLink(child) == false else {
                continue
            }
            guard rules.ignores(name: name, isDirectory: true) == false else {
                continue
            }

            scan(
                directory: child,
                depth: depth + 1,
                options: options,
                inheritedRules: rules,
                found: &found
            )
        }
    }

    private func containsGitDirectory(_ url: URL) -> Bool {
        fileManager.fileExists(atPath: url.appending(path: ".git").path(percentEncoded: false))
    }

    private func isLinkedWorktree(_ url: URL) -> Bool {
        guard let contents = try? String(contentsOf: url.appending(path: ".git"), encoding: .utf8) else {
            return false
        }

        return GitWorktreeParser.isLinkedWorktreePointer(contents)
    }

    private func loadRules(in directory: URL) -> GitIgnoreRules {
        let url = directory.appending(path: ".gitignore")

        guard let contents = try? String(contentsOf: url, encoding: .utf8) else {
            return .empty
        }

        return GitIgnoreRules.parse(contents)
    }

    private func isDirectory(_ url: URL) -> Bool {
        (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
    }

    private func isSymbolicLink(_ url: URL) -> Bool {
        (try? url.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink) == true
    }
}
