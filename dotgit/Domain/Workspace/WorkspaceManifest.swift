import Foundation

struct WorkspaceManifest: Equatable, Codable {
    static let currentVersion = 1

    var version: Int
    var name: String
    var repositories: [WorkspaceManifestEntry]

    static let empty = WorkspaceManifest(version: currentVersion, name: "Workspace", repositories: [])

    var isSupportedVersion: Bool {
        version >= 1 && version <= Self.currentVersion
    }

    static func make(name: String, repositories: [WorkspaceRepository]) -> WorkspaceManifest {
        WorkspaceManifest(
            version: currentVersion,
            name: name,
            repositories: repositories.map(WorkspaceManifestEntry.init)
        )
    }
}
