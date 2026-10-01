import Foundation

struct SyncProgress: Equatable {
    let total: Int
    let completed: Int
    let currentRepositoryName: String?

    var fraction: Double {
        guard total > 0 else {
            return 0
        }

        return Double(completed) / Double(total)
    }

    var isFinished: Bool {
        completed >= total
    }
}
