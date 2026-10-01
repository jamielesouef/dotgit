import Foundation
@testable import dotgit

@MainActor
final class StubSharedWorkspaceStore: SharedWorkspaceStoring {
    // MARK: - State

    var repositories: [WorkspaceRepository] = []
    var preferences: AppPreferences = .default
    var loadFailure: PersistenceError?
    private(set) var savedPreferences: [AppPreferences] = []
    private(set) var removedIdentifiers: [String] = []
    private(set) var clearedAllCount = 0

    // MARK: - Init

    init(repositories: [WorkspaceRepository] = [], preferences: AppPreferences = .default) {
        self.repositories = repositories
        self.preferences = preferences
    }

    // MARK: - SharedWorkspaceStoring

    func loadRepositories() throws(PersistenceError) -> [WorkspaceRepository] {
        if let loadFailure {
            throw loadFailure
        }

        return repositories
    }

    func upsert(_ repository: WorkspaceRepository) throws(PersistenceError) {
        guard let index = repositories.firstIndex(where: { $0.identifier == repository.identifier }) else {
            repositories.append(repository)
            return
        }

        repositories[index] = repository
    }

    func remove(identifier: String) throws(PersistenceError) {
        guard repositories.contains(where: { $0.identifier == identifier }) else {
            throw .recordMissing(identifier)
        }

        removedIdentifiers.append(identifier)
        repositories.removeAll { $0.identifier == identifier }
    }

    func removeDuplicates() throws(PersistenceError) -> [String] {
        var seen: Set<String> = []
        var removed: [String] = []
        var kept: [WorkspaceRepository] = []

        for repository in repositories {
            guard seen.insert(repository.identifier).inserted else {
                removed.append(repository.identifier)
                continue
            }

            kept.append(repository)
        }

        repositories = kept

        return removed
    }

    func removeAllRepositories() throws(PersistenceError) {
        clearedAllCount += 1
        repositories = []
    }

    func loadPreferences() throws(PersistenceError) -> AppPreferences {
        if let loadFailure {
            throw loadFailure
        }

        return preferences
    }

    func save(_ preferences: AppPreferences) throws(PersistenceError) {
        self.preferences = preferences
        savedPreferences.append(preferences)
    }
}
