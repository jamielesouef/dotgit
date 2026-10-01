import Foundation

struct AccountFallbackAttempt: Equatable, Identifiable {
    let account: String
    let failureMessage: String?

    var id: String {
        account
    }

    var succeeded: Bool {
        failureMessage == nil
    }
}
