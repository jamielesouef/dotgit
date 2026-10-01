import Foundation

struct GitFileChange: Equatable, Identifiable, Codable {
    let path: String
    let status: GitChangeStatus
    let originalPath: String?

    var id: String {
        "\(status.rawValue):\(path)"
    }

    var isTracked: Bool {
        status != .untracked
    }

    init(path: String, status: GitChangeStatus, originalPath: String? = nil) {
        self.path = path
        self.status = status
        self.originalPath = originalPath
    }
}
