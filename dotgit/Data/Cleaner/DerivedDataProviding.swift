import Foundation

protocol DerivedDataProviding: Sendable {
    func entries(
        includesDefaultLocation: Bool,
        projectRoots: [URL],
        customPaths: [URL]
    ) async -> [DerivedDataEntry]

    func remove(at url: URL) async throws(CleanupError)
}
