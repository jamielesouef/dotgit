import Foundation

protocol WorkspaceManifestStoring: Sendable {
    func load(from url: URL) async throws(WorkspaceManifestError) -> WorkspaceManifest
    func save(_ manifest: WorkspaceManifest, to url: URL) async throws(WorkspaceManifestError)
}
