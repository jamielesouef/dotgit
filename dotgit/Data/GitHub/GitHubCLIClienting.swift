import Foundation

protocol GitHubCLIClienting: Sendable {
    func isAvailable() async -> Bool
    func accounts() async throws(GitHubCLIError) -> [GitHubAccount]
    func switchAccount(to login: String, host: String) async throws(GitHubCLIError)
    func hasAccess(toRemoteURL remoteURL: String) async -> Bool
    func beginInteractiveSignIn() async throws(GitHubCLIError)
}
