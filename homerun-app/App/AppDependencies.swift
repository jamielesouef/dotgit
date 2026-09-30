import Foundation
import SwiftData

enum AppDependencies {
    // MARK: - Graph

    @MainActor
    static let shared = makeGraph()

    @MainActor
    static func makeGraph() -> AppGraph {
        let core = makeCoreDependencies()
        let repositories = makeRepositoriesService(core: core)
        let engine = RepositorySyncEngine(
            gitClient: core.gitClient,
            gitHubClient: core.gitHubClient,
            pushFallback: GitHubAccountPushFallback(gitClient: core.gitClient, gitHubClient: core.gitHubClient)
        )

        return makeAppGraph(core: core, repositories: repositories, engine: engine)
    }

    // MARK: - Private

    private struct CoreDependencies {
        let fileManager: FileManager
        let resolver: ToolPathResolver
        let commandRunner: ProcessCommandRunner
        let sharedStore: any SharedWorkspaceStoring
        let settings: SettingsService
        let gitClient: ProcessGitClient
        let gitHubClient: ProcessGitHubCLIClient
        let clock: SystemClock
    }

    @MainActor
    private static func makeCoreDependencies() -> CoreDependencies {
        let fileManager = FileManager.default
        let defaults = UserDefaults.standard
        let processEnvironment = ProcessInfo.processInfo.environment
        let temporaryDirectory = fileManager.temporaryDirectory
        let resolver = ToolPathResolver(fileManager: fileManager, searchDirectories: AppConstants.toolSearchDirectories)

        let localStore = UserDefaultsLocalSettingsStore(
            defaults: defaults,
            defaultSettings: makeDefaultLocalSettings(resolver)
        )

        let sharedStore = makeSharedStore()
        let settings = SettingsService(sharedStore: sharedStore, localStore: localStore)

        let commandRunner = ProcessCommandRunner(
            baseEnvironment: processEnvironment,
            temporaryDirectory: temporaryDirectory
        )

        let gitClient = ProcessGitClient(
            commandRunner: commandRunner,
            gitPath: resolver.resolve("git", preferring: settings.localSettings.gitPath) ?? "/usr/bin/git"
        )

        let gitHubClient = ProcessGitHubCLIClient(
            commandRunner: commandRunner,
            gitHubCLIPath: resolver
                .resolve("gh", preferring: settings.localSettings.gitHubCLIPath) ?? "/opt/homebrew/bin/gh",
            scriptRunnerPath: resolver.resolve("osascript", preferring: nil) ?? "/usr/bin/osascript"
        )

        let clock = SystemClock(timeZone: TimeZone.current)

        return CoreDependencies(
            fileManager: fileManager,
            resolver: resolver,
            commandRunner: commandRunner,
            sharedStore: sharedStore,
            settings: settings,
            gitClient: gitClient,
            gitHubClient: gitHubClient,
            clock: clock
        )
    }

    @MainActor
    private static func makeRepositoriesService(core: CoreDependencies) -> RepositoriesService {
        RepositoriesService(
            sharedStore: core.sharedStore,
            gitClient: core.gitClient,
            discovery: FileSystemRepositoryDiscovery(fileManager: core.fileManager),
            readinessChecker: GitReadinessChecker(gitClient: core.gitClient, fileManager: core.fileManager),
            sshHostResolver: ProcessSSHHostResolver(
                commandRunner: core.commandRunner,
                sshPath: core.resolver.resolve("ssh", preferring: nil) ?? "/usr/bin/ssh"
            ),
            fileManager: core.fileManager,
            clock: core.clock,
            settings: core.settings
        )
    }

    @MainActor
    private static func makeAppGraph(
        core: CoreDependencies,
        repositories: RepositoriesService,
        engine: RepositorySyncEngine
    ) -> AppGraph {
        AppGraph(
            settings: core.settings,
            onboarding: OnboardingService(
                gitClient: core.gitClient,
                gitHubClient: core.gitHubClient,
                settings: core.settings
            ),
            repositories: repositories,
            sync: SyncService(engine: engine, repositories: repositories, settings: core.settings, clock: core.clock),
            resume: ResumeService(
                gitClient: core.gitClient,
                repositories: repositories,
                settings: core.settings,
                projectOpener: WorkspaceProjectOpener()
            ),
            workspace: WorkspaceService(
                manifestStore: FileWorkspaceManifestStore(),
                sharedStore: core.sharedStore,
                repositories: repositories,
                settings: core.settings,
                clock: core.clock
            ),
            accounts: GitHubAccountsService(
                client: core.gitHubClient,
                repositories: repositories,
                settings: core.settings
            ),
            cleaner: CleanerService(
                runtimeProvider: SimctlRuntimeProvider(
                    commandRunner: core.commandRunner,
                    xcrunPath: core.resolver.resolve("xcrun", preferring: nil) ?? "/usr/bin/xcrun"
                ),
                derivedDataProvider: FileSystemDerivedDataProvider(
                    fileManager: core.fileManager,
                    defaultDerivedDataURL: makeDefaultDerivedDataURL(core.fileManager)
                ),
                repositories: repositories,
                settings: core.settings
            ),
            filePanel: AppKitFilePanelPresenter()
        )
    }

    @MainActor
    private static func makeSharedStore() -> any SharedWorkspaceStoring {
        let identifier = Bundle.main.object(forInfoDictionaryKey: AppConstants.cloudKitContainerInfoKey) as? String

        do {
            let container = try ModelContainerFactory.make(inMemory: false, cloudKitContainerIdentifier: identifier)

            return SwiftDataWorkspaceStore(context: ModelContext(container))
        } catch {
            AppLog.error("Falling back to an in-memory workspace: \(String(describing: error))")

            return makeInMemoryStore()
        }
    }

    @MainActor
    private static func makeInMemoryStore() -> any SharedWorkspaceStoring {
        guard let container = try? ModelContainerFactory.make(inMemory: true, cloudKitContainerIdentifier: nil) else {
            fatalError("The workspace store could not be created")
        }

        return SwiftDataWorkspaceStore(context: ModelContext(container))
    }

    private static func makeDefaultLocalSettings(_ resolver: ToolPathResolver) -> LocalSettings {
        var settings = LocalSettings.default
        settings.gitPath = resolver.resolve("git", preferring: nil) ?? settings.gitPath
        settings.gitHubCLIPath = resolver.resolve("gh", preferring: nil) ?? settings.gitHubCLIPath

        return settings
    }

    private static func makeDefaultDerivedDataURL(_ fileManager: FileManager) -> URL {
        let home = fileManager.homeDirectoryForCurrentUser

        return home.appending(path: "Library/Developer/Xcode/DerivedData")
    }
}
