import Foundation

@MainActor
@Observable
final class RepositoriesService: SingleFlightRefreshing {
    // MARK: - State

    enum LoadState: Equatable {
        case loading(RepositoryLoadProgress)
        case error(PersistenceError)
        case empty
        case loaded([TrackedRepository])
    }

    var loadState: LoadState {
        switch (isLoading, loadError, repositories.isEmpty) {
        case (true, _, true):
            .loading(loadProgress)
        case (_, let error?, true):
            .error(error)
        case (_, nil, true):
            .empty
        case (_, _, false):
            .loaded(repositories)
        }
    }

    private(set) var repositories: [TrackedRepository] = []
    private(set) var readinessReports: [String: ReadinessReport] = [:]
    private(set) var isScanning = false
    private(set) var lastMaintenanceMessage: String?
    private(set) var foldersAwaitingScanDecision: [URL] = []

    var folderAwaitingScanDecision: URL? {
        foldersAwaitingScanDecision.first
    }

    var filter: RepositoryStatusFilter
    var sortOrder: RepositorySortOrder
    var searchText = ""

    var visibleRepositories: [TrackedRepository] {
        RepositorySortUseCase.sorted(
            RepositoryFilterUseCase.apply(
                to: repositories,
                filter: filter,
                showsCleanRepositories: settings.preferences.showsCleanRepositories,
                searchText: searchText
            ),
            by: sortOrder
        )
    }

    var allCheckouts: [TrackedRepository] {
        repositories.flatMap(\.allCheckouts)
    }

    var todaySummary: TodaySummary {
        TodaySummaryUseCase.summary(for: repositories, readiness: readinessReports)
    }

    // MARK: - SingleFlightRefreshing

    var refreshTask: Task<Void, Never>?

    // MARK: - Private

    private let sharedStore: any SharedWorkspaceStoring
    private let gitClient: any GitClienting
    private let discovery: any RepositoryDiscovering
    private let readinessChecker: any ReadinessChecking
    private let sshHostResolver: any SSHHostResolving
    private let reader: TrackedRepositoryReader
    private let fileManager: FileManager
    private let clock: any Clocking
    private let settings: SettingsService

    private var outcomes: [String: RepositorySyncOutcome] = [:]
    private var isLoading = false
    private var loadProgress = RepositoryLoadProgress.opening
    private var loadError: PersistenceError?
    private var hasStarted = false

    // MARK: - Init

    init(
        sharedStore: any SharedWorkspaceStoring,
        gitClient: any GitClienting,
        discovery: any RepositoryDiscovering,
        readinessChecker: any ReadinessChecking,
        sshHostResolver: any SSHHostResolving,
        fileManager: FileManager,
        clock: any Clocking,
        settings: SettingsService
    ) {
        self.sharedStore = sharedStore
        self.gitClient = gitClient
        self.discovery = discovery
        self.readinessChecker = readinessChecker
        self.sshHostResolver = sshHostResolver
        self.fileManager = fileManager
        reader = TrackedRepositoryReader(gitClient: gitClient, fileManager: fileManager)
        self.clock = clock
        self.settings = settings
        filter = settings.preferences.defaultRepositoryStatusFilter
        sortOrder = settings.preferences.repositorySortOrder
    }

    // MARK: - Intent

    func start() async {
        guard hasStarted == false else {
            return
        }

        hasStarted = true
        await refresh()
    }

    func repository(identifier: String) -> TrackedRepository? {
        allCheckouts.first { $0.id == identifier }
    }

    func update(_ repository: WorkspaceRepository) {
        guard repositories.first(where: { $0.id == repository.identifier })?.shared != repository else {
            return
        }

        store { () throws(PersistenceError) in
            try sharedStore.upsert(repository)
        }

        guard let index = repositories.firstIndex(where: { $0.id == repository.identifier }) else {
            return
        }

        repositories[index] = repositories[index].replacingShared(repository)
    }

    @discardableResult
    func addRepository(at url: URL) async -> RepositoryAddOutcome {
        let dropped = url.standardizedFileURL

        guard await gitClient.isRepository(at: dropped) else {
            if foldersAwaitingScanDecision.contains(dropped) == false {
                foldersAwaitingScanDecision.append(dropped)
            }

            return .notARepository(dropped)
        }

        let listed = await (try? gitClient.worktrees(at: dropped)) ?? []
        let mainCheckout = WorktreeUseCase.mainCheckout(for: dropped.resolvingSymlinksInPath(), in: listed)

        await add([DiscoveredRepository(url: mainCheckout?.standardizedFileURL ?? dropped)])

        return .added
    }

    func dismissScanDecision(for folder: URL) {
        guard foldersAwaitingScanDecision.first == folder else {
            return
        }

        foldersAwaitingScanDecision.removeFirst()
    }

    func scanFolder(_ url: URL) async -> [DiscoveredRepository] {
        isScanning = true
        defer { isScanning = false }

        let ignored = Set(settings.preferences.ignoredFolderNames)
        let found = await discovery.discoverRepositories(in: url, ignoredFolderNames: ignored, maximumDepth: 6)

        guard Task.isCancelled == false else {
            return []
        }

        return found
    }

    func add(_ discovered: [DiscoveredRepository]) async {
        let existing = (try? sharedStore.loadRepositories()) ?? []
        var added: [(shared: WorkspaceRepository, directory: URL)] = []

        for repository in RepositoryMaintenanceUseCase.deduplicated(discovered) {
            let remoteURL = try? await gitClient.remoteURL(at: repository.url)
            let identifier = await sshHostResolver.identifier(remoteURL: remoteURL, folderName: repository.name)
            let merged = RepositoryMaintenanceUseCase.merged(
                existing: existing.first { $0.identifier == identifier },
                identifier: identifier,
                discovered: repository,
                remoteURL: remoteURL,
                addedDate: clock.now()
            )

            store { () throws(PersistenceError) in
                try sharedStore.upsert(merged)
            }
            settings.recordLocalPath(repository.url, for: identifier)
            added.append((merged, repository.url))
        }

        showWhileReading(added)
        await read(added)
    }

    // MARK: - Maintenance

    func removeFromSharedWorkspace(identifiers: Set<String>) {
        guard identifiers.isEmpty == false else {
            return
        }

        for identifier in identifiers {
            store { () throws(PersistenceError) in
                try sharedStore.remove(identifier: identifier)
            }
            settings.removeLocalPath(for: identifier)
        }

        repositories.removeAll { identifiers.contains($0.id) }
        lastMaintenanceMessage = String(
            localized: "Removed \(identifiers.count) repository(s) from the shared workspace. No files were deleted."
        )
    }

    func removeLocalPathMappings(identifiers: Set<String>) {
        guard identifiers.isEmpty == false else {
            return
        }

        for identifier in identifiers {
            settings.removeLocalPath(for: identifier)
        }

        forgetLocalCheckout(of: identifiers)
        lastMaintenanceMessage = String(
            localized: "Removed this Mac's path for \(identifiers.count) repository(s). The shared workspace is unchanged."
        )
    }

    @discardableResult
    func removeStaleLocalPathMappings() -> [String] {
        let stale = RepositoryMaintenanceUseCase.staleLocalPathIdentifiers(
            repositoryPaths: settings.localSettings.repositoryPaths
        ) { [fileManager] path in
            fileManager.fileExists(atPath: path)
        }

        for identifier in stale {
            settings.removeLocalPath(for: identifier)
        }

        forgetLocalCheckout(of: Set(stale))
        lastMaintenanceMessage = String(localized: "Removed \(stale.count) stale path(s) on this Mac.")

        return stale
    }

    @discardableResult
    func removeDuplicateEntries() -> [String] {
        var removed: [String] = []

        store { () throws(PersistenceError) in
            removed = try sharedStore.removeDuplicates()
        }

        var seen: Set<String> = []
        repositories = repositories.filter { seen.insert($0.id).inserted }
        lastMaintenanceMessage = String(localized: "Removed \(removed.count) duplicate entry(s).")

        return removed
    }

    func clearTrackedConfiguration(scope: ConfigurationScope) {
        switch scope {
        case .local:
            settings.updateLocalSettings { $0.repositoryPaths = [:] }
            forgetLocalCheckout(of: Set(repositories.map(\.id)))
        case .shared:
            store { () throws(PersistenceError) in
                try sharedStore.removeAllRepositories()
            }
            settings.updateLocalSettings { $0.repositoryPaths = [:] }
            repositories = []
        }

        lastMaintenanceMessage = scope.explanation
    }

    func clearMaintenanceMessage() {
        lastMaintenanceMessage = nil
    }

    // MARK: - Sync results

    func apply(_ outcomes: [RepositorySyncOutcome]) async {
        for outcome in outcomes {
            self.outcomes[outcome.identifier] = outcome
            record(outcome)
        }

        await reread(identifiers: Set(outcomes.map(\.identifier)))
    }

    // MARK: - Detail

    func recentCommits(for repository: TrackedRepository, limit: Int) async -> [GitCommitSummary] {
        guard let directory = repository.localPath else {
            return []
        }

        return await (try? gitClient.recentCommits(at: directory, limit: limit)) ?? []
    }

    func diffSummary(for repository: TrackedRepository) async -> String {
        guard let directory = repository.localPath else {
            return ""
        }

        return await (try? gitClient.diffSummary(at: directory)) ?? ""
    }

    // MARK: - Readiness

    func evaluateReadiness(for repository: TrackedRepository, checksRemoteTags: Bool) async {
        guard let directory = repository.localPath, let snapshot = repository.snapshot else {
            return
        }

        let input = ReadinessCheckInput(
            repository: repository.shared,
            directory: directory,
            snapshot: snapshot,
            checksRemoteTags: checksRemoteTags
        )

        let report = await readinessChecker.evaluate(input)

        guard Task.isCancelled == false else {
            return
        }

        readinessReports[repository.id] = report
    }

    func evaluateReadinessForAll(checksRemoteTags: Bool) async {
        for repository in repositories where repository.isCloned {
            await evaluateReadiness(for: repository, checksRemoteTags: checksRemoteTags)
        }
    }

    // MARK: - SingleFlightRefreshing

    func performRefresh() async {
        isLoading = true
        loadError = nil
        loadProgress = .opening

        let shared: [WorkspaceRepository]

        do {
            shared = try sharedStore.loadRepositories()
        } catch {
            loadError = error
            isLoading = false
            return
        }

        let paths = settings.localSettings.repositoryPaths
        let loaded = await load(shared, paths: paths)

        guard Task.isCancelled == false else {
            return
        }

        repositories = loaded
        isLoading = false
    }
}

// MARK: - Helpers

private extension RepositoriesService {
    func load(_ shared: [WorkspaceRepository], paths: [String: String]) async -> [TrackedRepository] {
        await reader.readAll(
            shared,
            paths: paths,
            outcomes: outcomes,
            concurrency: AppConstants.concurrentRepositoryReads
        ) { [weak self] progress in
            self?.loadProgress = progress
        }
    }

    func forgetLocalCheckout(of identifiers: Set<String>) {
        repositories = repositories.map { repository in
            guard identifiers.contains(repository.id) else {
                return repository
            }

            return TrackedRepository(shared: repository.shared, lastSyncOutcome: repository.lastSyncOutcome)
        }
    }

    func showWhileReading(_ added: [(shared: WorkspaceRepository, directory: URL)]) {
        for entry in added where repositories.contains(where: { $0.id == entry.shared.identifier }) == false {
            repositories.append(
                TrackedRepository(shared: entry.shared, localPath: entry.directory, isLoadingSnapshot: true)
            )
        }
    }

    func read(_ added: [(shared: WorkspaceRepository, directory: URL)], appendsMissing: Bool = true) async {
        for entry in added {
            let loaded = await tracked(entry.shared, path: entry.directory.path(percentEncoded: false))

            guard Task.isCancelled == false else {
                return
            }
            guard let index = repositories.firstIndex(where: { $0.id == entry.shared.identifier }) else {
                if appendsMissing {
                    repositories.append(loaded)
                }
                continue
            }

            repositories[index] = loaded
        }
    }

    /// Re-reads only the repositories a sync touched, in place. A full `refresh()` here
    /// is cancelled by any other refresh, leaving just-pushed changes on screen.
    func reread(identifiers: Set<String>) async {
        let paths = settings.localSettings.repositoryPaths
        let touched = repositories.compactMap { repository -> (shared: WorkspaceRepository, directory: URL)? in
            guard repository.allCheckouts.contains(where: { identifiers.contains($0.id) }),
                  let path = paths[repository.id]
            else {
                return nil
            }

            return ((try? sharedStore.repository(identifier: repository.id)) ?? repository.shared, URL(filePath: path))
        }

        await read(touched, appendsMissing: false)
    }

    func tracked(_ repository: WorkspaceRepository, path: String?) async -> TrackedRepository {
        await reader.read(repository, path: path, outcomes: outcomes)
    }

    func record(_ outcome: RepositorySyncOutcome) {
        guard let stored = try? sharedStore.repository(identifier: outcome.identifier),
              let repository = SyncHandoffUseCase.recording(outcome, in: stored)
        else {
            return
        }

        store { () throws(PersistenceError) in
            try sharedStore.upsert(repository)
        }
    }

    func store(_ work: () throws(PersistenceError) -> Void) {
        do {
            try work()
            loadError = nil
        } catch {
            loadError = error
            AppLog.error("Shared workspace write failed: \(String(describing: error))")
        }
    }
}
