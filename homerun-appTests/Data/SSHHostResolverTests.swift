import Foundation
import Testing
@testable import homerun_app

@Suite("SSH host resolution", .tags(.data))
struct SSHHostResolverTests {
    @Test("reads the hostname from ssh -G output")
    func readsHostName() {
        let output = "user git\nhostname github.com\nport 22\nidentityfile ~/.ssh/work\n"

        #expect(SSHResolvedConfigParser.hostName(from: output) == "github.com")
    }

    @Test("finds no hostname in empty output")
    func findsNothingInEmptyOutput() {
        #expect(SSHResolvedConfigParser.hostName(from: "") == nil)
    }

    @Test("asks ssh for the resolved configuration of the alias")
    func runsSSHDashG() async {
        let runner = StubCommandRunner()
        await runner.stub(["-G", "--", "github-work"], output: "hostname github.com\n")
        let resolver = ProcessSSHHostResolver(commandRunner: runner, sshPath: "/usr/bin/ssh")

        #expect(await resolver.hostName(forAlias: "github-work") == "github.com")
    }

    @Test("resolves nothing when ssh fails")
    func resolvesNothingOnFailure() async {
        let runner = StubCommandRunner()
        await runner.stub(["-G"], exitCode: 255, error: "bad configuration")
        let resolver = ProcessSSHHostResolver(commandRunner: runner, sshPath: "/usr/bin/ssh")

        #expect(await resolver.hostName(forAlias: "github-work") == nil)
    }

    @Test("never passes an alias that could be read as an option")
    func rejectsOptionLikeAlias() async {
        let runner = StubCommandRunner()
        let resolver = ProcessSSHHostResolver(commandRunner: runner, sshPath: "/usr/bin/ssh")

        #expect(await resolver.hostName(forAlias: "-oProxyCommand=evil") == nil)
        #expect(await runner.requests.isEmpty)
    }
}
