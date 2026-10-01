import Foundation

enum GitHubCLIError: Error, Equatable {
    case notInstalled
    case notAuthenticated
    case switchFailed(String)
    case commandFailed(String)
    case cancelled

    var message: String {
        switch self {
        case .notInstalled:
            String(localized: "The GitHub CLI is not installed.")
        case .notAuthenticated:
            String(localized: "No GitHub account is signed in.")
        case let .switchFailed(detail):
            String(localized: "Could not switch account: \(detail)")
        case let .commandFailed(detail):
            detail
        case .cancelled:
            String(localized: "Cancelled.")
        }
    }
}
