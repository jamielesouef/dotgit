import Foundation

enum CleanupError: Error, Equatable {
    case protectedLocation(String)
    case toolUnavailable
    case removalFailed(String)

    var message: String {
        switch self {
        case let .protectedLocation(path):
            String(localized: "dotgit will not remove \(path) because it belongs to an Xcode installation.")
        case .toolUnavailable:
            String(localized: "The Xcode command line tools are not available.")
        case let .removalFailed(detail):
            detail
        }
    }
}
