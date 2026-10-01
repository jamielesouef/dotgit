import Foundation

enum ConfigurationScope: String, Equatable, CaseIterable, Identifiable {
    case local
    case shared

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .local:
            String(localized: "This Mac only")
        case .shared:
            String(localized: "Every Mac")
        }
    }

    var explanation: String {
        switch self {
        case .local:
            String(
                localized: "Clears the paths and checkout details dotgit keeps for this Mac. The shared workspace and your files are untouched."
            )
        case .shared:
            String(
                localized: "Removes every repository from the shared workspace on all your Macs. No files are deleted."
            )
        }
    }
}
