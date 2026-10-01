import Foundation
import Testing
@testable import dotgit

@Suite("OnboardingRequirementUseCase", .tags(.domain))
struct OnboardingRequirementUseCaseTests {
    // MARK: - Private

    private var account: GitHubAccount {
        GitHubAccount(login: "jamie", host: "github.com", isActive: true)
    }

    private func availability(
        git: Bool = true,
        isGitHubCLIAvailable: Bool = true,
        accounts: [GitHubAccount] = []
    ) -> ToolAvailability {
        ToolAvailability(isGitAvailable: git, isGitHubCLIAvailable: isGitHubCLIAvailable, gitHubAccounts: accounts)
    }

    // MARK: - Tests

    @Test("treats a missing git as the one thing that blocks the app")
    func treatsGitAsRequired() {
        let requirements = OnboardingRequirementUseCase.requirements(
            for: availability(git: false, isGitHubCLIAvailable: false)
        )

        #expect(requirements.contains(.gitMissing))
        #expect(requirements.filter(\.isBlocking) == [.gitMissing])
    }

    @Test("treats the GitHub CLI as optional")
    func treatsGitHubCLIAsOptional() {
        #expect(
            OnboardingRequirementUseCase.requirements(for: availability(isGitHubCLIAvailable: false)) ==
                [.gitHubCLIMissing]
        )
        #expect(OnboardingRequirement.gitHubCLIMissing.isBlocking == false)
    }

    @Test("reports gh as signed out when it is installed with no account")
    func reportsSignedOutCLI() {
        #expect(OnboardingRequirementUseCase.requirements(for: availability()) == [.gitHubCLINotAuthenticated])
    }

    @Test("keeps ordinary git sync available without gh")
    func keepsGitSyncWithoutCLI() {
        let capabilities = OnboardingRequirementUseCase.capabilities(for: availability(isGitHubCLIAvailable: false))

        #expect(capabilities == [.gitSync])
    }

    @Test("enables account management and fallback only once gh is installed and signed in")
    func enablesAccountFeaturesWhenAuthenticated() {
        #expect(OnboardingRequirementUseCase.capabilities(for: availability()) == [.gitSync])
        #expect(OnboardingRequirementUseCase.capabilities(for: availability(accounts: [account]))
            == [.gitSync, .gitHubAccountManagement, .gitHubAccountFallback])
    }

    @Test("skips onboarding when every check passes")
    func skipsWhenChecksPass() {
        let skips = OnboardingRequirementUseCase.canSkipOnboarding(
            availability: availability(accounts: [account]),
            hasCompletedOnboarding: false
        )

        #expect(skips)
    }

    @Test("skips onboarding again once it has been completed, even without gh")
    func skipsAfterCompletion() {
        let skips = OnboardingRequirementUseCase.canSkipOnboarding(
            availability: availability(isGitHubCLIAvailable: false),
            hasCompletedOnboarding: true
        )

        #expect(skips)
    }

    @Test("never skips onboarding while git is missing")
    func neverSkipsWithoutGit() {
        let skips = OnboardingRequirementUseCase.canSkipOnboarding(
            availability: availability(git: false),
            hasCompletedOnboarding: true
        )

        #expect(skips == false)
    }
}

@Suite("TodaySummaryUseCase", .tags(.domain))
struct TodaySummaryUseCaseTests {
    // MARK: - Private

    private let dirty = RepositoryFixtures.tracked(
        "dirty",
        name: "dirty",
        snapshot: RepositoryFixtures.snapshot(tracked: [GitFileChange(path: "A", status: .modified)]),
        lastSynced: Date(timeIntervalSince1970: 100)
    )
    private let diverged = RepositoryFixtures.tracked(
        "diverged",
        name: "diverged",
        snapshot: RepositoryFixtures.snapshot(ahead: 1, behind: 1)
    )
    private let settled = RepositoryFixtures.tracked(
        "settled",
        name: "settled",
        snapshot: RepositoryFixtures.snapshot(),
        lastSynced: Date(timeIntervalSince1970: 500)
    )
    private let absent = RepositoryFixtures.tracked("absent", name: "absent", path: nil)

    private var all: [TrackedRepository] {
        [dirty, diverged, settled, absent]
    }

    // MARK: - Tests

    @Test("highlights the repositories with work that exists only on this Mac")
    func highlightsLocalOnlyWork() {
        let summary = TodaySummaryUseCase.summary(for: all, readiness: [:])

        #expect(summary.unfinishedWork.map(\.name) == ["dirty", "diverged"])
        #expect(summary.localOnlyCount == 2)
    }

    @Test("separates sync problems from ordinary unfinished work")
    func separatesSyncProblems() {
        let summary = TodaySummaryUseCase.summary(for: all, readiness: [:])

        #expect(summary.syncProblems.map(\.name) == ["diverged"])
    }

    @Test("lists repositories that are not cloned here without treating them as problems")
    func listsNotClonedSeparately() {
        let summary = TodaySummaryUseCase.summary(for: all, readiness: [:])

        #expect(summary.notClonedHere.map(\.name) == ["absent"])
        #expect(summary.syncProblems.map(\.name).contains("absent") == false)
    }

    @Test("reports the most recent successful sync across every repository")
    func reportsLastSync() {
        #expect(TodaySummaryUseCase.summary(for: all, readiness: [:])
            .lastSuccessfulSync == Date(timeIntervalSince1970: 500))
    }

    @Test("lists a project as ready to resume only when its readiness report says so")
    func listsReadyProjects() {
        let ready = ReadinessReport(identifier: "settled", currentBranchPushed: true, issues: [])
        let notReady = ReadinessReport(
            identifier: "settled",
            currentBranchPushed: true,
            issues: [.missingSetupInstructions]
        )

        #expect(TodaySummaryUseCase.summary(for: all, readiness: ["settled": ready])
            .readyToResume
            .map(\.name) == ["settled"])
        #expect(TodaySummaryUseCase.summary(for: all, readiness: ["settled": notReady]).readyToResume.isEmpty)
    }

    @Test("says nothing needs attention when every repository is settled")
    func reportsNothingToDo() {
        #expect(TodaySummaryUseCase.summary(for: [settled], readiness: [:]).needsAttention == false)
    }
}
