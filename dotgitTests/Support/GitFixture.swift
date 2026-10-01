import Foundation
@testable import dotgit

struct GitFixture {
    // MARK: - State

    let root: URL
    let workingCopy: URL
    let remote: URL
    let client: ProcessGitClient

    private let runner: ProcessCommandRunner
    private let gitPath: String

    // MARK: - Init

    init?() {
        guard let gitPath = ["/usr/bin/git", "/opt/homebrew/bin/git", "/usr/local/bin/git"]
            .first(where: { FileManager.default.isExecutableFile(atPath: $0) })
        else {
            return nil
        }

        self.gitPath = gitPath
        root = URL(filePath: NSTemporaryDirectory()).appending(path: "dotgit-git-\(UUID().uuidString)")
        workingCopy = root.appending(path: "app")
        remote = root.appending(path: "remote.git")
        runner = ProcessCommandRunner(
            baseEnvironment: [
                "PATH": "/usr/bin:/bin:/usr/sbin:/sbin",
                "HOME": root.path(percentEncoded: false),
                "GIT_CONFIG_GLOBAL": "/dev/null",
                "GIT_CONFIG_SYSTEM": "/dev/null"
            ],
            temporaryDirectory: FileManager.default.temporaryDirectory
        )
        client = ProcessGitClient(commandRunner: runner, gitPath: gitPath)
    }

    // MARK: - Setup

    func create() async throws {
        try FileManager.default.createDirectory(at: workingCopy, withIntermediateDirectories: true)
        try await git(["init", "--initial-branch=main", "--bare", remote.path(percentEncoded: false)], at: root)
        try await git(["init", "--initial-branch=main"], at: workingCopy)
        try await git(["config", "user.email", "tests@example.com"], at: workingCopy)
        try await git(["config", "user.name", "dotgit tests"], at: workingCopy)
        try await git(["remote", "add", "origin", remote.path(percentEncoded: false)], at: workingCopy)
        try write("first\n", to: "README.md")
        try await git(["add", "README.md"], at: workingCopy)
        try await git(["commit", "--message", "First commit"], at: workingCopy)
        try await git(["push", "--set-upstream", "origin", "main"], at: workingCopy)
    }

    func remove() {
        try? FileManager.default.removeItem(at: root)
    }

    // MARK: - Helpers

    func write(_ contents: String, to relativePath: String) throws {
        try contents.write(to: workingCopy.appending(path: relativePath), atomically: true, encoding: .utf8)
    }

    func delete(_ relativePath: String) throws {
        try FileManager.default.removeItem(at: workingCopy.appending(path: relativePath))
    }

    @discardableResult
    func git(_ arguments: [String], at directory: URL) async throws -> CommandResult {
        let request = CommandRequest(
            executablePath: gitPath,
            arguments: arguments,
            workingDirectory: directory,
            extraEnvironment: ["GIT_TERMINAL_PROMPT": "0"]
        )

        return try await runner.run(request)
    }
}
