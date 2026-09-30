import Foundation
import Testing
@testable import homerun_app

@Suite("SyncHandoffUseCase", .tags(.domain))
struct SyncHandoffUseCaseTests {
    @Test("records where to resume from after a successful push")
    func recordsHandoff() {
        let outcome = RepositorySyncOutcome(
            identifier: "a",
            result: .succeeded(commit: "abc123", branch: "feature/login"),
            finishedAt: Date(timeIntervalSince1970: 500)
        )

        let recorded = SyncHandoffUseCase.recording(outcome, in: RepositoryFixtures.shared("a"))

        #expect(recorded?.handoff == RepositoryHandoff(
            branch: "feature/login",
            commit: "abc123",
            recordedAt: Date(timeIntervalSince1970: 500)
        ))
        #expect(recorded?.lastSuccessfulSyncDate == Date(timeIntervalSince1970: 500))
    }

    @Test("dates the sync but leaves the handoff alone when nothing was pushed")
    func keepsHandoffWithoutCommit() {
        var repository = RepositoryFixtures.shared("a")
        let earlier = RepositoryHandoff(branch: "main", commit: "old", recordedAt: .distantPast)
        repository.handoff = earlier
        let outcome = RepositorySyncOutcome(
            identifier: "a",
            result: .succeeded(commit: nil, branch: nil),
            finishedAt: Date(timeIntervalSince1970: 500)
        )

        let recorded = SyncHandoffUseCase.recording(outcome, in: repository)

        #expect(recorded?.handoff == earlier)
        #expect(recorded?.lastSuccessfulSyncDate == Date(timeIntervalSince1970: 500))
    }

    @Test("changes nothing when the sync failed")
    func ignoresFailure() {
        let outcome = RepositorySyncOutcome(identifier: "a", result: .failed(.diverged), finishedAt: .distantPast)

        #expect(SyncHandoffUseCase.recording(outcome, in: RepositoryFixtures.shared("a")) == nil)
    }
}
