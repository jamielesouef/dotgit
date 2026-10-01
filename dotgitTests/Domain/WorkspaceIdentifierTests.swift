import Testing
@testable import dotgit

@Suite("WorkspaceIdentifier", .tags(.domain))
struct WorkspaceIdentifierTests {
    @Test("gives the same identifier to the same remote written different ways", arguments: [
        "git@github.com:Acme/App.git",
        "https://github.com/acme/app.git",
        "https://github.com/acme/app/",
        "ssh://github.com/acme/app",
        "ssh://git@github.com/acme/app.git",
        "github.com:acme/app.git"
    ])
    func matchesEquivalentRemotes(remote: String) {
        #expect(WorkspaceIdentifier.make(remoteURL: remote, folderName: "app") == "remote:github.com/acme/app")
    }

    @Test("falls back to the folder name when a repository has no remote")
    func fallsBackToFolderName() {
        #expect(WorkspaceIdentifier.make(remoteURL: nil, folderName: "Scratch") == "local:scratch")
        #expect(WorkspaceIdentifier.make(remoteURL: "  ", folderName: "Scratch") == "local:scratch")
    }

    @Test("separates two different remotes")
    func separatesDifferentRemotes() {
        let first = WorkspaceIdentifier.make(remoteURL: "git@github.com:acme/app.git", folderName: "app")
        let second = WorkspaceIdentifier.make(remoteURL: "git@github.com:acme/other.git", folderName: "app")

        #expect(first != second)
    }

    // MARK: - SSH host aliases

    @Test("reads the host an SSH remote names", arguments: [
        ("git@github-work:acme/app.git", "github-work"),
        ("github-work:acme/app.git", "github-work"),
        ("ssh://git@github-work:2222/acme/app.git", "github-work"),
        ("ssh://github-work/acme/app", "github-work")
    ])
    func readsSSHHost(remote: String, host: String) {
        #expect(WorkspaceIdentifier.sshHost(in: remote) == host)
    }

    @Test("finds no SSH host in HTTPS or local remotes", arguments: [
        "https://github.com/acme/app.git",
        "/Volumes/Backup/app.git",
        "./relative/app"
    ])
    func findsNoSSHHost(remote: String) {
        #expect(WorkspaceIdentifier.sshHost(in: remote) == nil)
    }

    @Test("gives an aliased remote the same identifier as the host it resolves to", arguments: [
        "git@github-work:acme/app.git",
        "github-work:acme/app.git",
        "ssh://git@github-work/acme/app.git"
    ])
    func resolvesAlias(remote: String) {
        let resolved = WorkspaceIdentifier.remote(remote, resolvingSSHHostTo: "github.com")

        #expect(WorkspaceIdentifier.make(remoteURL: resolved, folderName: "app") == "remote:github.com/acme/app")
    }

    @Test("leaves the remote alone when the alias could not be resolved")
    func keepsUnresolvedRemote() {
        #expect(WorkspaceIdentifier.remote("git@github-work:acme/app.git", resolvingSSHHostTo: nil)
            == "git@github-work:acme/app.git")
    }
}
