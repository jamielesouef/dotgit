import Foundation

struct ReadinessReport: Equatable, Identifiable {
    let identifier: String
    let currentBranchPushed: Bool
    let issues: [ReadinessIssue]

    var id: String {
        identifier
    }

    var isReadyToResume: Bool {
        issues.isEmpty
    }

    var issueCount: Int {
        issues.count
    }
}
