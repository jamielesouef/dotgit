import Foundation
import Testing
@testable import dotgit

@Suite("WorkspaceManifest", .tags(.domain))
struct WorkspaceManifestTests {
    @Test("carries the shared settings of each repository and leaves machine-specific paths out")
    func carriesSharedSettingsOnly() throws {
        var repository = RepositoryFixtures.shared()
        repository.setupInstructionsPath = "SETUP.md"
        repository.requiredEnvironmentVariableNames = ["API_HOST"]

        let manifest = WorkspaceManifest.make(name: "Work", repositories: [repository])
        let encoded = try FileWorkspaceManifestStore.makeEncoder().encode(manifest)
        let json = try #require(String(data: encoded, encoding: .utf8))

        #expect(json.contains("setup_instructions_path"))
        #expect(json.contains("required_environment_variable_names"))
        #expect(json.contains("/Users/") == false)
        #expect(json.contains("last_successful_sync_date") == false)
    }

    @Test("round-trips through the production coder")
    func roundTrips() throws {
        let manifest = WorkspaceManifest.make(name: "Work", repositories: [RepositoryFixtures.shared()])
        let data = try FileWorkspaceManifestStore.makeEncoder().encode(manifest)

        #expect(try FileWorkspaceManifestStore.makeDecoder().decode(WorkspaceManifest.self, from: data) == manifest)
    }

    @Test("reads a manifest written before the timestamp flag existed without losing the local value")
    func readsManifestMissingTheTimestampFlag() throws {
        let json = """
        {
          "version": 1,
          "name": "Work",
          "repositories": [
            {
              "identifier": "a",
              "name": "app",
              "preferred_relative_path": "app",
              "allows_main_branch_sync": false,
              "allows_master_branch_sync": false,
              "required_environment_variable_names": [],
              "expected_configuration_templates": []
            }
          ]
        }
        """
        let data = try #require(json.data(using: .utf8))
        let manifest = try FileWorkspaceManifestStore.makeDecoder().decode(WorkspaceManifest.self, from: data)
        let entry = try #require(manifest.repositories.first)

        var existing = RepositoryFixtures.shared("a")
        existing.omitsTimestampFromWIPCommit = true

        #expect(entry.merged(into: existing, addedDate: .distantPast).omitsTimestampFromWIPCommit)
    }

    @Test("carries the timestamp flag to another Mac once it is set")
    func carriesTheTimestampFlag() throws {
        var repository = RepositoryFixtures.shared()
        repository.omitsTimestampFromWIPCommit = true

        let manifest = WorkspaceManifest.make(name: "Work", repositories: [repository])
        let data = try FileWorkspaceManifestStore.makeEncoder().encode(manifest)
        let decoded = try FileWorkspaceManifestStore.makeDecoder().decode(WorkspaceManifest.self, from: data)

        #expect(decoded.repositories.first?.omitsTimestampFromWIPCommit == true)
    }

    @Test("rejects a manifest written by a newer build")
    func rejectsNewerVersion() {
        let manifest = WorkspaceManifest(version: WorkspaceManifest.currentVersion + 1, name: "Work", repositories: [])

        #expect(manifest.isSupportedVersion == false)
    }

    @Test("keeps the local settings of a repository the manifest already knows")
    func keepsLocalSettingsOnMerge() {
        var existing = RepositoryFixtures.shared()
        existing.lastSuccessfulSyncDate = .distantFuture
        existing.handoff = RepositoryHandoff(branch: "feature/login", commit: "abc", recordedAt: .distantPast)
        let entry = WorkspaceManifestEntry(RepositoryFixtures.shared(name: "renamed"))

        let merged = entry.merged(into: existing, addedDate: .distantPast)

        #expect(merged.lastSuccessfulSyncDate == .distantFuture)
        #expect(merged.handoff?.branch == "feature/login")
        #expect(merged.name == "renamed")
    }

    @Test("falls back to the repository name when no preferred relative path is set")
    func fallsBackToName() {
        var repository = RepositoryFixtures.shared(name: "app")
        repository.preferredRelativePath = ""

        #expect(WorkspaceManifestEntry(repository).preferredRelativePath == "app")
    }
}

@Suite("WorkspacePlanUseCase", .tags(.domain))
struct WorkspacePlanUseCaseTests {
    // MARK: - Private

    private let root = URL(filePath: "/Users/jamie/Developer")

    private func manifest(_ repositories: [WorkspaceRepository]) -> WorkspaceManifest {
        WorkspaceManifest.make(name: "Work", repositories: repositories)
    }

    // MARK: - Tests

    @Test("previews which repositories will be cloned and which are already here")
    func previewsCloneAndUpdate() {
        var second = RepositoryFixtures.shared("b", name: "other")
        second.preferredRelativePath = "nested/other"

        let plan = WorkspacePlanUseCase.plan(
            manifest: manifest([RepositoryFixtures.shared("a", name: "app"), second]),
            workspaceRoot: root,
            localPaths: ["a": "/Users/jamie/elsewhere/app"]
        )

        #expect(plan.updateCount == 1)
        #expect(plan.cloneCount == 1)
        #expect(plan.entries.last?.action == .clone(URL(filePath: "/Users/jamie/Developer/nested/other")))
    }

    @Test("supports a different workspace root on each Mac")
    func supportsDifferentRoots() {
        let repositories = [RepositoryFixtures.shared("a", name: "app")]
        let first = WorkspacePlanUseCase.plan(manifest: manifest(repositories), workspaceRoot: root, localPaths: [:])
        let second = WorkspacePlanUseCase.plan(
            manifest: manifest(repositories),
            workspaceRoot: URL(filePath: "/Volumes/Work/code"),
            localPaths: [:]
        )

        #expect(first.entries.first?.action == .clone(URL(filePath: "/Users/jamie/Developer/app")))
        #expect(second.entries.first?.action == .clone(URL(filePath: "/Volumes/Work/code/app")))
    }

    @Test("blocks cloning until this Mac has a workspace root")
    func blocksWithoutWorkspaceRoot() {
        let plan = WorkspacePlanUseCase.plan(
            manifest: manifest([RepositoryFixtures.shared("a", name: "app")]),
            workspaceRoot: nil,
            localPaths: [:]
        )

        #expect(plan.blockedEntries.first?.action == .noWorkspaceRoot)
    }

    @Test("blocks an entry the manifest records no remote for")
    func blocksWithoutRemote() {
        var repository = RepositoryFixtures.shared("a", name: "app")
        repository.remoteURL = nil

        let plan = WorkspacePlanUseCase.plan(manifest: manifest([repository]), workspaceRoot: root, localPaths: [:])

        #expect(plan.blockedEntries.first?.action == .noRemote)
    }
}
