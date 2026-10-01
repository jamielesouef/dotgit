import Foundation

enum TodaySummaryUseCase {
    static func summary(
        for repositories: [TrackedRepository],
        readiness: [String: ReadinessReport]
    ) -> TodaySummary {
        TodaySummary(
            unfinishedWork: repositories.filter(\.hasLocalOnlyWork),
            syncProblems: repositories.filter { $0.allCheckouts.contains(where: hasSyncProblem) },
            readyToResume: repositories.filter { isReadyToResume($0, readiness: readiness) },
            notClonedHere: repositories.filter { $0.isCloned == false },
            lastSuccessfulSync: repositories.compactMap(\.shared.lastSuccessfulSyncDate).max()
        )
    }

    // MARK: - Helpers

    private static func hasSyncProblem(_ repository: TrackedRepository) -> Bool {
        switch repository.status {
        case .failed,
             .diverged,
             .unreadable:
            true
        case .notCloned,
             .loading:
            false
        case .clean,
             .dirty,
             .ahead,
             .behind:
            repository.snapshot?.hasRemote == false
        }
    }

    private static func isReadyToResume(_ repository: TrackedRepository, readiness: [String: ReadinessReport]) -> Bool {
        guard repository.isCloned, repository.allCheckouts.contains(where: hasSyncProblem) == false else {
            return false
        }
        guard let report = readiness[repository.id] else {
            return repository.hasLocalOnlyWork == false
        }

        return report.isReadyToResume && repository.worktrees.contains(where: \.hasOwnLocalOnlyWork) == false
    }
}
