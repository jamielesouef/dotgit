import Foundation

enum SyncHandoffUseCase {
    /// The shared record after a sync, carrying the branch and commit another Mac
    /// should resume from. `nil` when the sync did not succeed and nothing changes.
    static func recording(
        _ outcome: RepositorySyncOutcome,
        in repository: WorkspaceRepository
    ) -> WorkspaceRepository? {
        guard case let .succeeded(commit, branch) = outcome.result else {
            return nil
        }

        var recorded = repository
        recorded.lastSuccessfulSyncDate = outcome.finishedAt

        if let commit, let branch {
            recorded.handoff = RepositoryHandoff(branch: branch, commit: commit, recordedAt: outcome.finishedAt)
        }

        return recorded
    }
}
