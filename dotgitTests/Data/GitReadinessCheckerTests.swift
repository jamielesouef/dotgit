import Foundation
import Testing
@testable import dotgit

@Suite("GitReadinessChecker", .tags(.data))
struct GitReadinessCheckerTests {
    // MARK: - Private

    private let fileManager = FileManager.default

    private func makeDirectory(_ files: [String]) throws -> URL {
        let root = URL(filePath: NSTemporaryDirectory()).appending(path: "dotgit-readiness-\(UUID().uuidString)")
        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)

        for file in files {
            try "x".write(to: root.appending(path: file), atomically: true, encoding: .utf8)
        }

        return root
    }

    private func input(
        directory: URL,
        repository: WorkspaceRepository,
        checksRemoteTags: Bool = false
    ) -> ReadinessCheckInput {
        ReadinessCheckInput(
            repository: repository,
            directory: directory,
            snapshot: RepositoryFixtures.snapshot(),
            checksRemoteTags: checksRemoteTags
        )
    }

    // MARK: - Tests

    @Test("treats setup instructions that are recorded and present as satisfied")
    func acceptsPresentSetupInstructions() async throws {
        let directory = try makeDirectory(["SETUP.md"])
        defer { try? fileManager.removeItem(at: directory) }
        var repository = RepositoryFixtures.shared()
        repository.setupInstructionsPath = "SETUP.md"

        let report = await GitReadinessChecker(gitClient: StubGitClient(), fileManager: fileManager)
            .evaluate(input(directory: directory, repository: repository))

        #expect(report.issues.contains(.missingSetupInstructions) == false)
    }

    @Test("flags setup instructions the manifest points at but the repository does not have")
    func flagsAbsentSetupInstructions() async throws {
        let directory = try makeDirectory([])
        defer { try? fileManager.removeItem(at: directory) }
        var repository = RepositoryFixtures.shared()
        repository.setupInstructionsPath = "SETUP.md"

        let report = await GitReadinessChecker(gitClient: StubGitClient(), fileManager: fileManager)
            .evaluate(input(directory: directory, repository: repository))

        #expect(report.issues.contains(.missingSetupInstructions))
    }

    @Test("flags only the expected configuration templates that are absent")
    func flagsAbsentTemplatesOnly() async throws {
        let directory = try makeDirectory([".env.example"])
        defer { try? fileManager.removeItem(at: directory) }
        var repository = RepositoryFixtures.shared()
        repository.setupInstructionsPath = ".env.example"
        repository.expectedConfigurationTemplates = [".env.example", "Config/secrets.example.plist"]

        let report = await GitReadinessChecker(gitClient: StubGitClient(), fileManager: fileManager)
            .evaluate(input(directory: directory, repository: repository))

        #expect(report.issues.contains(.missingConfigurationTemplates(["Config/secrets.example.plist"])))
    }

    @Test("asks the remote for its tags only when the check is allowed to")
    func checksRemoteTagsOnDemand() async throws {
        let directory = try makeDirectory([])
        defer { try? fileManager.removeItem(at: directory) }
        let git = StubGitClient()
        await git.setLocalTags(["v1.0", "v2.0"])
        await git.setRemoteTags(["v1.0"])
        let checker = GitReadinessChecker(gitClient: git, fileManager: fileManager)

        let offline = await checker.evaluate(input(directory: directory, repository: RepositoryFixtures.shared()))
        let online = await checker.evaluate(
            input(directory: directory, repository: RepositoryFixtures.shared(), checksRemoteTags: true)
        )

        #expect(offline.issues.contains(.unpushedTags(["v2.0"])) == false)
        #expect(online.issues.contains(.unpushedTags(["v2.0"])))
    }
}
