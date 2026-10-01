import Foundation

struct CleanupOutcome: Equatable, Identifiable {
    let item: CleanupItem
    let failureMessage: String?

    var id: String {
        item.id
    }

    var succeeded: Bool {
        failureMessage == nil
    }
}
