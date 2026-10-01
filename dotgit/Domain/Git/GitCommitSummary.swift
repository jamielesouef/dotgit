import Foundation

struct GitCommitSummary: Equatable, Identifiable {
    let hash: String
    let subject: String
    let authorName: String
    let date: Date

    var id: String {
        hash
    }

    var shortHash: String {
        String(hash.prefix(7))
    }
}
