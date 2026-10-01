import Foundation

struct RepositorySyncRequest: Equatable {
    let identifier: String
    let directory: URL
    let branch: String
    let protectedBranchFallback: String
    let remote: String
    let remoteURL: String?
    let setsUpstream: Bool
    let willCommit: Bool
    let untrackedPathsToInclude: [String]
    let commitMessage: String
    let preferredAccount: String?
    let checksAccountAccess: Bool
    let fallbackEnabled: Bool
    var additionalBranches: [GitBranchRef] = []
}
