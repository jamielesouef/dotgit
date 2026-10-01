import Foundation

struct RepositorySyncOutcome: Equatable, Identifiable {
    enum Result: Equatable {
        case succeeded(commit: String?, branch: String?)
        case skipped(String)
        case failed(SyncFailure)
    }

    let identifier: String
    let result: Result
    let finishedAt: Date

    var id: String {
        identifier
    }

    var didFail: Bool {
        switch result {
        case .failed:
            true
        case .succeeded,
             .skipped:
            false
        }
    }

    var didSucceed: Bool {
        switch result {
        case .succeeded:
            true
        case .failed,
             .skipped:
            false
        }
    }
}
