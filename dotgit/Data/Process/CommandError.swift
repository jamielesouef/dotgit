import Foundation

enum CommandError: Error, Equatable {
    case executableMissing(String)
    case launchFailed(String)
    case outputUnreadable
    case cancelled
}
