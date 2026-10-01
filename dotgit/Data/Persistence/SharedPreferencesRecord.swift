import Foundation
import SwiftData

@Model
final class SharedPreferencesRecord {
    var defaultRepositoryStatusFilterRaw: String = RepositoryStatusFilter.all.rawValue
    var showsCleanRepositories: Bool = true
    var requiresSyncConfirmation: Bool = true
    var includesUntrackedFilesByDefault: Bool = false
    var asksBeforeCreatingUpstream: Bool = true
    var wipCommitPrefix: String = AppPreferences.fallbackWIPCommitPrefix
    var appendsTimestampToWIPCommit: Bool = true
    var repositorySortOrderRaw: String = RepositorySortOrder.name.rawValue
    var ignoredFolderNames: [String] = AppPreferences.defaultIgnoredFolderNames
    var accountFallbackEnabled: Bool = true
    var accountAccessChecksEnabled: Bool = false
    var preselectsSafeFastForward: Bool = true
    var offersToOpenProjectAfterResume: Bool = true
    var menuBarShowsLocalOnlyCount: Bool = true

    init() {}

    // MARK: - Domain

    var domainValue: AppPreferences {
        AppPreferences(
            defaultRepositoryStatusFilter: RepositoryStatusFilter(rawValue: defaultRepositoryStatusFilterRaw) ?? .all,
            showsCleanRepositories: showsCleanRepositories,
            requiresSyncConfirmation: requiresSyncConfirmation,
            includesUntrackedFilesByDefault: includesUntrackedFilesByDefault,
            asksBeforeCreatingUpstream: asksBeforeCreatingUpstream,
            wipCommitPrefix: wipCommitPrefix,
            appendsTimestampToWIPCommit: appendsTimestampToWIPCommit,
            repositorySortOrder: RepositorySortOrder(rawValue: repositorySortOrderRaw) ?? .name,
            ignoredFolderNames: ignoredFolderNames,
            accountFallbackEnabled: accountFallbackEnabled,
            accountAccessChecksEnabled: accountAccessChecksEnabled,
            preselectsSafeFastForward: preselectsSafeFastForward,
            offersToOpenProjectAfterResume: offersToOpenProjectAfterResume,
            menuBarShowsLocalOnlyCount: menuBarShowsLocalOnlyCount
        )
    }

    func apply(_ preferences: AppPreferences) {
        defaultRepositoryStatusFilterRaw = preferences.defaultRepositoryStatusFilter.rawValue
        showsCleanRepositories = preferences.showsCleanRepositories
        requiresSyncConfirmation = preferences.requiresSyncConfirmation
        includesUntrackedFilesByDefault = preferences.includesUntrackedFilesByDefault
        asksBeforeCreatingUpstream = preferences.asksBeforeCreatingUpstream
        wipCommitPrefix = preferences.wipCommitPrefix
        appendsTimestampToWIPCommit = preferences.appendsTimestampToWIPCommit
        repositorySortOrderRaw = preferences.repositorySortOrder.rawValue
        ignoredFolderNames = preferences.ignoredFolderNames
        accountFallbackEnabled = preferences.accountFallbackEnabled
        accountAccessChecksEnabled = preferences.accountAccessChecksEnabled
        preselectsSafeFastForward = preferences.preselectsSafeFastForward
        offersToOpenProjectAfterResume = preferences.offersToOpenProjectAfterResume
        menuBarShowsLocalOnlyCount = preferences.menuBarShowsLocalOnlyCount
    }
}
