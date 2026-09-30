import Foundation

struct ProcessSSHHostResolver: SSHHostResolving {
    // MARK: - Private

    private let commandRunner: any CommandRunning
    private let sshPath: String

    // MARK: - Init

    init(commandRunner: any CommandRunning, sshPath: String) {
        self.commandRunner = commandRunner
        self.sshPath = sshPath
    }

    // MARK: - SSHHostResolving

    /// `ssh -G` prints the configuration that applies to a host without connecting,
    /// so this honours `Include`, `Match` and wildcards the way git's own ssh will.
    func hostName(forAlias alias: String) async -> String? {
        guard alias.hasPrefix("-") == false else {
            return nil
        }

        let request = CommandRequest(executablePath: sshPath, arguments: ["-G", "--", alias])

        guard let result = try? await commandRunner.run(request), result.succeeded else {
            return nil
        }

        return SSHResolvedConfigParser.hostName(from: result.standardOutput)
    }
}
