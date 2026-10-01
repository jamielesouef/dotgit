import Foundation

struct ToolPathResolver: @unchecked Sendable {
    // MARK: - Private

    private let fileManager: FileManager
    private let searchDirectories: [String]

    // MARK: - Init

    init(fileManager: FileManager, searchDirectories: [String]) {
        self.fileManager = fileManager
        self.searchDirectories = searchDirectories
    }

    // MARK: - Resolution

    func resolve(_ toolName: String, preferring configuredPath: String?) -> String? {
        if let configuredPath, isExecutable(configuredPath) {
            return configuredPath
        }

        for directory in searchDirectories {
            let candidate = "\(directory)/\(toolName)"

            guard isExecutable(candidate) else {
                continue
            }

            return candidate
        }

        return nil
    }

    // MARK: - Helpers

    private func isExecutable(_ path: String) -> Bool {
        fileManager.isExecutableFile(atPath: path)
    }
}
