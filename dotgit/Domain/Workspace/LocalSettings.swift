import Foundation

struct LocalSettings: Equatable, Codable {
    var workspaceRootPath: String?
    var gitPath: String
    var gitHubCLIPath: String
    var preferredOpenApplicationPath: String?
    var showsMenuBarItem: Bool
    var keepsRunningInMenuBarOnClose: Bool
    var includesDefaultDerivedData: Bool
    var additionalDerivedDataPaths: [String]
    var manifestPath: String?
    var defaultCleanupCategories: [CleanupCategory]
    var repositoryPaths: [String: String]
    var hasCompletedOnboarding: Bool

    static let `default` = LocalSettings(
        workspaceRootPath: nil,
        gitPath: "/usr/bin/git",
        gitHubCLIPath: "/opt/homebrew/bin/gh",
        preferredOpenApplicationPath: nil,
        showsMenuBarItem: true,
        keepsRunningInMenuBarOnClose: true,
        includesDefaultDerivedData: true,
        additionalDerivedDataPaths: [],
        manifestPath: nil,
        defaultCleanupCategories: CleanupCategory.allCases,
        repositoryPaths: [:],
        hasCompletedOnboarding: false
    )

    func path(for identifier: String) -> URL? {
        guard let path = repositoryPaths[identifier] else {
            return nil
        }

        return URL(filePath: path)
    }

    var workspaceRoot: URL? {
        guard let workspaceRootPath else {
            return nil
        }

        return URL(filePath: workspaceRootPath)
    }
}
