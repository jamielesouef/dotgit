import Foundation

enum StartupStepStatus: Equatable {
    case waiting
    case running
    case passed
    case warning
    case failed
    case skipped
}
