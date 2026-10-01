import Foundation

enum CleanupCategory: String, Equatable, CaseIterable, Codable, Identifiable {
    case simulatorRuntimes
    case derivedData

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .simulatorRuntimes:
            String(localized: "Simulator runtimes")
        case .derivedData:
            String(localized: "Derived Data")
        }
    }
}
