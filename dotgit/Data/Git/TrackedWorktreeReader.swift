import Foundation

struct TrackedWorktreeReader {
    // MARK: - Private

    private let gitClient: any GitClienting

    // MARK: - Init

    init(gitClient: any GitClienting) {
        self.gitClient = gitClient
    }

    // MARK: - Reading

    func worktrees(
        of repository: WorkspaceRepository,
        at directory: URL,
        outcomes: [String: RepositorySyncOutcome]
    ) async -> [TrackedRepository] {
        let listed = await (try? gitClient.worktrees(at: directory)) ?? []
        var worktrees: [TrackedRepository] = []

        for worktree in WorktreeUseCase.linkedWorktrees(listed) {
            let identifier = WorktreeUseCase.identifier(forWorktreeAt: worktree.path, in: repository.identifier)
            await worktrees.append(read(worktree, of: repository, lastSyncOutcome: outcomes[identifier]))
        }

        return worktrees
    }

    // MARK: - Helpers

    private func read(
        _ worktree: GitWorktree,
        of repository: WorkspaceRepository,
        lastSyncOutcome: RepositorySyncOutcome?
    ) async -> TrackedRepository {
        do {
            let snapshot = try await gitClient.snapshot(at: worktree.path)

            return TrackedRepository(
                shared: repository,
                localPath: worktree.path,
                snapshot: snapshot,
                lastSyncOutcome: lastSyncOutcome,
                worktree: worktree
            )
        } catch {
            return TrackedRepository(
                shared: repository,
                localPath: worktree.path,
                lastSyncOutcome: lastSyncOutcome,
                readError: error,
                worktree: worktree
            )
        }
    }
}
