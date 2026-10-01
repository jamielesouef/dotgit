import Foundation
import Testing
@testable import dotgit

@Suite("SettingsService", .tags(.service))
struct SettingsServiceTests {
    @Test("loads the shared preferences and this Mac's settings on creation")
    @MainActor
    func loadsBothStores() {
        let harness = ServiceHarness()
        harness.sharedStore.preferences.wipCommitPrefix = "PARKED"

        let settings = SettingsService(sharedStore: harness.sharedStore, localStore: harness.localStore)

        #expect(settings.preferences.wipCommitPrefix == "PARKED")
        #expect(settings.localSettings == .default)
    }

    @Test("writes a changed preference through to the shared store")
    @MainActor
    func writesPreferencesThrough() {
        let harness = ServiceHarness()

        harness.settings.updatePreferences { $0.requiresSyncConfirmation = false }

        #expect(harness.sharedStore.savedPreferences.last?.requiresSyncConfirmation == false)
    }

    @Test("writes a changed machine setting to the local store only")
    @MainActor
    func writesLocalSettingsThrough() {
        let harness = ServiceHarness()

        harness.settings.updateLocalSettings { $0.workspaceRootPath = "/Users/jamie/Developer" }

        #expect(harness.localStore.settings.workspaceRootPath == "/Users/jamie/Developer")
        #expect(harness.sharedStore.savedPreferences.isEmpty)
    }

    @Test("does not write when nothing actually changed")
    @MainActor
    func skipsUnchangedWrites() {
        let harness = ServiceHarness()

        harness.settings.updatePreferences { $0.wipCommitPrefix = AppPreferences.default.wipCommitPrefix }

        #expect(harness.sharedStore.savedPreferences.isEmpty)
    }

    @Test("keeps a repository's local path out of the shared store")
    @MainActor
    func keepsPathsLocal() {
        let harness = ServiceHarness()

        harness.settings.recordLocalPath(URL(filePath: "/dev/app"), for: "app")

        #expect(harness.localStore.settings.repositoryPaths["app"] == "/dev/app")

        harness.settings.removeLocalPath(for: "app")

        #expect(harness.localStore.settings.repositoryPaths.isEmpty)
    }

    @Test("surfaces a shared store failure instead of losing it")
    @MainActor
    func surfacesStoreFailure() {
        let harness = ServiceHarness()
        harness.sharedStore.loadFailure = .fetchFailed("iCloud unavailable")

        harness.settings.reload()

        #expect(harness.settings.lastError == .fetchFailed("iCloud unavailable"))
    }

    // MARK: - Reset to fresh install

    @Test("clears every shared repository")
    @MainActor
    func resetClearsSharedRepositories() {
        let harness = ServiceHarness()
        harness.sharedStore.repositories = [RepositoryFixtures.shared("a"), RepositoryFixtures.shared("b", name: "b")]

        harness.settings.resetToFreshInstall()

        #expect(harness.sharedStore.repositories.isEmpty)
        #expect(harness.sharedStore.clearedAllCount == 1)
    }

    @Test("resets the shared preferences back to their defaults")
    @MainActor
    func resetRestoresDefaultPreferences() {
        let harness = ServiceHarness()
        harness.settings.updatePreferences { $0.wipCommitPrefix = "PARKED" }

        harness.settings.resetToFreshInstall()

        #expect(harness.settings.preferences == .default)
        #expect(harness.sharedStore.preferences == .default)
    }

    @Test("resets this Mac's settings back to their defaults, including onboarding")
    @MainActor
    func resetRestoresDefaultLocalSettings() {
        let harness = ServiceHarness()
        harness.settings.updateLocalSettings { local in
            local.workspaceRootPath = "/dev"
            local.hasCompletedOnboarding = true
            local.repositoryPaths["a"] = "/dev/a"
        }

        harness.settings.resetToFreshInstall()

        #expect(harness.settings.localSettings == .default)
        #expect(harness.localStore.resetCount == 1)
    }
}
