#if DEBUG
    import Foundation
    import UniformTypeIdentifiers

    struct MockGitClient: GitClienting {
        var snapshotsByPath: [String: GitRepositorySnapshot] = [:]
        var defaultSnapshot: GitRepositorySnapshot?
        var worktreesByPath: [String: [GitWorktree]] = [:]
        var commits: [GitCommitSummary] = []

        func isAvailable() async -> Bool {
            true
        }

        func isRepository(at url: URL) async -> Bool {
            true
        }

        func snapshot(at url: URL) async throws(GitError) -> GitRepositorySnapshot {
            guard let snapshot = snapshotsByPath[url.path(percentEncoded: false)] ?? defaultSnapshot else {
                throw .notARepository(url.path(percentEncoded: false))
            }

            return snapshot
        }

        func worktrees(at url: URL) async throws(GitError) -> [GitWorktree] {
            worktreesByPath[url.path(percentEncoded: false)] ?? []
        }

        func recentCommits(at url: URL, limit: Int) async throws(GitError) -> [GitCommitSummary] {
            Array(commits.prefix(limit))
        }

        func diffSummary(at url: URL) async throws(GitError) -> String {
            " Sources/App.swift | 12 ++++++------\n 1 file changed"
        }

        func stageTrackedChanges(at url: URL) async throws(GitError) {}

        func stage(paths: [String], at url: URL) async throws(GitError) {}

        func commit(message: String, at url: URL) async throws(GitError) {}

        func push(branch: String, remote: String, setUpstream: Bool, at url: URL) async throws(GitError) {}

        func fetch(remote: String, at url: URL) async throws(GitError) {}

        func fastForward(at url: URL) async throws(GitError) {}

        func clone(remoteURL: String, into destination: URL) async throws(GitError) {}

        func checkout(branch: String, at url: URL) async throws(GitError) {}

        func createBranch(_ branch: String, at url: URL) async throws(GitError) {}

        func localTags(at url: URL) async throws(GitError) -> [String] {
            []
        }

        func remoteTags(remote: String, at url: URL) async throws(GitError) -> Set<String> {
            []
        }

        func remoteURL(at url: URL) async throws(GitError) -> String? {
            "git@github.com:acme/\(url.lastPathComponent).git"
        }

        func headCommit(at url: URL) async throws(GitError) -> String? {
            "abc1234"
        }

        func branchExists(_ branch: String, at url: URL) async -> Bool {
            true
        }

        func containsCommit(_ commit: String, at url: URL) async -> Bool {
            true
        }
    }

    struct MockGitHubCLIClient: GitHubCLIClienting {
        var available = true
        var storedAccounts: [GitHubAccount] = [
            GitHubAccount(login: "jamie", host: "github.com", isActive: true),
            GitHubAccount(login: "acme-bot", host: "github.com", isActive: false)
        ]

        func isAvailable() async -> Bool {
            available
        }

        func accounts() async throws(GitHubCLIError) -> [GitHubAccount] {
            storedAccounts
        }

        func switchAccount(to login: String, host: String) async throws(GitHubCLIError) {}

        func hasAccess(toRemoteURL remoteURL: String) async -> Bool {
            true
        }

        func beginInteractiveSignIn() async throws(GitHubCLIError) {}
    }

    struct MockSSHHostResolver: SSHHostResolving {
        func hostName(forAlias alias: String) async -> String? {
            alias
        }
    }

    struct MockRepositoryDiscovery: RepositoryDiscovering {
        var results: [DiscoveredRepository] = []

        func discoverRepositories(
            in root: URL,
            ignoredFolderNames: Set<String>,
            maximumDepth: Int
        ) async -> [DiscoveredRepository] {
            results
        }
    }

    struct MockReadinessChecker: ReadinessChecking {
        var issues: [ReadinessIssue] = []

        func evaluate(_ input: ReadinessCheckInput) async -> ReadinessReport {
            ReadinessReport(identifier: input.repository.identifier, currentBranchPushed: true, issues: issues)
        }
    }

    struct MockSyncEngine: RepositorySyncPerforming {
        func sync(_ request: RepositorySyncRequest) async -> RepositorySyncReport {
            RepositorySyncReport(
                identifier: request.identifier,
                branch: request.branch,
                result: .succeeded(commit: "abc1234", branch: request.branch),
                fallback: nil,
                committed: request.willCommit
            )
        }
    }

    struct MockWorkspaceManifestStore: WorkspaceManifestStoring {
        var manifest: WorkspaceManifest = .empty

        func load(from url: URL) async throws(WorkspaceManifestError) -> WorkspaceManifest {
            manifest
        }

        func save(_ manifest: WorkspaceManifest, to url: URL) async throws(WorkspaceManifestError) {}
    }

    struct MockSimulatorRuntimeProvider: SimulatorRuntimeProviding {
        var storedRuntimes: [SimulatorRuntime] = [
            SimulatorRuntime(
                identifier: "R1",
                name: "iOS 18.0",
                version: "18.0",
                build: "22A3351",
                sizeBytes: 7_100_000_000,
                isDeletable: true,
                path: "/Library/Developer/CoreSimulator/Images/R1.dmg"
            ),
            SimulatorRuntime(
                identifier: "R2",
                name: "watchOS 11.0",
                version: "11.0",
                build: "22R",
                sizeBytes: 2_300_000_000,
                isDeletable: true,
                path: "/Library/Developer/CoreSimulator/Images/R2.dmg"
            )
        ]

        func runtimes() async -> [SimulatorRuntime] {
            storedRuntimes
        }

        func delete(identifier: String) async throws(CleanupError) {}
    }

    struct MockDerivedDataProvider: DerivedDataProviding {
        var storedEntries: [DerivedDataEntry] = [
            DerivedDataEntry(
                url: URL(filePath: "/Users/preview/Library/Developer/Xcode/DerivedData/app-abc"),
                name: "app-abcdefgh",
                sizeBytes: 4_200_000_000,
                source: .defaultLocation
            )
        ]

        func entries(
            includesDefaultLocation: Bool,
            projectRoots: [URL],
            customPaths: [URL]
        ) async -> [DerivedDataEntry] {
            storedEntries
        }

        func remove(at url: URL) async throws(CleanupError) {}
    }

    struct MockProjectOpener: ProjectOpening {
        func open(_ url: URL, withApplicationAt applicationURL: URL?) async -> Bool {
            true
        }
    }

    @MainActor
    final class MockLocalSettingsStore: LocalSettingsStoring {
        private var settings: LocalSettings

        init(settings: LocalSettings = .default) {
            self.settings = settings
        }

        func load() -> LocalSettings {
            settings
        }

        func save(_ settings: LocalSettings) {
            self.settings = settings
        }

        func reset() {
            settings = .default
        }
    }

    @MainActor
    final class MockSharedWorkspaceStore: SharedWorkspaceStoring {
        private var storedRepositories: [WorkspaceRepository]
        private var storedPreferences: AppPreferences

        init(repositories: [WorkspaceRepository] = [], preferences: AppPreferences = .default) {
            storedRepositories = repositories
            storedPreferences = preferences
        }

        func loadRepositories() throws(PersistenceError) -> [WorkspaceRepository] {
            storedRepositories
        }

        func upsert(_ repository: WorkspaceRepository) throws(PersistenceError) {
            guard let index = storedRepositories.firstIndex(where: { $0.identifier == repository.identifier }) else {
                storedRepositories.append(repository)
                return
            }

            storedRepositories[index] = repository
        }

        func remove(identifier: String) throws(PersistenceError) {
            storedRepositories.removeAll { $0.identifier == identifier }
        }

        func removeDuplicates() throws(PersistenceError) -> [String] {
            []
        }

        func removeAllRepositories() throws(PersistenceError) {
            storedRepositories = []
        }

        func loadPreferences() throws(PersistenceError) -> AppPreferences {
            storedPreferences
        }

        func save(_ preferences: AppPreferences) throws(PersistenceError) {
            storedPreferences = preferences
        }
    }

    @MainActor
    final class MockFilePanelPresenter: FilePanelPresenting {
        var folder: URL?
        var file: URL?
        var saveLocation: URL?

        func chooseFolder(message: String) -> URL? {
            folder
        }

        func chooseFile(message: String, contentTypes: [UTType]) -> URL? {
            file
        }

        func chooseSaveLocation(message: String, suggestedName: String, contentType: UTType) -> URL? {
            saveLocation
        }
    }

    struct MockClock: Clocking {
        let timeZone = TimeZone(identifier: "UTC") ?? .gmt

        func now() -> Date {
            Date(timeIntervalSince1970: 1_758_600_000)
        }
    }
#endif
