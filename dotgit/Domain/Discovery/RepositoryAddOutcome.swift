import Foundation

enum RepositoryAddOutcome: Equatable {
    case added
    case notARepository(URL)
}
