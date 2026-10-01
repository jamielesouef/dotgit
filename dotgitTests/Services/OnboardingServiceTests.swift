import Foundation
import Testing
@testable import dotgit

@Suite("OnboardingService", .tags(.service))
struct OnboardingServiceTests {
    @Test("reports the app as ready once git and a signed-in gh are both there")
    @MainActor
    func reportsReady() async {
        let harness = ServiceHarness()
        await harness.gitHubClient.setAccounts([GitHubAccount(login: "jamie", host: "github.com", isActive: true)])
        let service = harness.makeOnboarding()

        await service.start()

        #expect(service.loadState == .ready)
        #expect(service.showsOnboarding == false)
    }

    @Test("blocks on a missing git")
    @MainActor
    func blocksOnMissingGit() async {
        let harness = ServiceHarness()
        await harness.gitClient.setAvailable(false)
        let service = harness.makeOnboarding()

        await service.start()

        #expect(service.loadState == .blocked([.gitMissing, .gitHubCLINotAuthenticated]))
        #expect(service.showsOnboarding)
    }

    @Test("treats a missing gh as optional and still offers git sync")
    @MainActor
    func treatsGitHubCLIAsOptional() async {
        let harness = ServiceHarness()
        await harness.gitHubClient.setAvailable(false)
        let service = harness.makeOnboarding()

        await service.start()

        #expect(service.loadState == .optional([.gitHubCLIMissing]))
        #expect(service.capabilities == [.gitSync])
    }

    @Test("stops showing onboarding once it has been completed")
    @MainActor
    func stopsShowingAfterCompletion() async {
        let harness = ServiceHarness()
        await harness.gitHubClient.setAvailable(false)
        let service = harness.makeOnboarding()
        await service.start()

        service.markCompleted()

        #expect(service.showsOnboarding == false)
        #expect(harness.localStore.settings.hasCompletedOnboarding)
    }

    @Test("only checks the tools once however often the view appears")
    @MainActor
    func checksOnce() async {
        let harness = ServiceHarness()
        let service = harness.makeOnboarding()

        await service.start()
        await service.start()

        #expect(await harness.gitHubClient.accessChecks.isEmpty)
        #expect(service.availability.isGitAvailable)
    }

    @Test("shows each startup check as it finishes while the slow sign-in check is still running")
    @MainActor
    func showsStartupChecksAsTheyFinish() async {
        let harness = ServiceHarness()
        await harness.gitHubClient.setAccounts([GitHubAccount(login: "jamie", host: "github.com", isActive: true)])
        await harness.gitHubClient.holdAccounts()
        let service = harness.makeOnboarding()

        let starting = Task { await service.start() }
        await harness.gitHubClient.waitUntilAccountsRequested()

        guard case let .checking(steps) = service.loadState else {
            Issue.record("Expected the launch checks to still be running")
            return
        }

        #expect(steps.first { $0.check == .gitHubCLI }?.status == .passed)
        #expect(steps.first { $0.check == .gitHubAccounts }?.status == .running)

        await harness.gitHubClient.releaseAccounts()
        await starting.value

        #expect(service.loadState == .ready)
    }

    @Test("records a sign-in failure instead of dropping it")
    @MainActor
    func recordsSignInFailure() async {
        let harness = ServiceHarness()
        await harness.gitHubClient.setAvailable(false)
        let service = harness.makeOnboarding()
        await harness.gitHubClient.setAccountsError(.notInstalled)

        await service.signIn()

        #expect(await harness.gitHubClient.signInCount == 1)
    }
}
