import Foundation
@testable import homerun_app

actor StubGitClient: GitClienting {
    // MARK: - Configuration

    var available = true
    var repositoryPaths: Set<String> = []
    var snapshots: [String: GitRepositorySnapshot] = [:]
    var snapshotError: GitError?
    var worktreeLists: [String: [GitWorktree]] = [:]
    var commits: [GitCommitSummary] = []
    var diff = ""
    var stageError: GitError?
    var commitError: GitError?
    var pushFailures: [GitError] = []
    var pushFailuresByBranch: [String: GitError] = [:]
    var fetchError: GitError?
    var fastForwardError: GitError?
    var cloneError: GitError?
    var checkoutError: GitError?
    var createBranchError: GitError?
    var localTagNames: [String] = []
    var remoteTagNames: Set<String> = []
    var head: String? = "head0001"
    var existingBranches: Set<String> = []
    var knownCommits: Set<String> = []

    // MARK: - Snapshot gate

    private var isHoldingSnapshots = false
    private var heldSnapshots: [CheckedContinuation<Void, Never>] = []
    private var awaitingRequest: CheckedContinuation<Void, Never>?
    private var hasRequestedSnapshot = false

    func holdSnapshots() {
        isHoldingSnapshots = true
    }

    func releaseSnapshots() {
        isHoldingSnapshots = false
        heldSnapshots.forEach { $0.resume() }
        heldSnapshots = []
    }

    func waitUntilSnapshotRequested() async {
        guard hasRequestedSnapshot == false else {
            return
        }

        await withCheckedContinuation { continuation in
            awaitingRequest = continuation
        }
    }

    // MARK: - Recording

    private(set) var calls: [String] = []
    private(set) var stagedPaths: [[String]] = []
    private(set) var commitMessages: [String] = []
    private(set) var pushes: [(branch: String, remote: String, setUpstream: Bool)] = []
    private(set) var clones: [(remoteURL: String, destination: URL)] = []
    private(set) var checkouts: [String] = []
    private(set) var createdBranches: [String] = []

    // MARK: - Configuration helpers

    func setSnapshot(_ snapshot: GitRepositorySnapshot, at url: URL) {
        snapshots[url.path(percentEncoded: false)] = snapshot
        repositoryPaths.insert(url.path(percentEncoded: false))
    }

    func setSnapshotError(_ error: GitError?) {
        snapshotError = error
    }

    func setPushFailures(_ failures: [GitError]) {
        pushFailures = failures
    }

    func setPushFailure(_ error: GitError, forBranch branch: String) {
        pushFailuresByBranch[branch] = error
    }

    func setCommitError(_ error: GitError?) {
        commitError = error
    }

    func setCreateBranchError(_ error: GitError?) {
        createBranchError = error
    }

    func setFastForwardError(_ error: GitError?) {
        fastForwardError = error
    }

    func setHead(_ head: String?) {
        self.head = head
    }

    func setLocalTags(_ tags: [String]) {
        localTagNames = tags
    }

    func setRemoteTags(_ tags: Set<String>) {
        remoteTagNames = tags
    }

    func setExistingBranches(_ branches: Set<String>) {
        existingBranches = branches
    }

    func setKnownCommits(_ commits: Set<String>) {
        knownCommits = commits
    }

    func setWorktrees(_ worktrees: [GitWorktree], at url: URL) {
        worktreeLists[url.path(percentEncoded: false)] = worktrees
    }

    func setAvailable(_ available: Bool) {
        self.available = available
    }

    func setRecentCommits(_ commits: [GitCommitSummary]) {
        self.commits = commits
    }

    // MARK: - GitClienting

    func isAvailable() async -> Bool {
        available
    }

    func isRepository(at url: URL) async -> Bool {
        repositoryPaths.contains(url.path(percentEncoded: false))
    }

    func snapshot(at url: URL) async throws(GitError) -> GitRepositorySnapshot {
        calls.append("snapshot")
        hasRequestedSnapshot = true
        awaitingRequest?.resume()
        awaitingRequest = nil

        if isHoldingSnapshots {
            await withCheckedContinuation { continuation in
                heldSnapshots.append(continuation)
            }
        }

        if let snapshotError {
            throw snapshotError
        }

        guard let snapshot = snapshots[url.path(percentEncoded: false)] else {
            throw .notARepository(url.path(percentEncoded: false))
        }

        return snapshot
    }

    func worktrees(at url: URL) async throws(GitError) -> [GitWorktree] {
        worktreeLists[url.path(percentEncoded: false)] ?? []
    }

    func recentCommits(at url: URL, limit: Int) async throws(GitError) -> [GitCommitSummary] {
        Array(commits.prefix(limit))
    }

    func diffSummary(at url: URL) async throws(GitError) -> String {
        diff
    }

    func stageTrackedChanges(at url: URL) async throws(GitError) {
        calls.append("stageTracked")

        if let stageError {
            throw stageError
        }
    }

    func stage(paths: [String], at url: URL) async throws(GitError) {
        stagedPaths.append(paths)

        if let stageError {
            throw stageError
        }
    }

    func commit(message: String, at url: URL) async throws(GitError) {
        calls.append("commit")
        commitMessages.append(message)

        if let commitError {
            throw commitError
        }
    }

    func push(branch: String, remote: String, setUpstream: Bool, at url: URL) async throws(GitError) {
        calls.append("push")
        pushes.append((branch, remote, setUpstream))

        if let failure = pushFailuresByBranch[branch] {
            throw failure
        }

        guard pushFailures.isEmpty == false else {
            return
        }

        throw pushFailures.removeFirst()
    }

    func fetch(remote: String, at url: URL) async throws(GitError) {
        calls.append("fetch")

        if let fetchError {
            throw fetchError
        }
    }

    func fastForward(at url: URL) async throws(GitError) {
        calls.append("fastForward")

        if let fastForwardError {
            throw fastForwardError
        }
    }

    func clone(remoteURL: String, into destination: URL) async throws(GitError) {
        calls.append("clone")
        clones.append((remoteURL, destination))

        if let cloneError {
            throw cloneError
        }
    }

    func checkout(branch: String, at url: URL) async throws(GitError) {
        calls.append("checkout")
        checkouts.append(branch)

        if let checkoutError {
            throw checkoutError
        }
    }

    func createBranch(_ branch: String, at url: URL) async throws(GitError) {
        calls.append("createBranch")
        createdBranches.append(branch)

        if let createBranchError {
            throw createBranchError
        }
    }

    func localTags(at url: URL) async throws(GitError) -> [String] {
        localTagNames
    }

    func remoteTags(remote: String, at url: URL) async throws(GitError) -> Set<String> {
        remoteTagNames
    }

    func remoteURL(at url: URL) async throws(GitError) -> String? {
        snapshots[url.path(percentEncoded: false)]?.remoteURL
    }

    func headCommit(at url: URL) async throws(GitError) -> String? {
        head
    }

    func branchExists(_ branch: String, at url: URL) async -> Bool {
        existingBranches.contains(branch)
    }

    func containsCommit(_ commit: String, at url: URL) async -> Bool {
        knownCommits.contains(commit)
    }
}
