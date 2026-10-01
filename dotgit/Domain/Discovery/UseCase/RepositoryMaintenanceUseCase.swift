import Foundation

enum RepositoryMaintenanceUseCase {
    static func staleLocalPathIdentifiers(
        repositoryPaths: [String: String],
        existsOnDisk: (String) -> Bool
    ) -> [String] {
        repositoryPaths
            .filter { existsOnDisk($0.value) == false }
            .keys
            .sorted()
    }

    static func duplicateIdentifiers(in repositories: [WorkspaceRepository]) -> [String] {
        var seen: Set<String> = []
        var duplicates: [String] = []

        for repository in repositories where seen.insert(repository.identifier).inserted == false {
            duplicates.append(repository.identifier)
        }

        return duplicates
    }

    static func deduplicated(_ discovered: [DiscoveredRepository]) -> [DiscoveredRepository] {
        var seen: Set<String> = []

        return discovered.filter { seen.insert($0.url.standardizedFileURL.path(percentEncoded: false)).inserted }
    }

    static func merged(
        existing: WorkspaceRepository?,
        identifier: String,
        discovered: DiscoveredRepository,
        remoteURL: String?,
        addedDate: Date
    ) -> WorkspaceRepository {
        guard var repository = existing else {
            return WorkspaceRepository(
                identifier: identifier,
                name: discovered.name,
                remoteURL: remoteURL,
                preferredRelativePath: discovered.name,
                addedDate: addedDate
            )
        }

        repository.name = discovered.name
        repository.remoteURL = remoteURL ?? repository.remoteURL

        return repository
    }
}
