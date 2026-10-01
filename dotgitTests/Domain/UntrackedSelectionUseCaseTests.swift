import Foundation
import Testing
@testable import dotgit

@Suite("UntrackedSelectionUseCase", .tags(.domain))
struct UntrackedSelectionUseCaseTests {
    // MARK: - Private

    private func step(_ identifier: String, untracked: [String], included: [String] = []) -> SyncPlanStep {
        SyncPlanStep(
            identifier: identifier,
            repositoryName: identifier,
            branch: "feature/login",
            action: .commitAndPush(willCommit: true, setsUpstream: false),
            trackedChanges: [],
            selectableUntrackedPaths: untracked,
            includedUntrackedPaths: included,
            outstandingBranches: [],
            submoduleChanges: []
        )
    }

    // MARK: - Defaults

    @Test("leaves earlier picks alone when untracked files are not included by default")
    func keepsPicksWhenOff() {
        let checkout = RepositoryFixtures.tracked("a", snapshot: RepositoryFixtures.snapshot(untracked: ["A", "B"]))

        let selections = UntrackedSelectionUseCase.startingSelections(
            for: [checkout],
            existing: ["a": ["A"]],
            includesByDefault: false
        )

        #expect(selections == ["a": ["A"]])
    }

    @Test("starts every review with each checkout's untracked files ticked when included by default")
    func ticksEverythingWhenOn() {
        let checkout = RepositoryFixtures.tracked("a", snapshot: RepositoryFixtures.snapshot(untracked: ["A", "B"]))

        let selections = UntrackedSelectionUseCase.startingSelections(
            for: [checkout],
            existing: ["a": [], "other": ["X"]],
            includesByDefault: true
        )

        #expect(selections == ["a": ["A", "B"], "other": ["X"]])
    }

    // MARK: - Select all

    @Test("selects and deselects every untracked file across the steps it is given")
    func selectsAll() {
        let steps = [step("a", untracked: ["A", "B"]), step("b", untracked: []), step("c", untracked: ["C"])]

        let all = UntrackedSelectionUseCase.selectingAll(true, in: steps, existing: ["a": ["A"]])
        let none = UntrackedSelectionUseCase.selectingAll(false, in: steps, existing: all)

        #expect(all == ["a": ["A", "B"], "c": ["C"]])
        #expect(none == ["a": [], "c": []])
    }

    @Test("reports everything picked only when every step with untracked files has all of them")
    func reportsEverythingPicked() {
        let partly = SyncPlan(steps: [step("a", untracked: ["A"], included: ["A"]), step("b", untracked: ["B"])])
        let fully = SyncPlan(steps: [step("a", untracked: ["A"], included: ["A"]), step("b", untracked: [])])

        #expect(partly.includesAllUntracked == false)
        #expect(fully.includesAllUntracked)
        #expect(SyncPlan(steps: [step("a", untracked: [])]).hasUntrackedFiles == false)
    }

    @Test("offers to deselect once everything is picked")
    func namesTheButton() {
        #expect(UntrackedSelectionUseCase.selectAllTitle(isEverythingSelected: false) == "Select all untracked files")
        #expect(UntrackedSelectionUseCase.selectAllTitle(isEverythingSelected: true) == "Deselect all untracked files")
    }
}
