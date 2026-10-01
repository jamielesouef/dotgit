import Foundation

enum AccountFallbackResult: Equatable {
    case notApplicable(String)
    case succeeded(account: String, attempts: [AccountFallbackAttempt])
    case exhausted([AccountFallbackAttempt])

    var attempts: [AccountFallbackAttempt] {
        switch self {
        case .notApplicable:
            []
        case let .succeeded(_, attempts),
             let .exhausted(attempts):
            attempts
        }
    }
}
