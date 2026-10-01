import Foundation

struct FileWorkspaceManifestStore: WorkspaceManifestStoring {
    // MARK: - Coding

    static func makeDecoder() -> JSONDecoder {
        JSONDecoder()
    }

    static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        return encoder
    }

    // MARK: - WorkspaceManifestStoring

    @concurrent
    func load(from url: URL) async throws(WorkspaceManifestError) -> WorkspaceManifest {
        guard let data = try? Data(contentsOf: url) else {
            throw .fileUnreadable(url.path(percentEncoded: false))
        }

        let manifest: WorkspaceManifest

        do {
            manifest = try Self.makeDecoder().decode(WorkspaceManifest.self, from: data)
        } catch {
            throw WorkspaceManifestError.malformed(error.localizedDescription)
        }

        guard manifest.isSupportedVersion else {
            throw .unsupportedVersion(manifest.version)
        }

        return manifest
    }

    @concurrent
    func save(_ manifest: WorkspaceManifest, to url: URL) async throws(WorkspaceManifestError) {
        do {
            let data = try Self.makeEncoder().encode(manifest)
            try data.write(to: url, options: .atomic)
        } catch {
            throw WorkspaceManifestError.writeFailed(error.localizedDescription)
        }
    }
}
