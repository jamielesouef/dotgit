import Foundation

protocol RepositoryDiscovering: Sendable {
    func discoverRepositories(
        in root: URL,
        ignoredFolderNames: Set<String>,
        maximumDepth: Int
    ) async -> [DiscoveredRepository]
}
