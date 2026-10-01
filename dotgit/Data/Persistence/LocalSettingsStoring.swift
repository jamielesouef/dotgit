import Foundation

@MainActor
protocol LocalSettingsStoring: AnyObject {
    func load() -> LocalSettings
    func save(_ settings: LocalSettings)
    func reset()
}
