import Foundation

struct FileSystemDerivedDataProvider: @unchecked Sendable, DerivedDataProviding {
    // MARK: - Private

    private let fileManager: FileManager
    private let defaultDerivedDataURL: URL

    // MARK: - Init

    init(fileManager: FileManager, defaultDerivedDataURL: URL) {
        self.fileManager = fileManager
        self.defaultDerivedDataURL = defaultDerivedDataURL
    }

    // MARK: - DerivedDataProviding

    @concurrent
    func entries(
        includesDefaultLocation: Bool,
        projectRoots: [URL],
        customPaths: [URL]
    ) async -> [DerivedDataEntry] {
        var entries: [DerivedDataEntry] = []

        if includesDefaultLocation {
            entries.append(contentsOf: children(of: defaultDerivedDataURL, source: .defaultLocation))
        }

        for root in projectRoots {
            let candidate = root.appending(path: "DerivedData")

            guard isDirectory(candidate) else {
                continue
            }

            entries.append(entry(at: candidate, source: .projectSpecific))
        }

        for path in customPaths where isDirectory(path) {
            entries.append(entry(at: path, source: .custom))
        }

        return entries.sorted { $0.sizeBytes > $1.sizeBytes }
    }

    @concurrent
    func remove(at url: URL) async throws(CleanupError) {
        let path = url.path(percentEncoded: false)

        guard CleanupSafetyUseCase.isDeletable(path: path) else {
            throw .protectedLocation(path)
        }

        do {
            try fileManager.removeItem(at: url)
        } catch {
            throw CleanupError.removalFailed(error.localizedDescription)
        }
    }

    // MARK: - Helpers

    private func children(of directory: URL, source: DerivedDataEntry.Source) -> [DerivedDataEntry] {
        guard let contents = try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        return contents.filter(isDirectory).map { entry(at: $0, source: source) }
    }

    private func entry(at url: URL, source: DerivedDataEntry.Source) -> DerivedDataEntry {
        DerivedDataEntry(url: url, name: url.lastPathComponent, sizeBytes: size(of: url), source: source)
    }

    private func size(of url: URL) -> Int64 {
        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: [.totalFileAllocatedSizeKey, .fileAllocatedSizeKey],
            options: []
        ) else {
            return 0
        }

        var total: Int64 = 0

        for case let child as URL in enumerator {
            let values = try? child.resourceValues(forKeys: [.totalFileAllocatedSizeKey, .fileAllocatedSizeKey])
            let bytes = values?.totalFileAllocatedSize ?? values?.fileAllocatedSize ?? 0
            total += Int64(bytes)
        }

        return total
    }

    private func isDirectory(_ url: URL) -> Bool {
        (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
    }
}
