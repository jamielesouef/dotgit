import Foundation

enum GitChangeStatus: String, Equatable, CaseIterable, Codable {
    case added
    case modified
    case deleted
    case renamed
    case copied
    case typeChanged
    case conflicted
    case untracked
}
