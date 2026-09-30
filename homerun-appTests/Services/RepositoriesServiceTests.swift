import Foundation
import Testing
@testable import homerun_app

@Suite("RepositoriesService", .tags(.service))
struct RepositoriesServiceTests {
    // MARK: - Filtering

    @Test("starts on the default filter and sort order from the shared preferences")
    @MainActor
    func startsFromPreferences() {
        let harness = ServiceHarness()
        harness.sharedStore.preferences.defaultRepositoryStatusFilter = .dirty
        harness.sharedStore.preferences.repositorySortOrder = .lastSynced
        let settings = SettingsService(sharedStore: harness.sharedStore, localStore: harness.localStore)

        let service = RepositoriesService(
            sharedStore: harness.sharedStore,
            gitClient: harness.gitClient,
            discovery: harness.discovery,
            readinessChecker: harness.readinessChecker,
            sshHostResolver: harness.sshHostResolver,
            fileManager: .default,
            clock: harness.clock,
            settings: settings
        )

        #expect(service.filter == .dirty)
        #expect(service.sortOrder == .lastSynced)
    }

    @Test("hides clean repositories when the preference says to")
    @MainActor
    func hidesCleanRepositories() async {
        let harness = ServiceHarness()
        await harness.addRepository("a", name: "clean", snapshot: RepositoryFixtures.snapshot())
        await harness.addRepository("b", name: "dirty", snapshot: RepositoryFixtures.snapshot(untracked: ["A"]))
        await harness.repositories.start()

        harness.settings.updatePreferences { $0.showsCleanRepositories = false }

        #expect(harness.repositories.visibleRepositories.map(\.name) == ["dirty"])
    }

    // MARK: - Discovery

    @Test("scans with the configured ignored folder names")
    @MainActor
    func scansWithIgnoredFolders() async {
        let harness = ServiceHarness()
        harness.settings.updatePreferences { $0.ignoredFolderNames = ["Pods"] }

        _ = await harness.repositories.scanFolder(URL(filePath: "/dev"))

        #expect(await harness.discovery.ignoredFolderNames == ["Pods"])
    }

    @Test("offers to search a folder that is not itself a git repository")
    @MainActor
    func offersToSearchNonRepository() async {
        let harness = ServiceHarness()
        let folder = URL(filePath: "/dev/not-a-repo")

        let outcome = await harness.repositories.addRepository(at: folder)

        #expect(outcome == .notARepository(folder))
        #expect(harness.repositories.folderAwaitingScanDecision == folder)
        #expect(harness.sharedStore.repositories.isEmpty)
    }

    @Test("adds a folder that is a git repository without asking to search it")
    @MainActor
    func addsRepositoryWithoutAsking() async {
        let harness = ServiceHarness()
        let directory = harness.makeDirectory("app")
        await harness.gitClient.setSnapshot(RepositoryFixtures.snapshot(), at: directory)

        let outcome = await harness.repositories.addRepository(at: directory)

        #expect(outcome == .added)
        #expect(harness.repositories.folderAwaitingScanDecision == nil)
        #expect(harness.sharedStore.repositories.count == 1)
    }

    @Test("keys a repository on the host its SSH alias resolves to, keeping the remote as written")
    @MainActor
    func resolvesSSHAlias() async {
        let harness = ServiceHarness()
        let directory = harness.makeDirectory("app")
        await harness.gitClient.setSnapshot(
            RepositoryFixtures.snapshot(remoteURL: "git@github-work:acme/app.git"),
            at: directory
        )
        await harness.sshHostResolver.setHostName("github.com", forAlias: "github-work")

        await harness.repositories.addRepository(at: directory)

        let stored = harness.sharedStore.repositories.first
        #expect(stored?.identifier == "remote:github.com/acme/app")
        #expect(stored?.remoteURL == "git@github-work:acme/app.git")
    }

    @Test("queues each folder it could not add and offers them one at a time")
    @MainActor
    func queuesEachFolderToSearch() async {
        let harness = ServiceHarness()
        let first = URL(filePath: "/dev/one")
        let second = URL(filePath: "/dev/two")

        await harness.repositories.addRepository(at: first)
        await harness.repositories.addRepository(at: second)
        await harness.repositories.addRepository(at: first)

        #expect(harness.repositories.foldersAwaitingScanDecision == [first, second])

        harness.repositories.dismissScanDecision(for: first)

        #expect(harness.repositories.folderAwaitingScanDecision == second)

        harness.repositories.dismissScanDecision(for: second)

        #expect(harness.repositories.folderAwaitingScanDecision == nil)
    }

    @Test("adds a discovered repository keyed on its remote and records this Mac's path")
    @MainActor
    func addsDiscoveredRepository() async {
        let harness = ServiceHarness()
        let directory = harness.makeDirectory("app")
        await harness.gitClient.setSnapshot(RepositoryFixtures.snapshot(), at: directory)

        await harness.repositories.add([DiscoveredRepository(url: directory)])

        #expect(harness.sharedStore.repositories.first?.identifier == "remote:github.com/acme/app")
        #expect(harness.localStore.settings.repositoryPaths["remote:github.com/acme/app"] != nil)
    }

    @Test("preserves the settings of a repository that is added again")
    @MainActor
    func preservesSettingsOnReAdd() async throws {
        let harness = ServiceHarness()
        let directory = harness.makeDirectory("app")
        await harness.gitClient.setSnapshot(RepositoryFixtures.snapshot(), at: directory)
        await harness.repositories.add([DiscoveredRepository(url: directory)])
        var stored = try #require(harness.sharedStore.repositories.first)
        stored.wipCommitPrefixOverride = "SCRATCH"
        try harness.sharedStore.upsert(stored)

        await harness.repositories.add([DiscoveredRepository(url: directory)])

        #expect(harness.sharedStore.repositories.count == 1)
        #expect(harness.sharedStore.repositories.first?.wipCommitPrefixOverride == "SCRATCH")
    }

    @Test("publishes a changed setting straight away, keeping the snapshot it already had")
    @MainActor
    func publishesChangedSettingImmediately() async {
        let harness = ServiceHarness()
        await harness.addRepository("a", name: "app", snapshot: RepositoryFixtures.snapshot(ahead: 2))
        await harness.repositories.start()
        let snapshotsBefore = await harness.gitClient.calls.count(where: { $0 == "snapshot" })

        guard var shared = harness.repositories.repositories.first?.shared else {
            Issue.record("expected a repository")
            return
        }

        shared.allowsMainBranchSync = true
        harness.repositories.update(shared)

        #expect(harness.repositories.repositories.first?.shared.allowsMainBranchSync == true)
        #expect(harness.repositories.repositories.first?.status == .ahead)
        #expect(await harness.gitClient.calls.count(where: { $0 == "snapshot" }) == snapshotsBefore)
        #expect(harness.sharedStore.repositories.first?.allowsMainBranchSync == true)
    }

    // MARK: - Maintenance

    @Test("removing a shared entry deletes no files and clears this Mac's path")
    @MainActor
    func removesSharedEntryOnly() async {
        let harness = ServiceHarness()
        let directory = await harness.addRepository("a", name: "app", snapshot: RepositoryFixtures.snapshot())
        await harness.repositories.start()

        harness.repositories.removeFromSharedWorkspace(identifiers: ["a"])

        #expect(harness.sharedStore.removedIdentifiers == ["a"])
        #expect(harness.localStore.settings.repositoryPaths["a"] == nil)
        #expect(FileManager.default.fileExists(atPath: directory.path(percentEncoded: false)))
        #expect(harness.repositories.repositories.isEmpty)
        #expect(harness.repositories.loadState == .empty)
    }

    @Test("publishes a newly added repository without waiting for another load")
    @MainActor
    func publishesAddedRepositoryImmediately() async {
        let harness = ServiceHarness()
        await harness.repositories.start()
        let directory = harness.makeDirectory("igloo")
        await harness.gitClient.setSnapshot(RepositoryFixtures.snapshot(), at: directory)

        await harness.repositories.add([DiscoveredRepository(url: directory)])

        #expect(harness.repositories.repositories.map(\.name) == ["igloo"])
        #expect(harness.repositories.visibleRepositories.map(\.name) == ["igloo"])
        #expect(harness.repositories.repositories.first?.snapshot != nil)
    }

    @Test("shows a dropped repository straight away, before its status has been read")
    @MainActor
    func showsRepositoryWhileItsStatusLoads() async {
        let harness = ServiceHarness()
        await harness.repositories.start()
        let directory = harness.makeDirectory("igloo")
        await harness.gitClient.setSnapshot(RepositoryFixtures.snapshot(), at: directory)
        await harness.gitClient.holdSnapshots()

        let adding = Task { await harness.repositories.add([DiscoveredRepository(url: directory)]) }
        await harness.gitClient.waitUntilSnapshotRequested()

        #expect(harness.repositories.repositories.map(\.name) == ["igloo"])
        #expect(harness.repositories.repositories.first?.status == .loading)

        await harness.gitClient.releaseSnapshots()
        await adding.value

        #expect(harness.repositories.repositories.first?.status == .clean)
    }

    @Test("reads only the repository that was added rather than every tracked one")
    @MainActor
    func readsOnlyTheAddedRepository() async {
        let harness = ServiceHarness()
        await harness.addRepository("a", name: "existing", snapshot: RepositoryFixtures.snapshot())
        await harness.repositories.start()
        let directory = harness.makeDirectory("igloo")
        await harness.gitClient.setSnapshot(RepositoryFixtures.snapshot(), at: directory)
        let snapshotsBefore = await harness.gitClient.calls.count(where: { $0 == "snapshot" })

        await harness.repositories.add([DiscoveredRepository(url: directory)])

        let snapshotsAfter = await harness.gitClient.calls.count(where: { $0 == "snapshot" })
        #expect(snapshotsAfter - snapshotsBefore == 1)
        #expect(harness.repositories.repositories.count == 2)
    }

    @Test("removes every selected repository from the shared workspace in one go")
    @MainActor
    func removesSeveralFromSharedWorkspace() async {
        let harness = ServiceHarness()
        await harness.addRepository("a", name: "one", snapshot: RepositoryFixtures.snapshot())
        await harness.addRepository("b", name: "two", snapshot: RepositoryFixtures.snapshot())
        await harness.addRepository("c", name: "three", snapshot: RepositoryFixtures.snapshot())
        await harness.repositories.start()

        harness.repositories.removeFromSharedWorkspace(identifiers: ["a", "c"])

        #expect(harness.repositories.repositories.map(\.name) == ["two"])
        #expect(harness.sharedStore.repositories.map(\.identifier) == ["b"])
        #expect(harness.localStore.settings.repositoryPaths.keys.sorted() == ["b"])
    }

    @Test("removes this Mac's path for every selected repository, keeping the shared entries")
    @MainActor
    func removesSeveralLocalPaths() async {
        let harness = ServiceHarness()
        await harness.addRepository("a", name: "one", snapshot: RepositoryFixtures.snapshot())
        await harness.addRepository("b", name: "two", snapshot: RepositoryFixtures.snapshot())
        await harness.repositories.start()

        harness.repositories.removeLocalPathMappings(identifiers: ["a", "b"])

        #expect(harness.sharedStore.repositories.count == 2)
        #expect(harness.repositories.repositories.allSatisfy { $0.status == .notCloned })
    }

    @Test("ignores a removal with nothing selected")
    @MainActor
    func ignoresEmptyRemoval() async {
        let harness = ServiceHarness()
        await harness.addRepository("a", name: "one", snapshot: RepositoryFixtures.snapshot())
        await harness.repositories.start()

        harness.repositories.removeFromSharedWorkspace(identifiers: [])
        harness.repositories.removeLocalPathMappings(identifiers: [])

        #expect(harness.repositories.repositories.count == 1)
        #expect(harness.sharedStore.removedIdentifiers.isEmpty)
    }

    @Test("removing takes the row out without re-reading the repositories that remain")
    @MainActor
    func removesWithoutRereadingTheRest() async {
        let harness = ServiceHarness()
        await harness.addRepository("a", name: "going", snapshot: RepositoryFixtures.snapshot())
        await harness.addRepository("b", name: "staying", snapshot: RepositoryFixtures.snapshot())
        await harness.repositories.start()
        let snapshotsBefore = await harness.gitClient.calls.count(where: { $0 == "snapshot" })

        harness.repositories.removeFromSharedWorkspace(identifiers: ["a"])

        #expect(harness.repositories.repositories.map(\.name) == ["staying"])
        #expect(await harness.gitClient.calls.count(where: { $0 == "snapshot" }) == snapshotsBefore)
    }

    @Test("removing this Mac's path leaves the shared workspace entry in place")
    @MainActor
    func removesLocalPathOnly() async {
        let harness = ServiceHarness()
        await harness.addRepository("a", name: "app", snapshot: RepositoryFixtures.snapshot())
        await harness.repositories.start()

        harness.repositories.removeLocalPathMappings(identifiers: ["a"])

        #expect(harness.sharedStore.repositories.count == 1)
        #expect(harness.repositories.repositories.first?.status == .notCloned)
    }

    @Test("removes the path mappings whose folder has gone and nothing else")
    @MainActor
    func removesStaleMappings() async {
        let harness = ServiceHarness()
        await harness.addRepository("a", name: "app", snapshot: RepositoryFixtures.snapshot())
        harness.settings.recordLocalPath(URL(filePath: "/nowhere/gone"), for: "b")

        let stale = harness.repositories.removeStaleLocalPathMappings()

        #expect(stale == ["b"])
        #expect(harness.localStore.settings.repositoryPaths["a"] != nil)
    }

    @Test("removes duplicate shared entries")
    @MainActor
    func removesDuplicates() {
        let harness = ServiceHarness()
        harness.addUnclonedRepository("a", name: "app")
        harness.sharedStore.repositories.append(RepositoryFixtures.shared("a", name: "app"))

        let removed = harness.repositories.removeDuplicateEntries()

        #expect(removed == ["a"])
        #expect(harness.sharedStore.repositories.count == 1)
    }

    @Test("clearing with local scope keeps the shared workspace intact")
    @MainActor
    func clearsLocalScopeOnly() async {
        let harness = ServiceHarness()
        await harness.addRepository("a", name: "app", snapshot: RepositoryFixtures.snapshot())

        harness.repositories.clearTrackedConfiguration(scope: .local)

        #expect(harness.localStore.settings.repositoryPaths.isEmpty)
        #expect(harness.sharedStore.repositories.count == 1)
        #expect(harness.sharedStore.clearedAllCount == 0)
    }

    @Test("clearing with shared scope empties the workspace on every Mac")
    @MainActor
    func clearsSharedScope() async {
        let harness = ServiceHarness()
        await harness.addRepository("a", name: "app", snapshot: RepositoryFixtures.snapshot())

        harness.repositories.clearTrackedConfiguration(scope: .shared)

        #expect(harness.sharedStore.repositories.isEmpty)
        #expect(harness.localStore.settings.repositoryPaths.isEmpty)
    }
}

// MARK: - Sync results and readiness

extension RepositoriesServiceTests {
    // MARK: - Sync results

    @Test("records the branch and commit of a successful push for use when resuming elsewhere")
    @MainActor
    func recordsHandoff() async {
        let harness = ServiceHarness()
        await harness.addRepository("a", name: "app", snapshot: RepositoryFixtures.snapshot())
        await harness.repositories.start()

        await harness.repositories.apply([
            RepositorySyncOutcome(
                identifier: "a",
                result: .succeeded(commit: "abc123", branch: "feature/login"),
                finishedAt: Date(timeIntervalSince1970: 500)
            )
        ])

        let stored = harness.sharedStore.repositories.first
        #expect(stored?.handoff == RepositoryHandoff(
            branch: "feature/login",
            commit: "abc123",
            recordedAt: Date(timeIntervalSince1970: 500)
        ))
        #expect(stored?.lastSuccessfulSyncDate == Date(timeIntervalSince1970: 500))
    }

    @Test("records no handoff for a failed sync and marks the repository as failed")
    @MainActor
    func recordsFailure() async {
        let harness = ServiceHarness()
        await harness.addRepository("a", name: "app", snapshot: RepositoryFixtures.snapshot())
        await harness.repositories.start()

        await harness.repositories.apply([
            RepositorySyncOutcome(identifier: "a", result: .failed(.diverged), finishedAt: .distantPast)
        ])

        #expect(harness.sharedStore.repositories.first?.handoff == nil)
        #expect(harness.repositories.repositories.first?.status == .failed)
    }

    @Test("re-reads a synced repository so the list stops showing changes that were just pushed")
    @MainActor
    func rereadsAfterSync() async {
        let harness = ServiceHarness()
        let directory = await harness.addRepository(
            "a",
            name: "app",
            snapshot: RepositoryFixtures.snapshot(tracked: [GitFileChange(path: "a.swift", status: .modified)])
        )
        await harness.repositories.start()
        await harness.gitClient.setSnapshot(RepositoryFixtures.snapshot(), at: directory)

        await harness.repositories.apply([
            RepositorySyncOutcome(
                identifier: "a",
                result: .succeeded(commit: "abc123", branch: "main"),
                finishedAt: Date(timeIntervalSince1970: 500)
            )
        ])

        let repository = harness.repositories.repositories.first
        #expect(repository?.snapshot?.workingTree.isClean == true)
        #expect(repository?.shared.handoff?.commit == "abc123")
    }

    // MARK: - Readiness

    @Test("stores the readiness report against the repository it describes")
    @MainActor
    func storesReadinessReport() async {
        let harness = ServiceHarness()
        await harness.addRepository("a", name: "app", snapshot: RepositoryFixtures.snapshot())
        await harness.repositories.start()
        let report = ReadinessReport(identifier: "a", currentBranchPushed: true, issues: [.missingSetupInstructions])
        await harness.readinessChecker.setReport(report, for: "a")

        await harness.repositories.evaluateReadinessForAll(checksRemoteTags: false)

        #expect(harness.repositories.readinessReports["a"] == report)
    }

    @Test("does not evaluate readiness for a repository that is not cloned here")
    @MainActor
    func skipsReadinessForUncloned() async {
        let harness = ServiceHarness()
        harness.addUnclonedRepository("a", name: "app")
        await harness.repositories.start()

        await harness.repositories.evaluateReadinessForAll(checksRemoteTags: false)

        #expect(await harness.readinessChecker.inputs.isEmpty)
    }
}
