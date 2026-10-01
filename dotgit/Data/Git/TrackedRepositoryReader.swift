import Foundation

struct TrackedRepositoryReader: @unchecked Sendable {
    // MARK: - Private

    private let gitClient: any GitClienting
    private let fileManager: FileManager
    private let worktreeReader: TrackedWorktreeReader

    // MARK: - Init

    init(gitClient: any GitClienting, fileManager: FileManager) {
        self.gitClient = gitClient
        self.fileManager = fileManager
        worktreeReader = TrackedWorktreeReader(gitClient: gitClient)
    }

    // MARK: - Reading

    func read(
        _ repository: WorkspaceRepository,
        path: String?,
        outcomes: [String: RepositorySyncOutcome]
    ) async -> TrackedRepository {
        let lastSyncOutcome = outcomes[repository.identifier]

        guard let path, fileManager.fileExists(atPath: path) else {
            return TrackedRepository(shared: repository, lastSyncOutcome: lastSyncOutcome)
        }

        let directory = URL(filePath: path)

        do {
            let snapshot = try await gitClient.snapshot(at: directory)
            let worktrees = await worktreeReader.worktrees(of: repository, at: directory, outcomes: outcomes)

            let main = TrackedRepository(
                shared: repository,
                localPath: directory,
                snapshot: snapshot,
                lastSyncOutcome: lastSyncOutcome
            )

            return WorktreeUseCase.linking(main, to: worktrees)
        } catch {
            return TrackedRepository(
                shared: repository,
                localPath: directory,
                lastSyncOutcome: lastSyncOutcome,
                readError: error
            )
        }
    }

    /// Reads `concurrency` repositories at a time, keeping the order given. Progress is
    /// reported before each read starts, so launch can say what it is waiting on.
    func readAll(
        _ shared: [WorkspaceRepository],
        paths: [String: String],
        outcomes: [String: RepositorySyncOutcome],
        concurrency: Int,
        report: @MainActor @Sendable (RepositoryLoadProgress) -> Void
    ) async -> [TrackedRepository] {
        var progress = RepositoryLoadProgress.starting(total: shared.count)
        var loaded: [Int: TrackedRepository] = [:]
        var queue = shared.enumerated().makeIterator()

        await report(progress)

        await withTaskGroup(of: (Int, TrackedRepository).self) { group in
            for _ in 0 ..< concurrency {
                guard let (index, repository) = queue.next() else {
                    break
                }

                progress = progress.startingToRead(repository.name)
                await report(progress)
                start(repository, at: index, in: &group, path: paths[repository.identifier], outcomes: outcomes)
            }

            for await (index, repository) in group {
                guard Task.isCancelled == false else {
                    group.cancelAll()
                    return
                }

                loaded[index] = repository
                progress = progress.finishedReading(repository.name)

                guard let (nextIndex, next) = queue.next() else {
                    await report(progress)
                    continue
                }

                progress = progress.startingToRead(next.name)
                await report(progress)
                start(next, at: nextIndex, in: &group, path: paths[next.identifier], outcomes: outcomes)
            }
        }

        return shared.indices.compactMap { loaded[$0] }
    }

    // MARK: - Helpers

    private func start(
        _ repository: WorkspaceRepository,
        at index: Int,
        in group: inout TaskGroup<(Int, TrackedRepository)>,
        path: String?,
        outcomes: [String: RepositorySyncOutcome]
    ) {
        group.addTask {
            await (index, read(repository, path: path, outcomes: outcomes))
        }
    }
}
