import Foundation

protocol SSHHostResolving: Sendable {
    /// The real hostname `~/.ssh/config` maps `alias` to, or `nil` if it cannot tell.
    func hostName(forAlias alias: String) async -> String?
}

// MARK: - Identifiers

extension SSHHostResolving {
    /// Keyed on the host an SSH alias resolves to, so switching a remote between
    /// `github-work`, `github.com` and HTTPS does not track the same repository twice.
    func identifier(remoteURL: String?, folderName: String) async -> String {
        guard let alias = WorkspaceIdentifier.sshHost(in: remoteURL) else {
            return WorkspaceIdentifier.make(remoteURL: remoteURL, folderName: folderName)
        }

        let resolved = await WorkspaceIdentifier.remote(remoteURL, resolvingSSHHostTo: hostName(forAlias: alias))

        return WorkspaceIdentifier.make(remoteURL: resolved, folderName: folderName)
    }
}
