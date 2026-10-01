import Foundation

struct ProcessGitClient: GitClienting {
    // MARK: - Private

    private static let nonInteractiveEnvironment = [
        "GIT_TERMINAL_PROMPT": "0",
        "GIT_ASKPASS": "/usr/bin/true",
        "SSH_ASKPASS": "/usr/bin/true",
        "GIT_OPTIONAL_LOCKS": "0"
    ]

    private let commandRunner: any CommandRunning
    private let gitPath: String

    // MARK: - Init

    init(commandRunner: any CommandRunning, gitPath: String) {
        self.commandRunner = commandRunner
        self.gitPath = gitPath
    }

    // MARK: - GitClienting

    func isAvailable() async -> Bool {
        let result = try? await run(["--version"], at: nil)

        return result?.succeeded == true
    }

    func isRepository(at url: URL) async -> Bool {
        let result = try? await run(["rev-parse", "--is-inside-work-tree"], at: url)

        return result?.trimmedOutput == "true"
    }

    func snapshot(at url: URL) async throws(GitError) -> GitRepositorySnapshot {
        guard await isRepository(at: url) else {
            throw .notARepository(url.path(percentEncoded: false))
        }

        let branchResult = try await run(["rev-parse", "--abbrev-ref", "HEAD"], at: url)
        let rawBranch = branchResult.trimmedOutput
        let currentBranch = (rawBranch == "HEAD" || rawBranch.isEmpty) ? nil : rawBranch

        let headResult = try? await runChecked(["rev-parse", "HEAD"], at: url)
        let headCommit = headResult?.trimmedOutput

        let remotes = try await run(["remote"], at: url).outputLines
        let remoteName = remotes.contains("origin") ? "origin" : remotes.first

        var remoteURL: String?
        if let remoteName {
            remoteURL = try? await runChecked(["config", "--get", "remote.\(remoteName).url"], at: url).trimmedOutput
        }

        let upstreamResult = try? await runChecked(
            ["rev-parse", "--abbrev-ref", "--symbolic-full-name", "@{upstream}"],
            at: url
        )

        let upstreamBranch = upstreamResult?.trimmedOutput

        let (ahead, behind) = await aheadBehindCounts(upstreamBranch: upstreamBranch, at: url)

        let statusResult = try await run(
            ["status", "--porcelain=v1", "-z", "--untracked-files=all"],
            at: url
        )

        let workingTree = GitStatusParser.parse(porcelainZ: statusResult.standardOutput)

        let branchesResult = try await run(
            ["for-each-ref", "--format=\(GitBranchParser.format)", "refs/heads"],
            at: url
        )

        let branches = GitBranchParser.parse(forEachRef: branchesResult.standardOutput)

        let submoduleResult = try? await runChecked(["submodule", "status", "--recursive"], at: url)
        let submoduleChanges = GitSubmoduleParser.parse(statusOutput: submoduleResult?.standardOutput ?? "")

        return GitRepositorySnapshot(
            currentBranch: currentBranch,
            headCommit: headCommit,
            defaultRemoteName: remoteName,
            remoteURL: remoteURL?.isEmpty == true ? nil : remoteURL,
            upstreamBranch: upstreamBranch?.isEmpty == true ? nil : upstreamBranch,
            aheadCount: ahead,
            behindCount: behind,
            workingTree: workingTree,
            branches: branches,
            submoduleChanges: submoduleChanges
        )
    }

    func worktrees(at url: URL) async throws(GitError) -> [GitWorktree] {
        let result = try await runChecked(["worktree", "list", "--porcelain"], at: url)

        return GitWorktreeParser.parse(porcelain: result.standardOutput)
    }

    func recentCommits(at url: URL, limit: Int) async throws(GitError) -> [GitCommitSummary] {
        let result = try await runChecked(
            ["log", "--max-count=\(limit)", "--format=\(GitLogParser.format)"],
            at: url
        )

        return GitLogParser.parse(logOutput: result.standardOutput)
    }

    func diffSummary(at url: URL) async throws(GitError) -> String {
        let result = try await runChecked(["diff", "--stat", "HEAD"], at: url)

        return result.standardOutput
    }

    func stageTrackedChanges(at url: URL) async throws(GitError) {
        _ = try await runChecked(["add", "--update", "--", "."], at: url)
    }

    func stage(paths: [String], at url: URL) async throws(GitError) {
        guard paths.isEmpty == false else {
            return
        }

        _ = try await runChecked(["add", "--"] + paths, at: url)
    }

    func commit(message: String, at url: URL) async throws(GitError) {
        let staged = try await run(["diff", "--cached", "--name-only"], at: url)

        guard staged.trimmedOutput.isEmpty == false else {
            throw .nothingToCommit
        }

        _ = try await runChecked(["commit", "--message", message], at: url)
    }

    func push(branch: String, remote: String, setUpstream: Bool, at url: URL) async throws(GitError) {
        var arguments = ["push"]

        if setUpstream {
            arguments.append("--set-upstream")
        }

        arguments.append(contentsOf: [remote, branch])
        _ = try await runChecked(arguments, at: url)
    }

    func fetch(remote: String, at url: URL) async throws(GitError) {
        _ = try await runChecked(["fetch", "--prune", remote], at: url)
    }

    func fastForward(at url: URL) async throws(GitError) {
        _ = try await runChecked(["merge", "--ff-only", "@{upstream}"], at: url)
    }

    func clone(remoteURL: String, into destination: URL) async throws(GitError) {
        _ = try await runChecked(
            ["clone", remoteURL, destination.path(percentEncoded: false)],
            at: nil
        )
    }

    func checkout(branch: String, at url: URL) async throws(GitError) {
        _ = try await runChecked(["checkout", branch], at: url)
    }

    func createBranch(_ branch: String, at url: URL) async throws(GitError) {
        _ = try await runChecked(["checkout", "-b", branch], at: url)
    }

    func localTags(at url: URL) async throws(GitError) -> [String] {
        let result = try await runChecked(["tag", "--list"], at: url)

        return result.outputLines.map { $0.trimmingCharacters(in: .whitespaces) }
    }

    func remoteTags(remote: String, at url: URL) async throws(GitError) -> Set<String> {
        let result = try await runChecked(["ls-remote", "--tags", remote], at: url)

        return GitRemoteTagParser.tagNames(fromLsRemote: result.standardOutput)
    }

    func remoteURL(at url: URL) async throws(GitError) -> String? {
        let remotes = try await run(["remote"], at: url).outputLines

        guard let remoteName = remotes.contains("origin") ? "origin" : remotes.first else {
            return nil
        }

        let result = try await run(["config", "--get", "remote.\(remoteName).url"], at: url)

        return result.trimmedOutput.isEmpty ? nil : result.trimmedOutput
    }

    func headCommit(at url: URL) async throws(GitError) -> String? {
        let result = try await run(["rev-parse", "HEAD"], at: url)

        guard result.succeeded, result.trimmedOutput.isEmpty == false else {
            return nil
        }

        return result.trimmedOutput
    }

    func branchExists(_ branch: String, at url: URL) async -> Bool {
        let result = try? await run(["rev-parse", "--verify", "--quiet", branch], at: url)

        return result?.succeeded == true
    }

    func containsCommit(_ commit: String, at url: URL) async -> Bool {
        let result = try? await run(["cat-file", "-e", "\(commit)^{commit}"], at: url)

        return result?.succeeded == true
    }

    // MARK: - Helpers

    private func aheadBehindCounts(upstreamBranch: String?, at url: URL) async -> (ahead: Int, behind: Int) {
        guard upstreamBranch != nil else {
            return (0, 0)
        }

        let counts = try? await runChecked(["rev-list", "--left-right", "--count", "@{upstream}...HEAD"], at: url)
        let parsed = GitAheadBehindParser.parse(revListOutput: counts?.standardOutput ?? "")

        return (parsed.ahead, parsed.behind)
    }

    private func run(_ arguments: [String], at url: URL?) async throws(GitError) -> CommandResult {
        let request = CommandRequest(
            executablePath: gitPath,
            arguments: arguments,
            workingDirectory: url,
            extraEnvironment: Self.nonInteractiveEnvironment
        )

        do {
            return try await commandRunner.run(request)
        } catch {
            switch error {
            case .executableMissing:
                throw .gitUnavailable
            case .cancelled:
                throw .cancelled
            case let .launchFailed(message):
                throw .commandFailed(message)
            case .outputUnreadable:
                throw .commandFailed("Unable to read command output")
            }
        }
    }

    private func runChecked(_ arguments: [String], at url: URL?) async throws(GitError) -> CommandResult {
        let result = try await run(arguments, at: url)

        guard result.succeeded else {
            throw GitFailureClassifier.error(for: result.failureMessage)
        }

        return result
    }
}
