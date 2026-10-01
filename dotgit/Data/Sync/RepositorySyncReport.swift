import Foundation

struct RepositorySyncReport: Equatable {
    let identifier: String
    let branch: String
    let result: RepositorySyncOutcome.Result
    let fallback: AccountFallbackResult?
    let committed: Bool

    func outcome(finishedAt: Date) -> RepositorySyncOutcome {
        RepositorySyncOutcome(identifier: identifier, result: result, finishedAt: finishedAt)
    }
}
