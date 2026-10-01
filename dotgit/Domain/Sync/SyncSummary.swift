import Foundation

struct SyncSummary: Equatable {
    let outcomes: [RepositorySyncOutcome]

    static let empty = SyncSummary(outcomes: [])

    var succeededCount: Int {
        outcomes.count(where: \.didSucceed)
    }

    var failedCount: Int {
        outcomes.count(where: \.didFail)
    }

    var skippedCount: Int {
        outcomes.count - succeededCount - failedCount
    }

    var failures: [RepositorySyncOutcome] {
        outcomes.filter(\.didFail)
    }

    var isEmpty: Bool {
        outcomes.isEmpty
    }
}
