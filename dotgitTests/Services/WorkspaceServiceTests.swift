import Foundation
import Testing
@testable import dotgit

@Suite("WorkspaceService", .tags(.service))
struct WorkspaceServiceTests {
    // MARK: - Private

    private let manifestURL = URL(filePath: "/dev/workspace.json")

    private func manifest(_ repositories: [WorkspaceRepository]) -> WorkspaceManifest {
        WorkspaceManifest.make(name: "Work", repositories: repositories)
    }

    // MARK: - Tests

    @Test("previews which repositories a manifest would clone on this Mac")
    @MainActor
    func previewsManifest() async {
        let harness = ServiceHarness()
        harness.settings.updateLocalSettings { $0.workspaceRootPath = "/dev" }
        await harness.manifestStore.setManifest(
            manifest([RepositoryFixtures.shared("a", name: "app")]),
            at: manifestURL
        )

        let service = harness.makeWorkspace()

        await service.loadManifest(at: manifestURL)

        #expect(service.plan?.cloneCount == 1)
        #expect(service.loadedManifest?.name == "Work")
    }

    @Test("remembers which manifest this Mac uses")
    @MainActor
    func remembersSelectedManifest() async {
        let harness = ServiceHarness()
        await harness.manifestStore.setManifest(manifest([]), at: manifestURL)
        let service = harness.makeWorkspace()

        await service.loadManifest(at: manifestURL)

        #expect(harness.localStore.settings.manifestPath == "/dev/workspace.json")
    }

    @Test("re-previews when this Mac's workspace root changes")
    @MainActor
    func repreviewsOnRootChange() async {
        let harness = ServiceHarness()
        await harness.manifestStore.setManifest(
            manifest([RepositoryFixtures.shared("a", name: "app")]),
            at: manifestURL
        )

        let service = harness.makeWorkspace()
        await service.loadManifest(at: manifestURL)

        #expect(service.plan?.blockedEntries.first?.action == .noWorkspaceRoot)

        service.setWorkspaceRoot(URL(filePath: "/Volumes/Work"))

        #expect(service.plan?.entries.first?.action == .clone(URL(filePath: "/Volumes/Work/app")))
    }

    @Test("surfaces a manifest it cannot use instead of silently ignoring it")
    @MainActor
    func surfacesManifestError() async {
        let harness = ServiceHarness()
        await harness.manifestStore.setLoadError(.unsupportedVersion(99))
        let service = harness.makeWorkspace()

        await service.loadManifest(at: manifestURL)

        #expect(service.loadState == .error(.unsupportedVersion(99)))
    }

    @Test("applying a manifest adds its repositories to the shared workspace")
    @MainActor
    func appliesManifest() async {
        let harness = ServiceHarness()
        await harness.manifestStore.setManifest(
            manifest([RepositoryFixtures.shared("a", name: "app"), RepositoryFixtures.shared("b", name: "other")]),
            at: manifestURL
        )

        let service = harness.makeWorkspace()
        await service.loadManifest(at: manifestURL)

        await service.applyManifest()

        #expect(harness.sharedStore.repositories.map(\.identifier).sorted() == ["a", "b"])
    }

    @Test("applying a manifest keeps a repository's sync history and handoff")
    @MainActor
    func keepsHistoryOnApply() async {
        let harness = ServiceHarness()
        var existing = RepositoryFixtures.shared("a", name: "app")
        existing.lastSuccessfulSyncDate = Date(timeIntervalSince1970: 400)
        harness.sharedStore.repositories = [existing]
        await harness.manifestStore.setManifest(
            manifest([RepositoryFixtures.shared("a", name: "renamed")]),
            at: manifestURL
        )

        let service = harness.makeWorkspace()
        await service.loadManifest(at: manifestURL)

        await service.applyManifest()

        #expect(harness.sharedStore.repositories.first?.lastSuccessfulSyncDate == Date(timeIntervalSince1970: 400))
        #expect(harness.sharedStore.repositories.first?.name == "renamed")
    }

    @Test("writes a manifest from the shared workspace")
    @MainActor
    func exportsManifest() async {
        let harness = ServiceHarness()
        harness.sharedStore.repositories = [RepositoryFixtures.shared("a", name: "app")]
        let service = harness.makeWorkspace()

        await service.exportManifest(named: "Work", to: manifestURL)

        #expect(await harness.manifestStore.saved.first?.manifest.repositories.map(\.identifier) == ["a"])
        #expect(service.loadedManifest?.name == "Work")
    }

    @Test("stores a preferred relative path in the shared workspace, not on this Mac")
    @MainActor
    func storesPreferredRelativePath() async {
        let harness = ServiceHarness()
        harness.sharedStore.repositories = [RepositoryFixtures.shared("a", name: "app")]
        await harness.repositories.start()
        let service = harness.makeWorkspace()

        service.setPreferredRelativePath("clients/app", for: "a")

        #expect(harness.sharedStore.repositories.first?.preferredRelativePath == "clients/app")
        #expect(harness.localStore.settings.repositoryPaths.isEmpty)
    }
}
