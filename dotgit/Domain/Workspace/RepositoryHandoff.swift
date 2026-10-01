import Foundation

struct RepositoryHandoff: Equatable, Codable {
    let branch: String
    let commit: String
    let recordedAt: Date

    var shortCommit: String {
        String(commit.prefix(7))
    }
}
