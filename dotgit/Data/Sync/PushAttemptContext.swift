import Foundation

struct PushAttemptContext: Equatable {
    let directory: URL
    let branch: String
    let remote: String
    let remoteURL: String?
    let setsUpstream: Bool
    let preferredAccount: String?
}
