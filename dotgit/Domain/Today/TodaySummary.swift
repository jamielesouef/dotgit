import Foundation

struct TodaySummary: Equatable {
    let unfinishedWork: [TrackedRepository]
    let syncProblems: [TrackedRepository]
    let readyToResume: [TrackedRepository]
    let notClonedHere: [TrackedRepository]
    let lastSuccessfulSync: Date?

    static let empty = TodaySummary(
        unfinishedWork: [],
        syncProblems: [],
        readyToResume: [],
        notClonedHere: [],
        lastSuccessfulSync: nil
    )

    var localOnlyCount: Int {
        unfinishedWork.count
    }

    var needsAttention: Bool {
        unfinishedWork.isEmpty == false || syncProblems.isEmpty == false
    }
}
