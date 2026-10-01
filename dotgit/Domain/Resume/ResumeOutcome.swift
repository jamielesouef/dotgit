import Foundation

struct ResumeOutcome: Equatable, Identifiable {
    let identifier: String
    let name: String
    let openableURL: URL?
    let failureMessage: String?

    var id: String {
        identifier
    }

    var succeeded: Bool {
        failureMessage == nil
    }
}
