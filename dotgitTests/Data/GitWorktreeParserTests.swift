import Foundation
import Testing
@testable import dotgit

@Suite("GitWorktreeParser", .tags(.data))
struct GitWorktreeParserTests {
    // MARK: - Worktree list

    @Test("reads the main checkout first and each linked worktree after it")
    func readsMainAndLinked() {
        let output = """
        worktree /Users/jamie/Developer/app
        HEAD abc1234
        branch refs/heads/main

        worktree /Users/jamie/Developer/app/.claude/worktrees/feature+login
        HEAD def5678
        branch refs/heads/feature/login

        """

        let worktrees = GitWorktreeParser.parse(porcelain: output)

        #expect(worktrees.map(\.name) == ["app", "feature+login"])
        #expect(worktrees.map(\.isMain) == [true, false])
        #expect(worktrees.map(\.branch) == ["main", "feature/login"])
        #expect(worktrees.last?.headCommit == "def5678")
    }

    @Test("reads a detached, locked and prunable worktree without inventing a branch")
    func readsDetachedLockedPrunable() {
        let output = """
        worktree /repo
        HEAD abc1234
        branch refs/heads/main

        worktree /repo-detached
        HEAD 1111111
        detached
        locked being moved

        worktree /repo-gone
        HEAD 2222222
        branch refs/heads/old
        prunable gitdir file points to non-existent location
        """

        let worktrees = GitWorktreeParser.parse(porcelain: output)

        #expect(worktrees[1].isDetached)
        #expect(worktrees[1].isLocked)
        #expect(worktrees[1].isPrunable == false)
        #expect(worktrees[2].isPrunable)
    }

    @Test("marks a bare main repository")
    func marksBare() {
        let worktrees = GitWorktreeParser
            .parse(porcelain: "worktree /repo.git\nbare\n\nworktree /work\nHEAD abc\nbranch refs/heads/main\n")

        #expect(worktrees.first?.isBare == true)
        #expect(worktrees.last?.isBare == false)
    }

    @Test("reads nothing from empty output")
    func readsNothingFromEmptyOutput() {
        #expect(GitWorktreeParser.parse(porcelain: "").isEmpty)
    }

    // MARK: - Git file

    @Test("recognises the .git file of a linked worktree but not of a submodule")
    func recognisesLinkedWorktreePointer() {
        #expect(GitWorktreeParser.isLinkedWorktreePointer("gitdir: /Users/jamie/Developer/app/.git/worktrees/login\n"))
        #expect(GitWorktreeParser.isLinkedWorktreePointer("gitdir: ../.git/modules/vendor\n") == false)
        #expect(GitWorktreeParser.isLinkedWorktreePointer("") == false)
    }
}
