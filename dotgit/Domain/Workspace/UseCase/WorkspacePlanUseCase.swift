import Foundation

enum WorkspacePlanUseCase {
    static func plan(
        manifest: WorkspaceManifest,
        workspaceRoot: URL?,
        localPaths: [String: String]
    ) -> WorkspacePlan {
        WorkspacePlan(
            manifestName: manifest.name,
            entries: manifest.repositories.map { entry in
                WorkspacePlanEntry(
                    identifier: entry.identifier,
                    name: entry.name,
                    action: action(for: entry, workspaceRoot: workspaceRoot, localPaths: localPaths)
                )
            }
        )
    }

    static func destination(for entry: WorkspaceManifestEntry, workspaceRoot: URL) -> URL {
        let relativePath = entry.preferredRelativePath.isEmpty ? entry.name : entry.preferredRelativePath

        return workspaceRoot.appending(path: relativePath).standardizedFileURL
    }

    // MARK: - Helpers

    private static func action(
        for entry: WorkspaceManifestEntry,
        workspaceRoot: URL?,
        localPaths: [String: String]
    ) -> WorkspacePlanEntry.Action {
        if let existing = localPaths[entry.identifier] {
            return .update(URL(filePath: existing))
        }

        guard let remoteURL = entry.remoteURL, remoteURL.isEmpty == false else {
            return .noRemote
        }
        guard let workspaceRoot else {
            return .noWorkspaceRoot
        }

        return .clone(destination(for: entry, workspaceRoot: workspaceRoot))
    }
}
