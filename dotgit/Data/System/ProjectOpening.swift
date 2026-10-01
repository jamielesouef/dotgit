import Foundation

protocol ProjectOpening: Sendable {
    func open(_ url: URL, withApplicationAt applicationURL: URL?) async -> Bool
}
