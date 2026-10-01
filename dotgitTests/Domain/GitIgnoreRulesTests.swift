import Testing
@testable import dotgit

@Suite("GitIgnoreRules", .tags(.domain))
struct GitIgnoreRulesTests {
    @Test("ignores a plain folder name")
    func ignoresFolderName() {
        let rules = GitIgnoreRules.parse("build\n")

        #expect(rules.ignores(name: "build", isDirectory: true))
        #expect(rules.ignores(name: "builder", isDirectory: true) == false)
    }

    @Test("skips comments and blank lines")
    func skipsComments() {
        let rules = GitIgnoreRules.parse("# a comment\n\n   \n")

        #expect(rules.patterns.isEmpty)
    }

    @Test("applies a trailing slash pattern to directories only")
    func appliesDirectoryOnlyPattern() {
        let rules = GitIgnoreRules.parse("Pods/\n")

        #expect(rules.ignores(name: "Pods", isDirectory: true))
        #expect(rules.ignores(name: "Pods", isDirectory: false) == false)
    }

    @Test("matches a wildcard pattern")
    func matchesWildcard() {
        let rules = GitIgnoreRules.parse("*.xcworkspace\n")

        #expect(rules.ignores(name: "App.xcworkspace", isDirectory: true))
        #expect(rules.ignores(name: "App.xcodeproj", isDirectory: true) == false)
    }

    @Test("lets a later negation rescue an earlier ignore")
    func honoursNegation() {
        let rules = GitIgnoreRules.parse("vendor\n!vendor\n")

        #expect(rules.ignores(name: "vendor", isDirectory: true) == false)
    }

    @Test("strips the leading slash from an anchored pattern")
    func stripsAnchor() {
        let rules = GitIgnoreRules.parse("/build\n")

        #expect(rules.ignores(name: "build", isDirectory: true))
    }
}
