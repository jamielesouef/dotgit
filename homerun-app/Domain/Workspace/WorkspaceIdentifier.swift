import Foundation

enum WorkspaceIdentifier {
    // MARK: - Identifier

    static func make(remoteURL: String?, folderName: String) -> String {
        guard let normalised = normalisedRemote(remoteURL) else {
            return "local:\(folderName.lowercased())"
        }

        return "remote:\(normalised)"
    }

    static func normalisedRemote(_ remoteURL: String?) -> String? {
        guard var value = remoteURL?.trimmingCharacters(in: .whitespacesAndNewlines), value.isEmpty == false else {
            return nil
        }

        value = value.lowercased()

        if value.hasSuffix(".git") {
            value.removeLast(4)
        }

        if value.hasSuffix("/") {
            value.removeLast()
        }

        if let parts = sshParts(of: value) {
            let isSCPStyle = value.hasPrefix("ssh://") == false
            let path = isSCPStyle ? "/" + parts.suffix.dropFirst() : String(parts.suffix)

            return String(parts.host) + path
        }

        for prefix in ["https://", "http://", "git://"] where value.hasPrefix(prefix) {
            value.removeFirst(prefix.count)
        }

        return value
    }

    // MARK: - SSH host aliases

    /// The host an SSH remote names, which may be an alias from `~/.ssh/config`
    /// rather than a real hostname. `nil` for HTTPS and local remotes.
    static func sshHost(in remoteURL: String?) -> String? {
        guard let remoteURL, let parts = sshParts(of: remoteURL) else {
            return nil
        }

        return String(parts.host)
    }

    /// The same remote with its SSH host swapped for the one it resolves to, so
    /// `git@github-work:acme/app` and `https://github.com/acme/app` share an identifier.
    static func remote(_ remoteURL: String?, resolvingSSHHostTo hostName: String?) -> String? {
        guard let remoteURL, let hostName, hostName.isEmpty == false, let parts = sshParts(of: remoteURL) else {
            return remoteURL
        }

        return parts.prefix + hostName + parts.suffix
    }

    // MARK: - Helpers

    /// Splits `ssh://[user@]host[:port]/path` or scp-style `[user@]host:path` around the host.
    private static func sshParts(of remoteURL: String) -> (prefix: Substring, host: Substring, suffix: Substring)? {
        let value = Substring(remoteURL.trimmingCharacters(in: .whitespacesAndNewlines))
        let hostStart: Substring.Index
        let hostEnd: Substring.Index

        if value.lowercased().hasPrefix("ssh://") {
            let authorityStart = value.index(value.startIndex, offsetBy: "ssh://".count)
            let authorityEnd = value[authorityStart...].firstIndex(of: "/") ?? value.endIndex
            hostStart = value[authorityStart ..< authorityEnd].lastIndex(of: "@").map { value.index(after: $0) }
                ?? authorityStart
            hostEnd = value[hostStart ..< authorityEnd].firstIndex(of: ":") ?? authorityEnd
        } else {
            guard value.contains("://") == false,
                  let colon = value.firstIndex(of: ":"),
                  value[..<colon].contains("/") == false
            else {
                return nil
            }

            hostStart = value[..<colon].lastIndex(of: "@").map { value.index(after: $0) } ?? value.startIndex
            hostEnd = colon
        }

        guard hostStart < hostEnd else {
            return nil
        }

        return (value[..<hostStart], value[hostStart ..< hostEnd], value[hostEnd...])
    }
}
