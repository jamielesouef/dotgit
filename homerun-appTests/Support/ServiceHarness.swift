import Foundation
@testable import homerun_app

@MainActor
final class ServiceHarness {
    // MARK: - Doubles

    let sharedStore = StubSharedWorkspaceStore()
    let localStore = StubLocalSettingsStore()
    let gitClient = StubGitClient()
    let gitHubClient = StubGitHubCLIClient()
    let discovery = StubRepositoryDiscovery()
    let readinessChecker = StubReadinessChecker()
    let sshHostResolver = StubSSHHostResolver()
    let syncEngine = StubSyncEngine()
    let manifestStore = StubWorkspaceManifestStore()
    let runtimeProvider = StubSimulatorRuntimeProvider()
    let derivedDataProvider = StubDerivedDataProvider()
    let projectOpener = StubProjectOpener()
    let clock = StubClock()

    // MARK: - Services

    let settings: SettingsService
    let repositories: RepositoriesService

    private let root: URL

    // MARK: - Init

    init() {
        root = URL(filePath: NSTemporaryDirectory()).appending(path: "homerun-harness-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

        settings = SettingsService(sharedStore: sharedStore, localStore: localStore)
        repositories = RepositoriesService(
            sharedStore: sharedStore,
            gitClient: gitClient,
            discovery: discovery,
            readinessChecker: readinessChecker,
            sshHostResolver: sshHostResolver,
            fileManager: .default,
            clock: clock,
            settings: settings
        )
    }

    deinit {
        try? FileManager.default.removeItem(at: root)
    }

    // MARK: - Service factories

    func makeSync() -> SyncService {
        SyncService(engine: syncEngine, repositories: repositories, settings: settings, clock: clock)
    }

    func makeResume() -> ResumeService {
        ResumeService(
            gitClient: gitClient,
            repositories: repositories,
            settings: settings,
            projectOpener: projectOpener
        )
    }

    func makeWorkspace() -> WorkspaceService {
        WorkspaceService(
            manifestStore: manifestStore,
            sharedStore: sharedStore,
            repositories: repositories,
            settings: settings,
            clock: clock
        )
    }

    func makeAccounts() -> GitHubAccountsService {
        GitHubAccountsService(client: gitHubClient, repositories: repositories, settings: settings)
    }

    func makeCleaner() -> CleanerService {
        CleanerService(
            runtimeProvider: runtimeProvider,
            derivedDataProvider: derivedDataProvider,
            repositories: repositories,
            settings: settings
        )
    }

    func makeOnboarding() -> OnboardingService {
        OnboardingService(gitClient: gitClient, gitHubClient: gitHubClient, settings: settings)
    }

    // MARK: - Fixtures

    @discardableResult
    func addRepository(
        _ identifier: String,
        name: String,
        snapshot: GitRepositorySnapshot?,
        shared: WorkspaceRepository? = nil
    ) async -> URL {
        let directory = root.appending(path: name)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        var record = shared ?? RepositoryFixtures.shared(identifier, name: name)
        record.name = name
        sharedStore.repositories.append(record)
        settings.recordLocalPath(directory, for: identifier)

        if let snapshot {
            await gitClient.setSnapshot(snapshot, at: directory)
        }

        return directory
    }

    func addUnclonedRepository(_ identifier: String, name: String, shared: WorkspaceRepository? = nil) {
        var record = shared ?? RepositoryFixtures.shared(identifier, name: name)
        record.name = name
        sharedStore.repositories.append(record)
    }

    func makeDirectory(_ name: String) -> URL {
        let url = root.appending(path: name)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)

        return url
    }
}
