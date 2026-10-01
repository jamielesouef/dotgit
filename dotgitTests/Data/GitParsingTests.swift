import Foundation
import Testing
@testable import dotgit

@Suite("GitSubmoduleParser", .tags(.data))
struct GitSubmoduleParserTests {
    @Test("maps the status marker to the kind of attention the submodule needs", arguments: [
        ("+abc1234 Vendor/Lib (v1.0)", GitSubmoduleChange.Kind.commitDiffers),
        ("-abc1234 Vendor/Lib", GitSubmoduleChange.Kind.uninitialised),
        ("Uabc1234 Vendor/Lib", GitSubmoduleChange.Kind.mergeConflict)
    ])
    func mapsMarker(line: String, expected: GitSubmoduleChange.Kind) {
        #expect(GitSubmoduleParser.parse(statusOutput: line) == [GitSubmoduleChange(
            path: "Vendor/Lib",
            kind: expected
        )])
    }

    @Test("ignores submodules that match their recorded commit")
    func ignoresClean() {
        #expect(GitSubmoduleParser.parse(statusOutput: " abc1234 Vendor/Lib (v1.0)").isEmpty)
    }
}

@Suite("GitAheadBehindParser", .tags(.data))
struct GitAheadBehindParserTests {
    @Test("reads behind from the left column and ahead from the right")
    func readsColumns() {
        let counts = GitAheadBehindParser.parse(revListOutput: "3\t5\n")

        #expect(counts.behind == 3)
        #expect(counts.ahead == 5)
    }

    @Test("returns no divergence for unusable output")
    func handlesEmpty() {
        let counts = GitAheadBehindParser.parse(revListOutput: "")

        #expect(counts == (0, 0))
    }
}

@Suite("GitRemoteTagParser", .tags(.data))
struct GitRemoteTagParserTests {
    @Test("collapses a peeled tag onto its own name")
    func collapsesPeeled() {
        let output = "abc\trefs/tags/v1.0\ndef\trefs/tags/v1.0^{}\n123\trefs/heads/main\n"

        #expect(GitRemoteTagParser.tagNames(fromLsRemote: output) == ["v1.0"])
    }

    @Test("reports local tags the remote has never seen")
    func reportsUnpushed() {
        let unpushed = GitRemoteTagParser.unpushedTags(local: ["v1.0", "v2.0"], remote: ["v1.0"])

        #expect(unpushed == ["v2.0"])
    }
}

@Suite("GitLogParser", .tags(.data))
struct GitLogParserTests {
    @Test("reads the commit fields the activity list shows")
    func readsFields() {
        let line = "abcdef1234567890\u{1F}Fix the thing\u{1F}Jamie\u{1F}2026-09-23T10:00:00Z"
        let commits = GitLogParser.parse(logOutput: line)

        #expect(commits.first?.shortHash == "abcdef1")
        #expect(commits.first?.subject == "Fix the thing")
        #expect(commits.first?.authorName == "Jamie")
        #expect(commits.first?.date != Date.distantPast)
    }

    @Test("skips a line that is missing fields")
    func skipsShortLine() {
        #expect(GitLogParser.parse(logOutput: "abc\u{1F}subject").isEmpty)
    }
}

@Suite("GitFailureClassifier", .tags(.data))
struct GitFailureClassifierTests {
    @Test("recognises the authentication failures worth retrying with another account", arguments: [
        "remote: Authentication failed for 'https://github.com/acme/app.git'",
        "fatal: could not read Username for 'https://github.com'",
        "git@github.com: Permission denied (publickey).",
        "remote: Repository not found."
    ])
    func recognisesAuthFailure(message: String) {
        #expect(GitFailureClassifier.isAuthenticationFailure(message))
        #expect(GitFailureClassifier.error(for: message) == .authenticationFailed(message))
    }

    @Test("recognises a rejected push as divergence rather than an auth problem")
    func recognisesDivergence() {
        let message = "! [rejected] main -> main (non-fast-forward)"

        #expect(GitFailureClassifier.isAuthenticationFailure(message) == false)
        #expect(GitFailureClassifier.error(for: message) == .diverged)
    }

    @Test("recognises a remote refusing the branch itself", arguments: [
        "remote: error: GH006: Protected branch update failed for refs/heads/main.",
        "remote: error: GH013: Repository rule violations found for refs/heads/main.",
        "! [remote rejected] main -> main (protected branch hook declined)",
        "remote: GitLab: You are not allowed to push code to protected branches on this project.",
        "! [remote rejected] main -> main (pre-receive hook declined)\nerror: failed to push some refs"
    ])
    func recognisesProtectedBranch(message: String) {
        #expect(GitFailureClassifier.isProtectedBranchFailure(message))
        #expect(GitFailureClassifier.error(for: message) == .branchProtected(message))
    }

    @Test("falls back to the raw command failure for anything else")
    func fallsBack() {
        #expect(GitFailureClassifier.error(for: "fatal: bad object") == .commandFailed("fatal: bad object"))
    }
}
