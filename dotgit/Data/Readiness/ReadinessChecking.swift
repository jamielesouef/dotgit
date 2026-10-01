import Foundation

protocol ReadinessChecking: Sendable {
    func evaluate(_ input: ReadinessCheckInput) async -> ReadinessReport
}
