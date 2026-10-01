import Foundation

struct GitWorktree: Equatable {
    let path: URL
    let headCommit: String?
    let branch: String?
    let isMain: Bool
    let isBare: Bool
    let isLocked: Bool
    let isPrunable: Bool

    var name: String {
        path.lastPathComponent
    }

    var isDetached: Bool {
        branch == nil
    }
}
