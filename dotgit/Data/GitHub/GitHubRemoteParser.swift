import Foundation

enum GitHubRemoteParser {
    static func repositorySlug(fromRemoteURL remoteURL: String?) -> String? {
        guard let normalised = WorkspaceIdentifier.normalisedRemote(remoteURL) else {
            return nil
        }

        let components = normalised.split(separator: "/", omittingEmptySubsequences: true).map { String($0) }

        guard components.count >= 3, components[0].contains("github") else {
            return nil
        }

        return "\(components[1])/\(components[2])"
    }
}
