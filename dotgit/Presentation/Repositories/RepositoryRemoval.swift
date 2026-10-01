import Foundation

struct RepositoryRemoval: Identifiable {
    let identifiers: Set<String>
    let scope: ConfigurationScope

    var id: String {
        "\(scope.rawValue):\(identifiers.sorted().joined(separator: ","))"
    }

    var title: String {
        switch scope {
        case .local:
            String(localized: "Remove this Mac's path for \(identifiers.count) repository(s)?")
        case .shared:
            String(localized: "Remove \(identifiers.count) repository(s) from the shared workspace?")
        }
    }

    var explanation: String {
        switch scope {
        case .local:
            String(
                localized: "dotgit will forget where they live on this Mac. The shared workspace entries stay, and no files are deleted."
            )
        case .shared:
            String(localized: "dotgit will remove them from the workspace on every Mac. No files are deleted.")
        }
    }
}
