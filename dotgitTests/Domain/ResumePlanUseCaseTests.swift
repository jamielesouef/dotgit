import Foundation
import Testing
@testable import dotgit

@Suite("ResumePlanUseCase", .tags(.domain))
struct ResumePlanUseCaseTests {
    // MARK: - Private

    private let root = URL(filePath: "/Users/jamie/Developer")

    private func step(
        _ repository: TrackedRepository,
        workspaceRoot: URL? = URL(filePath: "/Users/jamie/Developer"),
        preselectsSafeFastForward: Bool = true
    ) -> ResumeStep {
        ResumePlanUseCase.step(
            for: repository,
            workspaceRoot: workspaceRoot,
            preselectsSafeFastForward: preselectsSafeFastForward
        )
    }

    private func withHandoff(_ handoff: RepositoryHandoff, snapshot: GitRepositorySnapshot) -> TrackedRepository {
        TrackedRepository(
            shared: RepositoryFixtures.shared(handoff: handoff),
            localPath: URL(filePath: "/Users/jamie/Developer/app"),
            snapshot: snapshot
        )
    }

    // MARK: - Tests

    @Test("identifies a repository that is missing from this Mac as one to clone")
    func identifiesMissingRepository() {
        #expect(step(RepositoryFixtures.tracked(path: nil))
            .action == .clone(URL(filePath: "/Users/jamie/Developer/app")))
    }

    @Test("fast-forwards a clean repository that is only behind")
    func fastForwardsCleanRepository() {
        #expect(step(RepositoryFixtures.tracked(snapshot: RepositoryFixtures.snapshot(behind: 4)))
            .action == .fastForward(4))
    }

    @Test("preselects a safe fast-forward only when the setting asks for it", arguments: [true, false])
    func honoursFastForwardPreselection(preselects: Bool) {
        let repository = RepositoryFixtures.tracked(snapshot: RepositoryFixtures.snapshot(behind: 1))

        #expect(step(repository, preselectsSafeFastForward: preselects).isSelected == preselects)
    }

    @Test("always preselects a clone, whatever the fast-forward setting says")
    func alwaysPreselectsClone() {
        #expect(step(RepositoryFixtures.tracked(path: nil), preselectsSafeFastForward: false).isSelected)
    }

    @Test("flags local changes before updating instead of overwriting them")
    func flagsLocalChanges() {
        let snapshot = RepositoryFixtures.snapshot(
            behind: 2,
            tracked: [GitFileChange(path: "A.swift", status: .modified)],
            untracked: ["Notes.md"]
        )

        #expect(step(RepositoryFixtures.tracked(snapshot: snapshot)).action == .blockedByLocalChanges(2))
    }

    @Test("flags a diverged branch rather than merging or rebasing it")
    func flagsDivergence() {
        #expect(step(RepositoryFixtures.tracked(snapshot: RepositoryFixtures.snapshot(ahead: 1, behind: 1)))
            .action == .blockedByDivergence)
    }

    @Test("checks out the branch the previous Mac was on when it is already here")
    func checksOutHandoffBranch() {
        let branches = [GitBranchRef(
            name: "feature/login",
            upstream: "origin/feature/login",
            aheadCount: 0,
            behindCount: 0
        )]
        let repository = withHandoff(
            RepositoryHandoff(branch: "feature/login", commit: "abc", recordedAt: .distantPast),
            snapshot: RepositoryFixtures.snapshot(branch: "main", branches: branches)
        )

        #expect(step(repository).action == .checkoutHandoffBranch("feature/login"))
    }

    @Test("says the handoff branch is not here yet when nothing local matches it")
    func reportsMissingHandoffBranch() {
        let repository = withHandoff(
            RepositoryHandoff(branch: "feature/login", commit: "abc", recordedAt: .distantPast),
            snapshot: RepositoryFixtures.snapshot(branch: "main", branches: [])
        )

        #expect(step(repository).action == .handoffBranchMissing("feature/login"))
    }

    @Test("leaves a repository already on the handoff branch and up to date alone")
    func leavesReadyRepositoryAlone() {
        let repository = withHandoff(
            RepositoryHandoff(branch: "main", commit: "abc", recordedAt: .distantPast),
            snapshot: RepositoryFixtures.snapshot(branch: "main")
        )

        #expect(step(repository).action == .upToDate)
        #expect(step(repository).isSelected == false)
    }

    @Test("cannot clone until this Mac has a workspace root")
    func blocksCloneWithoutRoot() {
        #expect(step(RepositoryFixtures.tracked(path: nil), workspaceRoot: nil).action == .noWorkspaceRoot)
    }

    @Test("separates the selected work from what is blocked")
    func separatesSelectedFromBlocked() {
        let plan = ResumePlanUseCase.plan(
            for: [
                RepositoryFixtures.tracked("a", name: "a", snapshot: RepositoryFixtures.snapshot(behind: 1)),
                RepositoryFixtures.tracked("b", name: "b", snapshot: RepositoryFixtures.snapshot(ahead: 1, behind: 1))
            ],
            workspaceRoot: root,
            preselectsSafeFastForward: true
        )

        #expect(plan.selectedSteps.map(\.name) == ["a"])
        #expect(plan.blockedSteps.map(\.name) == ["b"])
    }

    @Test("lets the review deselect a step before it runs")
    func allowsDeselection() {
        var plan = ResumePlanUseCase.plan(
            for: [RepositoryFixtures.tracked("a", name: "a", snapshot: RepositoryFixtures.snapshot(behind: 1))],
            workspaceRoot: root,
            preselectsSafeFastForward: true
        )

        plan.setSelection(false, for: "a")

        #expect(plan.isEmpty)
    }
}
