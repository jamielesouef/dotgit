import Foundation

@MainActor
final class UserDefaultsLocalSettingsStore: LocalSettingsStoring {
    // MARK: - Constants

    private enum Constants {
        static let key = "mobi.jamie.dotgit.localSettings"
    }

    // MARK: - Private

    private let defaults: UserDefaults
    private let defaultSettings: LocalSettings

    // MARK: - Init

    init(defaults: UserDefaults, defaultSettings: LocalSettings) {
        self.defaults = defaults
        self.defaultSettings = defaultSettings
    }

    // MARK: - LocalSettingsStoring

    func load() -> LocalSettings {
        guard let data = defaults.data(forKey: Constants.key),
              let decoded = try? JSONDecoder().decode(LocalSettings.self, from: data)
        else {
            return defaultSettings
        }

        return decoded
    }

    func save(_ settings: LocalSettings) {
        guard let data = try? JSONEncoder().encode(settings) else {
            AppLog.error("Unable to encode local settings")
            return
        }

        defaults.set(data, forKey: Constants.key)
    }

    func reset() {
        defaults.removeObject(forKey: Constants.key)
    }
}
