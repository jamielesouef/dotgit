import Foundation

protocol PushFallbackPerforming: Sendable {
    func retryPush(_ context: PushAttemptContext) async -> AccountFallbackResult
}
