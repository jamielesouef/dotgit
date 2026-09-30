import Foundation
import SwiftData
import Testing
@testable import homerun_app

@Suite("SwiftDataWorkspaceStore", .tags(.persistence))
struct SwiftDataWorkspaceStoreTests {
    // MARK: - Private

    @MainActor
    private func makeStore() throws -> SwiftDataWorkspaceStore {
        let container = try ModelContainerFactory.make(inMemory: true, cloudKitContainerIdentifier: nil)

        return SwiftDataWorkspaceStore(context: ModelContext(container))
    }

    private func makeRepository(_ identifier: String, name: String = "App") -> WorkspaceRepository {
        WorkspaceRepository(identifier: identifier, name: name, remoteURL: "git@github.com:acme/\(name).git")
    }

    // MARK: - Repositories

    @Test("round-trips every shared field of a workspace repository")
    @MainActor
    func roundTripsFields() throws {
        let store = try makeStore()
        var repository = makeRepository("remote:github.com/acme/app")
        repository.allowsMainBranchSync = true
        repository.wipCommitPrefixOverride = "SCRATCH"
        repository.preferredGitHubAccount = "acme-bot"
        repository.requiredEnvironmentVariableNames = ["API_HOST"]
        repository.expectedConfigurationTemplates = [".env.example"]
        repository.handoff = RepositoryHandoff(branch: "feature/login", commit: "abc123", recordedAt: .distantFuture)

        try store.upsert(repository)

        #expect(try store.loadRepositories() == [repository])
    }

    @Test("preserves existing settings when the same repository is added again")
    @MainActor
    func preservesSettingsOnReAdd() throws {
        let store = try makeStore()
        var repository = makeRepository("remote:github.com/acme/app")
        repository.wipCommitPrefixOverride = "SCRATCH"
        try store.upsert(repository)

        repository.name = "App Renamed"
        try store.upsert(repository)

        let loaded = try store.loadRepositories()
        #expect(loaded.count == 1)
        #expect(loaded.first?.wipCommitPrefixOverride == "SCRATCH")
        #expect(loaded.first?.name == "App Renamed")
    }

    @Test("removing a shared entry leaves the other entries in place")
    @MainActor
    func removesOneEntry() throws {
        let store = try makeStore()
        try store.upsert(makeRepository("a", name: "A"))
        try store.upsert(makeRepository("b", name: "B"))

        try store.remove(identifier: "a")

        #expect(try store.loadRepositories().map(\.identifier) == ["b"])
    }

    @Test("reports a missing record rather than silently succeeding")
    @MainActor
    func reportsMissingRecord() throws {
        let store = try makeStore()

        #expect(throws: PersistenceError.recordMissing("ghost")) {
            try store.remove(identifier: "ghost")
        }
    }

    @Test("clearing tracked repositories empties the shared workspace")
    @MainActor
    func clearsAll() throws {
        let store = try makeStore()
        try store.upsert(makeRepository("a", name: "A"))
        try store.upsert(makeRepository("b", name: "B"))

        try store.removeAllRepositories()

        #expect(try store.loadRepositories().isEmpty)
    }

    // MARK: - Preferences

    @Test("returns the default preferences before anything has been saved")
    @MainActor
    func returnsDefaultPreferences() throws {
        let store = try makeStore()

        #expect(try store.loadPreferences() == .default)
        #expect(try store.loadPreferences().includesUntrackedFilesByDefault == false)
        #expect(try store.loadPreferences().asksBeforeCreatingUpstream)
    }

    @Test("round-trips changed preferences")
    @MainActor
    func roundTripsPreferences() throws {
        let store = try makeStore()
        var preferences = AppPreferences.default
        preferences.wipCommitPrefix = "PARKED"
        preferences.requiresSyncConfirmation = false
        preferences.includesUntrackedFilesByDefault = true
        preferences.asksBeforeCreatingUpstream = false
        preferences.defaultRepositoryStatusFilter = .dirty
        preferences.ignoredFolderNames = ["Pods"]

        try store.save(preferences)

        #expect(try store.loadPreferences() == preferences)
    }
}
