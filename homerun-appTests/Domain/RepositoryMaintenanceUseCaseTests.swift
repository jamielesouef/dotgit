import Foundation
import Testing
@testable import homerun_app

@Suite("RepositoryMaintenanceUseCase", .tags(.domain))
struct RepositoryMaintenanceUseCaseTests {
    @Test("names the local path mappings whose folder has gone")
    func namesStaleMappings() {
        let paths = ["a": "/gone", "b": "/here"]

        let stale = RepositoryMaintenanceUseCase.staleLocalPathIdentifiers(repositoryPaths: paths) { $0 == "/here" }

        #expect(stale == ["a"])
    }

    @Test("names the duplicate shared entries")
    func namesDuplicates() {
        let repositories = [
            RepositoryFixtures.shared("a"),
            RepositoryFixtures.shared("b"),
            RepositoryFixtures.shared("a")
        ]

        #expect(RepositoryMaintenanceUseCase.duplicateIdentifiers(in: repositories) == ["a"])
    }

    @Test("collapses the same folder discovered twice")
    func collapsesRepeatedDiscovery() {
        let discovered = [
            DiscoveredRepository(url: URL(filePath: "/dev/app")),
            DiscoveredRepository(url: URL(filePath: "/dev/./app")),
            DiscoveredRepository(url: URL(filePath: "/dev/other"))
        ]

        #expect(RepositoryMaintenanceUseCase.deduplicated(discovered).count == 2)
    }

    @Test("keeps the settings of a repository that is added again")
    func keepsSettingsOnReAdd() {
        var existing = RepositoryFixtures.shared("remote:github.com/acme/app")
        existing.wipCommitPrefixOverride = "SCRATCH"
        existing.allowsMainBranchSync = true

        let merged = RepositoryMaintenanceUseCase.merged(
            existing: existing,
            identifier: existing.identifier,
            discovered: DiscoveredRepository(url: URL(filePath: "/dev/app")),
            remoteURL: "git@github.com:acme/app.git",
            addedDate: .distantFuture
        )

        #expect(merged.wipCommitPrefixOverride == "SCRATCH")
        #expect(merged.allowsMainBranchSync)
        #expect(merged.name == "app")
    }

    @Test("creates a new entry under the given identifier, keeping the remote as written")
    func createsNewEntry() {
        let merged = RepositoryMaintenanceUseCase.merged(
            existing: nil,
            identifier: "remote:github.com/acme/app",
            discovered: DiscoveredRepository(url: URL(filePath: "/dev/app")),
            remoteURL: "git@github-work:acme/app.git",
            addedDate: .distantFuture
        )

        #expect(merged.identifier == "remote:github.com/acme/app")
        #expect(merged.remoteURL == "git@github-work:acme/app.git")
        #expect(merged.preferredRelativePath == "app")
    }
}
