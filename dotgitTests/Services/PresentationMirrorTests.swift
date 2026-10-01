import Foundation
import Testing
@testable import dotgit

@Suite("Intents a view mirrors into @State", .tags(.service))
struct PresentationMirrorTests {
    // MARK: - SyncService

    @Test("leaving the review sheet after the run has finished keeps the summary")
    @MainActor
    func cancelReviewKeepsSummary() async {
        let harness = ServiceHarness()
        await harness.addRepository(
            "a",
            name: "app",
            snapshot: RepositoryFixtures.snapshot(branch: "feature/login", ahead: 1)
        )
        await harness.repositories.start()
        let service = harness.makeSync()
        await service.review(identifiers: nil)
        await service.run()

        service.cancelReview()

        #expect(service.isRunningOrFinished)
    }

    @Test("dismissing the run sheet during review leaves the review open")
    @MainActor
    func dismissSummaryKeepsReview() async {
        let harness = ServiceHarness()
        await harness.addRepository(
            "a",
            name: "app",
            snapshot: RepositoryFixtures.snapshot(branch: "feature/login", ahead: 1)
        )
        await harness.repositories.start()
        let service = harness.makeSync()
        await service.review(identifiers: nil)

        service.dismissSummary()

        #expect(service.reviewPlan != nil)
    }

    @Test("selecting an untracked file twice selects it once and does not rebuild the plan again")
    @MainActor
    func setUntrackedIsIdempotent() async {
        let harness = ServiceHarness()
        await harness.addRepository(
            "a",
            name: "app",
            snapshot: RepositoryFixtures.snapshot(branch: "feature/login", untracked: ["Notes.md"])
        )
        await harness.repositories.start()
        let service = harness.makeSync()
        await service.review(identifiers: nil)
        service.setUntracked("Notes.md", isSelected: true, for: "a")
        let probe = ObservationProbe()
        probe.watch { _ = service.phase }

        service.setUntracked("Notes.md", isSelected: true, for: "a")

        #expect(service.reviewPlan?.actionableSteps.first?.includedUntrackedPaths == ["Notes.md"])
        #expect(probe.didChange == false)
    }

    @Test("deselecting an untracked file drops it from the plan")
    @MainActor
    func setUntrackedDeselects() async {
        let harness = ServiceHarness()
        await harness.addRepository(
            "a",
            name: "app",
            snapshot: RepositoryFixtures.snapshot(branch: "feature/login", untracked: ["Notes.md"])
        )
        await harness.repositories.start()
        let service = harness.makeSync()
        await service.review(identifiers: nil)
        service.setUntracked("Notes.md", isSelected: true, for: "a")

        service.setUntracked("Notes.md", isSelected: false, for: "a")

        #expect(service.isUntrackedSelected("Notes.md", for: "a") == false)
        #expect(service.reviewPlan?.actionableSteps.isEmpty == true)
    }

    // MARK: - RepositoriesService

    @Test("writing back an unchanged repository changes nothing")
    @MainActor
    func updateUnchangedIsNoOp() async {
        let harness = ServiceHarness()
        await harness.addRepository("a", name: "app", snapshot: RepositoryFixtures.snapshot(branch: "main"))
        await harness.repositories.start()
        let shared = harness.repositories.repositories[0].shared
        let probe = ObservationProbe()
        probe.watch { _ = harness.repositories.repositories }

        harness.repositories.update(shared)

        #expect(probe.didChange == false)
    }

    @Test("dismissing a folder that is no longer first leaves the queue alone")
    @MainActor
    func dismissScanDecisionIsIdempotent() async {
        let harness = ServiceHarness()
        let first = URL(filePath: "/dev/one")
        let second = URL(filePath: "/dev/two")
        await harness.repositories.addRepository(at: first)
        await harness.repositories.addRepository(at: second)

        harness.repositories.dismissScanDecision(for: first)
        harness.repositories.dismissScanDecision(for: first)

        #expect(harness.repositories.foldersAwaitingScanDecision == [second])
    }

    // MARK: - ResumeService

    @Test("selecting a step that is already selected changes nothing")
    @MainActor
    func setSelectionUnchangedIsNoOp() async {
        let harness = ServiceHarness()
        await harness.addRepository("a", name: "app", snapshot: RepositoryFixtures.snapshot(behind: 2))
        await harness.repositories.start()
        let service = harness.makeResume()
        service.prepare()
        let isSelected = service.reviewPlan?.steps.first?.isSelected ?? false
        let probe = ObservationProbe()
        probe.watch { _ = service.phase }

        service.setSelection(isSelected, for: "a")

        #expect(probe.didChange == false)
    }
}
