import Foundation

enum AppCapability: String, Equatable, CaseIterable, Hashable {
    case gitSync
    case gitHubAccountManagement
    case gitHubAccountFallback

    var title: String {
        switch self {
        case .gitSync:
            String(localized: "Sync with git")
        case .gitHubAccountManagement:
            String(localized: "Manage GitHub accounts")
        case .gitHubAccountFallback:
            String(localized: "Retry a push with another account")
        }
    }
}
