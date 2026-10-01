import Foundation

enum GitError: Error, Equatable {
    case gitUnavailable
    case notARepository(String)
    case commandFailed(String)
    case noRemoteConfigured
    case noUpstreamConfigured
    case authenticationFailed(String)
    case diverged
    case branchProtected(String)
    case nothingToCommit
    case cancelled
}
