import Foundation
import Testing
@testable import dotgit

@Suite("MenuBarStatusUseCase", .tags(.domain))
struct MenuBarStatusUseCaseTests {
    // MARK: - Private

    private func summary(_ repositories: [TrackedRepository]) -> TodaySummary {
        TodaySummaryUseCase.summary(for: repositories, readiness: [:])
    }

    // MARK: - Tests

    @Test("says everything is pushed when nothing is outstanding")
    func reportsAllClear() {
        let status = MenuBarStatusUseCase.status(
            for: summary([RepositoryFixtures.tracked(snapshot: RepositoryFixtures.snapshot())])
        )

        #expect(status.level == .allClear)
        #expect(status.summary.isEmpty == false)
    }

    @Test("counts the repositories with work only on this Mac")
    func countsLocalOnlyWork() {
        let status = MenuBarStatusUseCase.status(
            for: summary([RepositoryFixtures.tracked(snapshot: RepositoryFixtures.snapshot(ahead: 1))])
        )

        #expect(status.level == .localOnlyWork)
        #expect(status.localOnlyCount == 1)
    }

    @Test("raises a problem above ordinary unfinished work")
    func raisesProblems() {
        let status = MenuBarStatusUseCase.status(
            for: summary([RepositoryFixtures.tracked(snapshot: RepositoryFixtures.snapshot(ahead: 1, behind: 1))])
        )

        #expect(status.level == .problems)
    }

    @Test("shows the count only when this Mac asked for it")
    func showsCountOnDemand() {
        let status = MenuBarStatus(level: .localOnlyWork, localOnlyCount: 3, problemCount: 0, lastSuccessfulSync: nil)

        #expect(MenuBarStatusUseCase.badgeText(for: status, showsCount: true) == "3")
        #expect(MenuBarStatusUseCase.badgeText(for: status, showsCount: false) == nil)
    }

    @Test("shows no badge when there is nothing to count")
    func showsNoBadgeWhenClear() {
        #expect(MenuBarStatusUseCase.badgeText(for: .allClear, showsCount: true) == nil)
    }
}
