import Foundation

enum WorkspaceManifestError: Error, Equatable {
    case fileUnreadable(String)
    case malformed(String)
    case unsupportedVersion(Int)
    case writeFailed(String)

    var message: String {
        switch self {
        case let .fileUnreadable(path):
            String(localized: "The manifest at \(path) could not be read.")
        case let .malformed(detail):
            String(localized: "The manifest is not in a format dotgit understands: \(detail)")
        case let .unsupportedVersion(version):
            String(localized: "This manifest is version \(version), which this build of dotgit does not support.")
        case let .writeFailed(detail):
            String(localized: "The manifest could not be written: \(detail)")
        }
    }
}
