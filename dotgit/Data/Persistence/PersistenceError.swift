import Foundation

enum PersistenceError: Error, Equatable {
    case containerUnavailable(String)
    case fetchFailed(String)
    case saveFailed(String)
    case recordMissing(String)
}
