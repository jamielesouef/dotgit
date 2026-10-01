import Foundation

enum RepositorySortOrder: String, Equatable, CaseIterable, Codable, Identifiable {
    case name
    case lastSynced
    case status
    case path

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .name:
            String(localized: "Name")
        case .lastSynced:
            String(localized: "Last synced")
        case .status:
            String(localized: "Status")
        case .path:
            String(localized: "Path")
        }
    }
}
