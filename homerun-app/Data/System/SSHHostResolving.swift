import Foundation

protocol SSHHostResolving: Sendable {
    /// The real hostname `~/.ssh/config` maps `alias` to, or `nil` if it cannot tell.
    func hostName(forAlias alias: String) async -> String?
}
