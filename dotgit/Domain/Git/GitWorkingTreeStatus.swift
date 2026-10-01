import Foundation

struct GitWorkingTreeStatus: Equatable {
    let trackedChanges: [GitFileChange]
    let untrackedPaths: [String]

    static let clean = GitWorkingTreeStatus(trackedChanges: [], untrackedPaths: [])

    var isClean: Bool {
        trackedChanges.isEmpty && untrackedPaths.isEmpty
    }

    var hasTrackedChanges: Bool {
        trackedChanges.isEmpty == false
    }
}
