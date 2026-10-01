import Foundation

enum StartupCheck: CaseIterable, Identifiable {
    case git
    case gitHubCLI
    case gitHubAccounts

    var id: Self {
        self
    }

    var title: String {
        switch self {
        case .git:
            String(localized: "git")
        case .gitHubCLI:
            String(localized: "GitHub CLI")
        case .gitHubAccounts:
            String(localized: "GitHub sign-in")
        }
    }
}
