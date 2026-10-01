import Testing
@testable import dotgit

@Suite("GitHubAuthStatusParser", .tags(.data))
struct GitHubAuthStatusParserTests {
    private let output = """
    github.com
      ✓ Logged in to github.com account jamie (keyring)
      - Active account: true
      - Git operations protocol: https
      ✓ Logged in to github.com account acme-bot (keyring)
      - Active account: false
    """

    @Test("lists every signed-in account")
    func listsAccounts() {
        #expect(GitHubAuthStatusParser.parse(output).map(\.login) == ["jamie", "acme-bot"])
    }

    @Test("marks the active account")
    func marksActiveAccount() {
        let accounts = GitHubAuthStatusParser.parse(output)

        #expect(accounts.first?.isActive == true)
        #expect(accounts.last?.isActive == false)
    }

    @Test("reads the host each account belongs to")
    func readsHost() {
        #expect(GitHubAuthStatusParser.parse(output).allSatisfy { $0.host == "github.com" })
    }

    @Test("returns nothing when no account is signed in")
    func returnsNothingWhenSignedOut() {
        #expect(GitHubAuthStatusParser.parse("You are not logged into any GitHub hosts.").isEmpty)
    }
}

@Suite("GitHubRemoteParser", .tags(.data))
struct GitHubRemoteParserTests {
    @Test("reads the owner and repository out of a remote", arguments: [
        "git@github.com:Acme/App.git",
        "https://github.com/acme/app.git"
    ])
    func readsSlug(remote: String) {
        #expect(GitHubRemoteParser.repositorySlug(fromRemoteURL: remote) == "acme/app")
    }

    @Test("returns nothing for a remote that is not on GitHub")
    func ignoresOtherHosts() {
        #expect(GitHubRemoteParser.repositorySlug(fromRemoteURL: "git@gitlab.com:acme/app.git") == nil)
        #expect(GitHubRemoteParser.repositorySlug(fromRemoteURL: nil) == nil)
    }
}

@Suite("AccountFallbackUseCase", .tags(.domain))
struct AccountFallbackUseCaseTests {
    @Test("applies to an https remote that git authenticates through the GitHub CLI")
    func appliesToHTTPS() {
        #expect(AccountFallbackUseCase.appliesToRemote("https://github.com/acme/app.git"))
    }

    @Test(
        "does not apply to an SSH remote",
        arguments: ["git@github.com:acme/app.git", "ssh://git@github.com/acme/app.git"]
    )
    func doesNotApplyToSSH(remote: String) {
        #expect(AccountFallbackUseCase.appliesToRemote(remote) == false)
        #expect(AccountFallbackUseCase.inapplicableExplanation(for: remote).contains("SSH"))
    }

    @Test("explains a repository with no push destination separately")
    func explainsMissingRemote() {
        #expect(AccountFallbackUseCase.inapplicableExplanation(for: nil).contains("no push destination"))
    }

    @Test("tries the preferred account first and never retries the one that just failed")
    func ordersCandidates() {
        let accounts = [
            GitHubAccount(login: "jamie", host: "github.com", isActive: true),
            GitHubAccount(login: "acme-bot", host: "github.com", isActive: false),
            GitHubAccount(login: "work", host: "github.com", isActive: false)
        ]

        let candidates = AccountFallbackUseCase.candidates(from: accounts, preferred: "work", excluding: "jamie")

        #expect(candidates == ["work", "acme-bot"])
    }

    @Test("names the account that must be put back afterwards")
    func namesAccountToRestore() {
        let accounts = [
            GitHubAccount(login: "jamie", host: "github.com", isActive: true),
            GitHubAccount(login: "acme-bot", host: "github.com", isActive: false)
        ]

        #expect(AccountFallbackUseCase.accountToRestore(from: accounts) == "jamie")
    }
}
