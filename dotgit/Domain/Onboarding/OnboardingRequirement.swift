import Foundation

enum OnboardingRequirement: Equatable, Identifiable, CaseIterable {
    case gitMissing
    case gitHubCLIMissing
    case gitHubCLINotAuthenticated

    var id: String {
        title
    }

    var isBlocking: Bool {
        switch self {
        case .gitMissing:
            true
        case .gitHubCLIMissing,
             .gitHubCLINotAuthenticated:
            false
        }
    }

    var title: String {
        switch self {
        case .gitMissing:
            String(localized: "Git is not available")
        case .gitHubCLIMissing:
            String(localized: "The GitHub CLI is not installed")
        case .gitHubCLINotAuthenticated:
            String(localized: "No GitHub account is signed in")
        }
    }

    var explanation: String {
        switch self {
        case .gitMissing:
            String(
                localized: "dotgit needs the git command line tool. Install the Xcode command line tools, then check again."
            )
        case .gitHubCLIMissing:
            String(
                localized: """
                gh is optional. Without it, dotgit still syncs with your existing git authentication, \
                but cannot manage GitHub accounts or retry a push with another one.
                """
            )
        case .gitHubCLINotAuthenticated:
            String(
                localized: "gh is installed but signed out. Sign in to manage GitHub accounts and retry failed pushes with another account."
            )
        }
    }
}
