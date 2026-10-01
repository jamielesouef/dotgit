import Foundation

protocol RepositorySyncPerforming: Sendable {
    func sync(_ request: RepositorySyncRequest) async -> RepositorySyncReport
}
