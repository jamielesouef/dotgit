import Foundation

@MainActor
protocol SharedWorkspaceStoring: AnyObject {
    func loadRepositories() throws(PersistenceError) -> [WorkspaceRepository]
    func upsert(_ repository: WorkspaceRepository) throws(PersistenceError)
    func remove(identifier: String) throws(PersistenceError)
    func removeDuplicates() throws(PersistenceError) -> [String]
    func removeAllRepositories() throws(PersistenceError)
    func loadPreferences() throws(PersistenceError) -> AppPreferences
    func save(_ preferences: AppPreferences) throws(PersistenceError)
}

extension SharedWorkspaceStoring {
    func repository(identifier: String) throws(PersistenceError) -> WorkspaceRepository? {
        try loadRepositories().first { $0.identifier == identifier }
    }
}
