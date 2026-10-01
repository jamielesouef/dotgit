import Foundation

struct MenuBarStatus: Equatable {
    enum Level: Equatable {
        case allClear
        case localOnlyWork
        case problems

        var symbolName: String {
            switch self {
            case .allClear:
                "checkmark.circle"
            case .localOnlyWork:
                "arrow.up.circle"
            case .problems:
                "exclamationmark.triangle"
            }
        }
    }

    let level: Level
    let localOnlyCount: Int
    let problemCount: Int
    let lastSuccessfulSync: Date?

    static let allClear = MenuBarStatus(level: .allClear, localOnlyCount: 0, problemCount: 0, lastSuccessfulSync: nil)

    var summary: String {
        switch level {
        case .allClear:
            String(localized: "Everything is pushed")
        case .localOnlyWork:
            String(localized: "\(localOnlyCount) repository(s) have work only on this Mac")
        case .problems:
            String(localized: "\(problemCount) repository(s) need attention")
        }
    }
}
