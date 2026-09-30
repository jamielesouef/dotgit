import Foundation

struct AppPreferences: Equatable, Codable {
    var defaultRepositoryStatusFilter: RepositoryStatusFilter
    var showsCleanRepositories: Bool
    var requiresSyncConfirmation: Bool
    var includesUntrackedFilesByDefault: Bool
    var asksBeforeCreatingUpstream: Bool
    var wipCommitPrefix: String
    var appendsTimestampToWIPCommit: Bool
    var repositorySortOrder: RepositorySortOrder
    var ignoredFolderNames: [String]
    var accountFallbackEnabled: Bool
    var accountAccessChecksEnabled: Bool
    var preselectsSafeFastForward: Bool
    var offersToOpenProjectAfterResume: Bool
    var menuBarShowsLocalOnlyCount: Bool

    static let fallbackWIPCommitPrefix = "WIP"

    static let defaultIgnoredFolderNames = [
        ".build",
        "DerivedData",
        "Pods",
        "node_modules",
        "vendor",
        ".swiftpm",
        "Carthage"
    ]

    static let `default` = AppPreferences(
        defaultRepositoryStatusFilter: .all,
        showsCleanRepositories: true,
        requiresSyncConfirmation: true,
        includesUntrackedFilesByDefault: false,
        asksBeforeCreatingUpstream: true,
        wipCommitPrefix: fallbackWIPCommitPrefix,
        appendsTimestampToWIPCommit: true,
        repositorySortOrder: .name,
        ignoredFolderNames: defaultIgnoredFolderNames,
        accountFallbackEnabled: true,
        accountAccessChecksEnabled: false,
        preselectsSafeFastForward: true,
        offersToOpenProjectAfterResume: true,
        menuBarShowsLocalOnlyCount: true
    )
}
