import Foundation
import Testing
@testable import dotgit

@Suite("GitHubAccountsService set-to-value intents", .tags(.service))
struct GitHubAccountsServiceIntentTests {
    // MARK: - Tests

    @Test("associating the account a repository already prefers writes nothing")
    @MainActor
    func associatingUnchangedAccountWritesNothing() async {
        let harness = ServiceHarness()
        await harness.addRepository("a", name: "app", snapshot: RepositoryFixtures.snapshot())
        await harness.repositories.start()
        let service = harness.makeAccounts()

        guard let repository = harness.repositories.repositories.first else {
            Issue.record("expected a repository")
            return
        }

        harness.sharedStore.repositories[0].preferredGitHubAccount = "written-elsewhere"

        service.associate(repository.shared.preferredGitHubAccount, with: repository)

        #expect(harness.sharedStore.repositories.first?.preferredGitHubAccount == "written-elsewhere")
    }
}
