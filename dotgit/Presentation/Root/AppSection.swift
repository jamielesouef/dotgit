import Foundation

enum AppSection: String, Equatable, CaseIterable, Identifiable {
    case today
    case repositories
    case gitHubAccounts
    case cleaner
    case settings

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .today:
            String(localized: "Today")
        case .repositories:
            String(localized: "Repositories")
        case .gitHubAccounts:
            String(localized: "GitHub Accounts")
        case .cleaner:
            String(localized: "Cleaner")
        case .settings:
            String(localized: "Settings")
        }
    }

    var symbolName: String {
        switch self {
        case .today:
            "sun.horizon"
        case .repositories:
            "folder"
        case .gitHubAccounts:
            "person.2"
        case .cleaner:
            "trash"
        case .settings:
            "gearshape"
        }
    }
}
