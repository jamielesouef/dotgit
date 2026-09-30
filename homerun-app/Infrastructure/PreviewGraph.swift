#if DEBUG
    import Foundation

    @MainActor
    enum PreviewGraph {
        // MARK: - Graphs

        static let populated = make(repositories: sampleRepositories, paths: samplePaths, snapshots: sampleSnapshots)

        static let empty = make(repositories: [], paths: [:], snapshots: [:])

        static let longNames = make(
            repositories: [
                WorkspaceRepository(
                    identifier: "remote:github.com/acme/an-extremely-long-repository-name-that-wraps",
                    name: "an-extremely-long-repository-name-that-wraps-onto-several-lines",
                    remoteURL: "https://github.com/acme/an-extremely-long-repository-name-that-wraps.git",
                    preferredRelativePath: "clients/acme/an-extremely-long-repository-name-that-wraps"
                )
            ],
            paths: [
                "remote:github.com/acme/an-extremely-long-repository-name-that-wraps": "/Users/preview/Developer/long"
            ],
            snapshots: [
                "/Users/preview/Developer/long": snapshot(
                    branch: "feature/a-very-long-branch-name-for-a-very-long-piece-of-work",
                    ahead: 12,
                    tracked: [GitFileChange(path: "Sources/A/Very/Deeply/Nested/File.swift", status: .modified)],
                    untracked: ["Notes/scratch-thoughts-about-the-thing.md"]
                )
            ]
        )

        // MARK: - Factory

        static func make(
            repositories: [WorkspaceRepository],
            paths: [String: String],
            snapshots: [String: GitRepositorySnapshot],
            gitHubAvailable: Bool = true
        ) -> AppGraph {
            makeGraph(core: makeCore(
                repositories: repositories,
                paths: paths,
                snapshots: snapshots,
                gitHubAvailable: gitHubAvailable
            ))
        }

        // MARK: - Core

        private struct Core {
            let sharedStore: MockSharedWorkspaceStore
            let settings: SettingsService
            let gitClient: MockGitClient
            let gitHubClient: MockGitHubCLIClient
            let clock: MockClock
            let repositoriesService: RepositoriesService
        }

        private static func makeCore(
            repositories: [WorkspaceRepository],
            paths: [String: String],
            snapshots: [String: GitRepositorySnapshot],
            gitHubAvailable: Bool
        ) -> Core {
            var local = LocalSettings.default
            local.repositoryPaths = paths
            local.workspaceRootPath = "/Users/preview/Developer"
            local.hasCompletedOnboarding = true

            let sharedStore = MockSharedWorkspaceStore(repositories: repositories)
            let localStore = MockLocalSettingsStore(settings: local)
            let settings = SettingsService(sharedStore: sharedStore, localStore: localStore)

            var gitClient = MockGitClient()
            gitClient.snapshotsByPath = snapshots
            gitClient.commits = sampleCommits

            var gitHubClient = MockGitHubCLIClient()
            gitHubClient.available = gitHubAvailable

            let clock = MockClock()
            let repositoriesService = RepositoriesService(
                sharedStore: sharedStore,
                gitClient: gitClient,
                discovery: MockRepositoryDiscovery(),
                readinessChecker: MockReadinessChecker(issues: [.untrackedFiles(["Notes.md"])]),
                sshHostResolver: MockSSHHostResolver(),
                fileManager: .default,
                clock: clock,
                settings: settings
            )

            return Core(
                sharedStore: sharedStore,
                settings: settings,
                gitClient: gitClient,
                gitHubClient: gitHubClient,
                clock: clock,
                repositoriesService: repositoriesService
            )
        }

        private static func makeGraph(core: Core) -> AppGraph {
            AppGraph(
                settings: core.settings,
                onboarding: OnboardingService(
                    gitClient: core.gitClient,
                    gitHubClient: core.gitHubClient,
                    settings: core.settings
                ),
                repositories: core.repositoriesService,
                sync: SyncService(
                    engine: MockSyncEngine(),
                    repositories: core.repositoriesService,
                    settings: core.settings,
                    clock: core.clock
                ),
                resume: ResumeService(
                    gitClient: core.gitClient,
                    repositories: core.repositoriesService,
                    settings: core.settings,
                    projectOpener: MockProjectOpener()
                ),
                workspace: WorkspaceService(
                    manifestStore: MockWorkspaceManifestStore(),
                    sharedStore: core.sharedStore,
                    repositories: core.repositoriesService,
                    settings: core.settings,
                    clock: core.clock
                ),
                accounts: GitHubAccountsService(
                    client: core.gitHubClient,
                    repositories: core.repositoriesService,
                    settings: core.settings
                ),
                cleaner: CleanerService(
                    runtimeProvider: MockSimulatorRuntimeProvider(),
                    derivedDataProvider: MockDerivedDataProvider(),
                    repositories: core.repositoriesService,
                    settings: core.settings
                ),
                filePanel: MockFilePanelPresenter()
            )
        }

        // MARK: - Samples

        static let sampleRepositories: [WorkspaceRepository] = [
            WorkspaceRepository(
                identifier: "remote:github.com/acme/app",
                name: "app",
                remoteURL: "https://github.com/acme/app.git",
                preferredRelativePath: "app",
                lastSuccessfulSyncDate: Date(timeIntervalSince1970: 1_758_500_000)
            ),
            WorkspaceRepository(
                identifier: "remote:github.com/acme/tooling",
                name: "tooling",
                remoteURL: "git@github.com:acme/tooling.git",
                preferredRelativePath: "tooling"
            ),
            WorkspaceRepository(
                identifier: "remote:github.com/acme/archive",
                name: "archive",
                remoteURL: "https://github.com/acme/archive.git",
                preferredRelativePath: "archive"
            )
        ]

        static let samplePaths = [
            "remote:github.com/acme/app": "/Users/preview/Developer/app",
            "remote:github.com/acme/tooling": "/Users/preview/Developer/tooling"
        ]

        static let sampleSnapshots = [
            "/Users/preview/Developer/app": snapshot(
                branch: "feature/login",
                ahead: 3,
                tracked: [
                    GitFileChange(path: "Sources/Login.swift", status: .modified),
                    GitFileChange(path: "Sources/Removed.swift", status: .deleted)
                ],
                untracked: ["Notes.md"]
            ),
            "/Users/preview/Developer/tooling": snapshot(branch: "main")
        ]

        static let sampleCommits = [
            GitCommitSummary(
                hash: "abc1234def5678",
                subject: "Add the login screen",
                authorName: "Jamie",
                date: Date(timeIntervalSince1970: 1_758_500_000)
            ),
            GitCommitSummary(
                hash: "bcd2345efa6789",
                subject: "Tidy the session store",
                authorName: "Jamie",
                date: Date(timeIntervalSince1970: 1_758_400_000)
            )
        ]

        // MARK: - Helpers

        static let repositoryWithWorktrees = repositoryWithWorktrees(
            worktrees: [
                worktree("feature+login", branch: "feature/login", dirty: true),
                worktree("hotfix", branch: "hotfix/crash")
            ]
        )

        static func repositoryWithWorktrees(worktrees: [TrackedRepository]) -> TrackedRepository {
            WorktreeUseCase.linking(
                TrackedRepository(
                    shared: sampleRepositories[0],
                    localPath: URL(filePath: "/Users/preview/Developer/app"),
                    snapshot: snapshot(branch: "main")
                ),
                to: worktrees
            )
        }

        static func worktree(
            _ name: String,
            branch: String?,
            dirty: Bool = false,
            readable: Bool = true
        ) -> TrackedRepository {
            let path = URL(filePath: "/Users/preview/Developer/app/.claude/worktrees/\(name)")

            let worktree = GitWorktree(
                path: path,
                headCommit: "def5678",
                branch: branch,
                isMain: false,
                isBare: false,
                isLocked: false,
                isPrunable: false
            )

            return TrackedRepository(
                shared: sampleRepositories[0],
                localPath: path,
                snapshot: readable
                    ? snapshot(
                        branch: branch,
                        tracked: dirty ? [GitFileChange(path: "Sources/Login.swift", status: .modified)] : [],
                        untracked: dirty ? ["Notes.md"] : []
                    )
                    : nil,
                readError: readable ? nil : .notARepository(path.path(percentEncoded: false)),
                worktree: worktree
            )
        }

        static func snapshot(
            branch: String?,
            ahead: Int = 0,
            behind: Int = 0,
            tracked: [GitFileChange] = [],
            untracked: [String] = []
        ) -> GitRepositorySnapshot {
            GitRepositorySnapshot(
                currentBranch: branch,
                headCommit: "abc1234",
                defaultRemoteName: "origin",
                remoteURL: "https://github.com/acme/app.git",
                upstreamBranch: branch.map { "origin/\($0)" },
                aheadCount: ahead,
                behindCount: behind,
                workingTree: GitWorkingTreeStatus(trackedChanges: tracked, untrackedPaths: untracked),
                branches: [
                    GitBranchRef(
                        name: branch ?? "main",
                        upstream: "origin/\(branch ?? "main")",
                        aheadCount: ahead,
                        behindCount: behind
                    ),
                    GitBranchRef(name: "spike", upstream: nil, aheadCount: 0, behindCount: 0)
                ],
                submoduleChanges: []
            )
        }
    }
#endif
