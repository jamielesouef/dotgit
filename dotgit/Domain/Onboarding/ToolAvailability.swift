import Foundation

struct ToolAvailability: Equatable {
    let isGitAvailable: Bool
    let isGitHubCLIAvailable: Bool
    let gitHubAccounts: [GitHubAccount]

    static let unknown = ToolAvailability(isGitAvailable: false, isGitHubCLIAvailable: false, gitHubAccounts: [])

    var isGitHubCLIAuthenticated: Bool {
        isGitHubCLIAvailable && gitHubAccounts.isEmpty == false
    }
}
