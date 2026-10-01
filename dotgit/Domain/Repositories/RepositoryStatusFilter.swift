import Foundation

enum RepositoryStatusFilter: String, Equatable, CaseIterable, Codable, Identifiable {
    case all
    case dirty
    case clean
    case ahead
    case behind
    case failed

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .all:
            String(localized: "All")
        case .dirty:
            String(localized: "Dirty")
        case .clean:
            String(localized: "Clean")
        case .ahead:
            String(localized: "Ahead")
        case .behind:
            String(localized: "Behind")
        case .failed:
            String(localized: "Failed")
        }
    }
}
