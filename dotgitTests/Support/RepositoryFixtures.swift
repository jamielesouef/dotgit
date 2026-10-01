import Foundation
@testable import dotgit

enum RepositoryFixtures {
    static func snapshot(
        branch: String? = "main",
        ahead: Int = 0,
        behind: Int = 0,
        tracked: [GitFileChange] = [],
        untracked: [String] = [],
        branches: [GitBranchRef] = [],
        remote: String? = "origin",
        remoteURL: String = "git@github.com:acme/app.git",
        upstream: String? = "origin/main",
        submodules: [GitSubmoduleChange] = [],
        headCommit: String? = "abc1234"
    ) -> GitRepositorySnapshot {
        GitRepositorySnapshot(
            currentBranch: branch,
            headCommit: headCommit,
            defaultRemoteName: remote,
            remoteURL: remote == nil ? nil : remoteURL,
            upstreamBranch: upstream,
            aheadCount: ahead,
            behindCount: behind,
            workingTree: GitWorkingTreeStatus(trackedChanges: tracked, untrackedPaths: untracked),
            branches: branches,
            submoduleChanges: submodules
        )
    }

    static func shared(
        _ identifier: String = "remote:github.com/acme/app",
        name: String = "app",
        lastSynced: Date? = nil,
        allowsMain: Bool = false,
        allowsMaster: Bool = false,
        prefix: String? = nil,
        account: String? = nil,
        handoff: RepositoryHandoff? = nil
    ) -> WorkspaceRepository {
        WorkspaceRepository(
            identifier: identifier,
            name: name,
            remoteURL: "git@github.com:acme/\(name).git",
            preferredRelativePath: name,
            allowsMainBranchSync: allowsMain,
            allowsMasterBranchSync: allowsMaster,
            wipCommitPrefixOverride: prefix,
            preferredGitHubAccount: account,
            handoff: handoff,
            lastSuccessfulSyncDate: lastSynced
        )
    }

    static func tracked(
        _ identifier: String = "remote:github.com/acme/app",
        name: String = "app",
        path: String? = "/Users/jamie/Developer/app",
        snapshot: GitRepositorySnapshot? = nil,
        outcome: RepositorySyncOutcome? = nil,
        readError: GitError? = nil,
        lastSynced: Date? = nil
    ) -> TrackedRepository {
        TrackedRepository(
            shared: shared(identifier, name: name, lastSynced: lastSynced),
            localPath: path.map { URL(filePath: $0) },
            snapshot: snapshot,
            lastSyncOutcome: outcome,
            readError: readError
        )
    }

    static func gitWorktree(
        _ path: String,
        branch: String? = "feature/login",
        isMain: Bool = false,
        isBare: Bool = false,
        isPrunable: Bool = false
    ) -> GitWorktree {
        GitWorktree(
            path: URL(filePath: path),
            headCommit: "def5678",
            branch: branch,
            isMain: isMain,
            isBare: isBare,
            isLocked: false,
            isPrunable: isPrunable
        )
    }

    static func worktree(
        _ path: String = "/Users/jamie/Developer/app-login",
        of identifier: String = "remote:github.com/acme/app",
        snapshot: GitRepositorySnapshot? = nil
    ) -> TrackedRepository {
        let worktree = gitWorktree(path, branch: snapshot?.currentBranch ?? "feature/login")

        return TrackedRepository(
            shared: shared(identifier),
            localPath: worktree.path,
            snapshot: snapshot,
            worktree: worktree
        )
    }

    static func failure(_ identifier: String = "remote:github.com/acme/app") -> RepositorySyncOutcome {
        RepositorySyncOutcome(identifier: identifier, result: .failed(.diverged), finishedAt: .distantPast)
    }
}
