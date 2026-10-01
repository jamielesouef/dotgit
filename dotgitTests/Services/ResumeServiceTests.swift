import Foundation
import Testing
@testable import dotgit

@Suite("ResumeService", .tags(.service))
struct ResumeServiceTests {
    @Test("preselects a clone and, when the setting allows, a safe fast-forward")
    @MainActor
    func preselectsSafeWork() async {
        let harness = ServiceHarness()
        harness.addUnclonedRepository("a", name: "a")
        await harness.addRepository("b", name: "b", snapshot: RepositoryFixtures.snapshot(behind: 2))
        harness.settings.updateLocalSettings { $0.workspaceRootPath = "/dev" }
        await harness.repositories.start()
        let service = harness.makeResume()

        service.prepare()

        #expect(service.reviewPlan?.selectedSteps.map(\.name).sorted() == ["a", "b"])
    }

    @Test("leaves a safe fast-forward unselected when the setting says not to preselect it")
    @MainActor
    func honoursFastForwardSetting() async {
        let harness = ServiceHarness()
        await harness.addRepository("b", name: "b", snapshot: RepositoryFixtures.snapshot(behind: 2))
        harness.settings.updatePreferences { $0.preselectsSafeFastForward = false }
        await harness.repositories.start()
        let service = harness.makeResume()

        service.prepare()

        #expect(service.reviewPlan?.isEmpty == true)
    }

    @Test("clones a missing repository into this Mac's workspace root and records the path")
    @MainActor
    func clonesMissingRepository() async {
        let harness = ServiceHarness()
        harness.addUnclonedRepository("remote:github.com/acme/app", name: "app")
        harness.settings.updateLocalSettings { $0.workspaceRootPath = "/dev" }
        await harness.repositories.start()
        let service = harness.makeResume()
        service.prepare()

        await service.run()

        #expect(await harness.gitClient.clones.first?.destination == URL(filePath: "/dev/app"))
        #expect(harness.localStore.settings.repositoryPaths["remote:github.com/acme/app"] == "/dev/app")
    }

    @Test("checks out the handoff branch after cloning when the previous Mac recorded one")
    @MainActor
    func checksOutHandoffAfterClone() async {
        let harness = ServiceHarness()
        let handoff = RepositoryHandoff(branch: "feature/login", commit: "abc", recordedAt: .distantPast)
        harness.addUnclonedRepository(
            "a",
            name: "app",
            shared: RepositoryFixtures.shared("a", name: "app", handoff: handoff)
        )
        harness.settings.updateLocalSettings { $0.workspaceRootPath = "/dev" }
        await harness.repositories.start()
        await harness.gitClient.setExistingBranches(["feature/login"])
        let service = harness.makeResume()
        service.prepare()

        await service.run()

        #expect(await harness.gitClient.checkouts == ["feature/login"])
    }

    @Test("fetches before fast-forwarding so the update is real")
    @MainActor
    func fetchesBeforeFastForward() async {
        let harness = ServiceHarness()
        await harness.addRepository("a", name: "app", snapshot: RepositoryFixtures.snapshot(behind: 2))
        await harness.repositories.start()
        let service = harness.makeResume()
        service.prepare()

        await service.run()

        let calls = await harness.gitClient.calls
        #expect(calls.contains("fetch"))
        #expect(calls.firstIndex(of: "fetch") ?? 0 < calls.firstIndex(of: "fastForward") ?? 0)
    }

    @Test("never updates a repository with local changes")
    @MainActor
    func neverUpdatesDirtyRepository() async {
        let harness = ServiceHarness()
        await harness.addRepository(
            "a",
            name: "app",
            snapshot: RepositoryFixtures.snapshot(behind: 2, tracked: [GitFileChange(path: "A", status: .modified)])
        )
        await harness.repositories.start()
        let service = harness.makeResume()
        service.prepare()

        await service.run()

        #expect(await harness.gitClient.calls.contains("fastForward") == false)
        #expect(service.reviewPlan == nil)
    }

    @Test("reports a failed update rather than treating it as done")
    @MainActor
    func reportsFailedUpdate() async {
        let harness = ServiceHarness()
        await harness.addRepository("a", name: "app", snapshot: RepositoryFixtures.snapshot(behind: 2))
        await harness.repositories.start()
        await harness.gitClient.setFastForwardError(.commandFailed("locked"))
        let service = harness.makeResume()
        service.prepare()

        await service.run()

        guard case let .finished(summary) = service.phase else {
            Issue.record("expected a finished summary")
            return
        }

        #expect(summary.failedCount == 1)
    }

    @Test("offers to open a project only once it is ready")
    @MainActor
    func offersToOpenReadyProject() async {
        let harness = ServiceHarness()
        await harness.addRepository("a", name: "app", snapshot: RepositoryFixtures.snapshot(behind: 2))
        await harness.repositories.start()
        let service = harness.makeResume()
        service.prepare()
        await service.run()

        guard case let .finished(summary) = service.phase, let outcome = summary.openableProjects.first else {
            Issue.record("expected an openable project")
            return
        }

        #expect(await service.open(outcome))
        #expect(await harness.projectOpener.opened.count == 1)
    }

    @Test("opens a project with this Mac's preferred application")
    @MainActor
    func opensWithPreferredApplication() async {
        let harness = ServiceHarness()
        harness.settings.updateLocalSettings { $0.preferredOpenApplicationPath = "/Applications/Xcode.app" }
        await harness.addRepository("a", name: "app", snapshot: RepositoryFixtures.snapshot(behind: 2))
        await harness.repositories.start()
        let service = harness.makeResume()
        service.prepare()
        await service.run()

        guard case let .finished(summary) = service.phase, let outcome = summary.openableProjects.first else {
            Issue.record("expected an openable project")
            return
        }

        _ = await service.open(outcome)

        #expect(await harness.projectOpener.opened.first?.application == URL(filePath: "/Applications/Xcode.app"))
    }

    @Test("respects a step the review deselected")
    @MainActor
    func respectsDeselection() async {
        let harness = ServiceHarness()
        await harness.addRepository("a", name: "app", snapshot: RepositoryFixtures.snapshot(behind: 2))
        await harness.repositories.start()
        let service = harness.makeResume()
        service.prepare()

        service.setSelection(false, for: "a")
        await service.run()

        #expect(await harness.gitClient.calls.contains("fastForward") == false)
    }
}
