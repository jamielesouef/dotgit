import Foundation
import Testing
@testable import dotgit

@Suite("ReadinessEvaluationUseCase", .tags(.domain))
struct ReadinessEvaluationUseCaseTests {
    // MARK: - Private

    private func report(
        snapshot: GitRepositorySnapshot,
        repository: WorkspaceRepository = RepositoryFixtures.shared(),
        unpushedTags: [String] = [],
        missingTemplates: [String] = [],
        hasSetupInstructions: Bool = true
    ) -> ReadinessReport {
        ReadinessEvaluationUseCase.report(
            identifier: "app",
            snapshot: snapshot,
            repository: repository,
            signals: ReadinessCheckSignals(
                unpushedTags: unpushedTags,
                missingConfigurationTemplates: missingTemplates,
                hasSetupInstructions: hasSetupInstructions
            )
        )
    }

    private var readyRepository: WorkspaceRepository {
        var repository = RepositoryFixtures.shared()
        repository.setupInstructionsPath = "README.md"

        return repository
    }

    // MARK: - Tests

    @Test("separates a pushed current branch from a project that is fully ready")
    func separatesPushedFromReady() {
        let result = report(
            snapshot: RepositoryFixtures.snapshot(untracked: ["Notes.md"]),
            repository: readyRepository
        )

        #expect(result.currentBranchPushed)
        #expect(result.isReadyToResume == false)
    }

    @Test("reports a project with nothing outstanding as ready to resume")
    func reportsReadyProject() {
        #expect(report(snapshot: RepositoryFixtures.snapshot(), repository: readyRepository).isReadyToResume)
    }

    @Test("surfaces untracked files that may need to be included")
    func surfacesUntrackedFiles() {
        let issues = report(snapshot: RepositoryFixtures.snapshot(untracked: ["Notes.md"])).issues

        #expect(issues.contains(.untrackedFiles(["Notes.md"])))
    }

    @Test("counts unpushed commits on the current branch")
    func countsUnpushedCommits() {
        #expect(report(snapshot: RepositoryFixtures.snapshot(ahead: 3)).issues.contains(.currentBranchNotPushed(3)))
    }

    @Test("reports divergence instead of a plain unpushed branch")
    func reportsDivergenceOverUnpushed() {
        let issues = report(snapshot: RepositoryFixtures.snapshot(ahead: 3, behind: 1)).issues

        #expect(issues.contains(.divergedBranch))
        #expect(issues.contains(.currentBranchNotPushed(3)) == false)
    }

    @Test("separates branches that were never pushed from branches with unpushed commits")
    func separatesBranchKinds() {
        let branches = [
            GitBranchRef(name: "main", upstream: "origin/main", aheadCount: 0, behindCount: 0),
            GitBranchRef(name: "spike", upstream: nil, aheadCount: 0, behindCount: 0),
            GitBranchRef(name: "old", upstream: "origin/old", aheadCount: 4, behindCount: 0)
        ]
        let issues = report(snapshot: RepositoryFixtures.snapshot(branches: branches)).issues

        #expect(issues.contains(.localOnlyBranches(["spike"])))
        #expect(issues.contains(.unpushedBranchCommits(["old"])))
    }

    @Test("reports tags that exist only on this Mac")
    func reportsUnpushedTags() {
        #expect(report(snapshot: RepositoryFixtures.snapshot(), unpushedTags: ["v2.0"])
            .issues
            .contains(.unpushedTags(["v2.0"])))
    }

    @Test("reports submodules that need attention")
    func reportsSubmodules() {
        let submodules = [GitSubmoduleChange(path: "Vendor/Lib", kind: .commitDiffers)]
        let issues = report(snapshot: RepositoryFixtures.snapshot(submodules: submodules)).issues

        #expect(issues.contains(.submoduleChanges(["Vendor/Lib"])))
    }

    @Test("flags missing setup instructions")
    func flagsMissingSetupInstructions() {
        #expect(report(snapshot: RepositoryFixtures.snapshot(), hasSetupInstructions: false)
            .issues
            .contains(.missingSetupInstructions))
    }

    @Test("flags configuration templates the manifest expects but the repository lacks")
    func flagsMissingTemplates() {
        let issues = report(snapshot: RepositoryFixtures.snapshot(), missingTemplates: [".env.example"]).issues

        #expect(issues.contains(.missingConfigurationTemplates([".env.example"])))
    }

    @Test("lists the required environment variable names without their values")
    func listsEnvironmentVariableNames() {
        var repository = readyRepository
        repository.requiredEnvironmentVariableNames = ["API_HOST", "API_TOKEN"]

        let issue = report(snapshot: RepositoryFixtures.snapshot(), repository: repository).issues.last

        #expect(issue == .requiredEnvironmentVariables(["API_HOST", "API_TOKEN"]))
        #expect(issue?.explanation.contains("never copied") == true)
    }

    @Test("explains every issue it raises")
    func explainsEveryIssue() {
        let issues = report(
            snapshot: RepositoryFixtures.snapshot(branch: nil, ahead: 1, untracked: ["A"], remote: nil, upstream: nil),
            hasSetupInstructions: false
        ).issues

        #expect(issues.isEmpty == false)
        #expect(issues.allSatisfy { $0.explanation.isEmpty == false })
    }

    @Test("does not call a detached head a pushed current branch")
    func detachedHeadIsNotPushed() {
        #expect(report(snapshot: RepositoryFixtures.snapshot(branch: nil)).currentBranchPushed == false)
    }
}
