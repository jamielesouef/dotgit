import Foundation

struct ReadinessCheckInput: Equatable {
    let repository: WorkspaceRepository
    let directory: URL
    let snapshot: GitRepositorySnapshot
    let checksRemoteTags: Bool
}
