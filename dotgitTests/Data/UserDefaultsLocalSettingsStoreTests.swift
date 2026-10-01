import Foundation
import Testing
@testable import dotgit

@Suite("UserDefaultsLocalSettingsStore", .tags(.persistence))
struct UserDefaultsLocalSettingsStoreTests {
    // MARK: - Private

    @MainActor
    private func makeStore() throws -> (UserDefaultsLocalSettingsStore, UserDefaults) {
        let name = "dotgit.tests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: name))

        return (UserDefaultsLocalSettingsStore(defaults: defaults, defaultSettings: .default), defaults)
    }

    // MARK: - Tests

    @Test("returns the supplied defaults on a Mac that has never been configured")
    @MainActor
    func returnsDefaults() throws {
        let (store, _) = try makeStore()

        #expect(store.load() == .default)
    }

    @Test("keeps this Mac's workspace root and repository paths out of the shared store")
    @MainActor
    func roundTripsMachineLocalPaths() throws {
        let (store, _) = try makeStore()
        var settings = LocalSettings.default
        settings.workspaceRootPath = "/Users/jamie/Developer"
        settings.repositoryPaths = ["remote:github.com/acme/app": "/Users/jamie/Developer/app"]
        settings.preferredOpenApplicationPath = "/Applications/Xcode.app"

        store.save(settings)

        let loaded = store.load()
        #expect(loaded.workspaceRoot == URL(filePath: "/Users/jamie/Developer"))
        #expect(loaded.path(for: "remote:github.com/acme/app") == URL(filePath: "/Users/jamie/Developer/app"))
        #expect(loaded.preferredOpenApplicationPath == "/Applications/Xcode.app")
    }

    @Test("reports no local path for a repository this Mac has not cloned")
    @MainActor
    func reportsNoPathWhenNotCloned() throws {
        let (store, _) = try makeStore()

        #expect(store.load().path(for: "remote:github.com/acme/app") == nil)
    }
}
