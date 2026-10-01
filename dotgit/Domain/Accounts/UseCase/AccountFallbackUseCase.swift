import Foundation

enum AccountFallbackUseCase {
    static func appliesToRemote(_ remoteURL: String?) -> Bool {
        guard let remoteURL = remoteURL?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() else {
            return false
        }

        return remoteURL.hasPrefix("https://") || remoteURL.hasPrefix("http://")
    }

    static func inapplicableExplanation(for remoteURL: String?) -> String {
        guard remoteURL != nil else {
            return String(localized: "This repository has no push destination, so there is no account to switch.")
        }

        return String(
            localized: """
            This repository pushes over SSH, so git uses your SSH key rather than a GitHub CLI \
            account. Switching accounts would not change the result.
            """
        )
    }

    static func candidates(from accounts: [GitHubAccount], preferred: String?, excluding failed: String?) -> [String] {
        let logins = accounts.map(\.login).filter { $0 != failed }

        guard let preferred, logins.contains(preferred) else {
            return logins
        }

        return [preferred] + logins.filter { $0 != preferred }
    }

    static func accountToRestore(from accounts: [GitHubAccount]) -> String? {
        accounts.first { $0.isActive }?.login
    }
}
