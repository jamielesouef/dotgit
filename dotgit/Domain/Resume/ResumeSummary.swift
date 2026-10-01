import Foundation

struct ResumeSummary: Equatable {
    let outcomes: [ResumeOutcome]

    static let empty = ResumeSummary(outcomes: [])

    var succeededCount: Int {
        outcomes.count(where: \.succeeded)
    }

    var failedCount: Int {
        outcomes.count - succeededCount
    }

    var openableProjects: [ResumeOutcome] {
        outcomes.filter { $0.succeeded && $0.openableURL != nil }
    }
}
