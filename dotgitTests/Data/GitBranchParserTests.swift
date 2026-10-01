import Testing
@testable import dotgit

@Suite("GitBranchParser", .tags(.data))
struct GitBranchParserTests {
    @Test("marks a branch with no upstream as local only")
    func marksLocalOnly() {
        let branches = GitBranchParser.parse(forEachRef: "spike\u{1F}\u{1F}\n")

        #expect(branches.first?.isLocalOnly == true)
        #expect(branches.first?.hasUnpushedCommits == false)
    }

    @Test("reads ahead and behind counts out of the track field")
    func readsCounts() {
        let branches = GitBranchParser.parse(forEachRef: "main\u{1F}origin/main\u{1F}[ahead 2, behind 3]\n")

        #expect(branches.first?.aheadCount == 2)
        #expect(branches.first?.behindCount == 3)
        #expect(branches.first?.upstream == "origin/main")
    }

    @Test("treats a tracked branch with no divergence as fully pushed")
    func readsInSync() {
        let branches = GitBranchParser.parse(forEachRef: "main\u{1F}origin/main\u{1F}\n")

        #expect(branches.first?.hasUnpushedCommits == false)
        #expect(branches.first?.isLocalOnly == false)
    }

    @Test("skips malformed lines instead of inventing a branch")
    func skipsMalformed() {
        #expect(GitBranchParser.parse(forEachRef: "garbage\n\n").isEmpty)
    }
}
