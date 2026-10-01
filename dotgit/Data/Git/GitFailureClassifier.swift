import Foundation

enum GitFailureClassifier {
    private static let authenticationMarkers = [
        "authentication failed",
        "could not read username",
        "could not read password",
        "permission denied (publickey)",
        "invalid username or password",
        "remote: invalid username or token",
        "403 forbidden",
        "access denied",
        "terminal prompts disabled",
        "repository not found"
    ]

    private static let divergenceMarkers = [
        "non-fast-forward",
        "fetch first",
        "updates were rejected",
        "tip of your current branch is behind"
    ]

    private static let protectedBranchMarkers = [
        "protected branch",
        "gh006",
        "gh013",
        "repository rule violations",
        "can only be modified through pull requests",
        "pre-receive hook declined"
    ]

    static func isAuthenticationFailure(_ message: String) -> Bool {
        contains(message, markers: authenticationMarkers)
    }

    static func isDivergenceFailure(_ message: String) -> Bool {
        contains(message, markers: divergenceMarkers)
    }

    static func isProtectedBranchFailure(_ message: String) -> Bool {
        contains(message, markers: protectedBranchMarkers)
    }

    static func error(for message: String) -> GitError {
        guard isProtectedBranchFailure(message) == false else {
            return .branchProtected(message)
        }
        guard isAuthenticationFailure(message) == false else {
            return .authenticationFailed(message)
        }
        guard isDivergenceFailure(message) == false else {
            return .diverged
        }

        return .commandFailed(message)
    }

    // MARK: - Helpers

    private static func contains(_ message: String, markers: [String]) -> Bool {
        let lowercased = message.lowercased()

        return markers.contains { lowercased.contains($0) }
    }
}
