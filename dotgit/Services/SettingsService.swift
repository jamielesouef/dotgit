import Foundation

@MainActor
@Observable
final class SettingsService {
    // MARK: - State

    private(set) var preferences: AppPreferences
    private(set) var localSettings: LocalSettings
    private(set) var lastError: PersistenceError?

    // MARK: - Private

    private let sharedStore: any SharedWorkspaceStoring
    private let localStore: any LocalSettingsStoring

    // MARK: - Init

    init(sharedStore: any SharedWorkspaceStoring, localStore: any LocalSettingsStoring) {
        self.sharedStore = sharedStore
        self.localStore = localStore
        localSettings = localStore.load()
        preferences = (try? sharedStore.loadPreferences()) ?? .default
    }

    // MARK: - Intent

    func reload() {
        localSettings = localStore.load()

        do {
            preferences = try sharedStore.loadPreferences()
            lastError = nil
        } catch {
            lastError = error
        }
    }

    func updatePreferences(_ mutate: (inout AppPreferences) -> Void) {
        var updated = preferences
        mutate(&updated)

        guard updated != preferences else {
            return
        }

        preferences = updated

        do {
            try sharedStore.save(updated)
            lastError = nil
        } catch {
            lastError = error
        }
    }

    func updateLocalSettings(_ mutate: (inout LocalSettings) -> Void) {
        var updated = localSettings
        mutate(&updated)

        guard updated != localSettings else {
            return
        }

        localSettings = updated
        localStore.save(updated)
    }

    func recordLocalPath(_ url: URL, for identifier: String) {
        updateLocalSettings { settings in
            settings.repositoryPaths[identifier] = url.standardizedFileURL.path(percentEncoded: false)
        }
    }

    func removeLocalPath(for identifier: String) {
        updateLocalSettings { settings in
            settings.repositoryPaths.removeValue(forKey: identifier)
        }
    }

    // MARK: - Debug

    func resetToFreshInstall() {
        do {
            try sharedStore.removeAllRepositories()
            lastError = nil
        } catch {
            lastError = error
        }

        preferences = .default

        do {
            try sharedStore.save(preferences)
        } catch {
            lastError = error
        }

        localStore.reset()
        localSettings = localStore.load()
    }
}
