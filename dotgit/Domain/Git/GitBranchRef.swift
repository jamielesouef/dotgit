import Foundation

struct GitBranchRef: Equatable, Identifiable {
    let name: String
    let upstream: String?
    let aheadCount: Int
    let behindCount: Int

    var id: String {
        name
    }

    var isLocalOnly: Bool {
        upstream == nil
    }

    var hasUnpushedCommits: Bool {
        aheadCount > 0
    }
}
