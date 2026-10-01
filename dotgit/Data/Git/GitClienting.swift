import Foundation

protocol GitClienting: Sendable {
    func isAvailable() async -> Bool
    func isRepository(at url: URL) async -> Bool
    func snapshot(at url: URL) async throws(GitError) -> GitRepositorySnapshot
    func worktrees(at url: URL) async throws(GitError) -> [GitWorktree]
    func recentCommits(at url: URL, limit: Int) async throws(GitError) -> [GitCommitSummary]
    func diffSummary(at url: URL) async throws(GitError) -> String
    func stageTrackedChanges(at url: URL) async throws(GitError)
    func stage(paths: [String], at url: URL) async throws(GitError)
    func commit(message: String, at url: URL) async throws(GitError)
    func push(branch: String, remote: String, setUpstream: Bool, at url: URL) async throws(GitError)
    func fetch(remote: String, at url: URL) async throws(GitError)
    func fastForward(at url: URL) async throws(GitError)
    func clone(remoteURL: String, into destination: URL) async throws(GitError)
    func checkout(branch: String, at url: URL) async throws(GitError)
    func createBranch(_ branch: String, at url: URL) async throws(GitError)
    func localTags(at url: URL) async throws(GitError) -> [String]
    func remoteTags(remote: String, at url: URL) async throws(GitError) -> Set<String>
    func remoteURL(at url: URL) async throws(GitError) -> String?
    func headCommit(at url: URL) async throws(GitError) -> String?
    func branchExists(_ branch: String, at url: URL) async -> Bool
    func containsCommit(_ commit: String, at url: URL) async -> Bool
}
