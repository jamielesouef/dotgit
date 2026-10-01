import Foundation

struct DerivedDataEntry: Equatable, Identifiable, Hashable {
    enum Source: String, Equatable, Hashable {
        case defaultLocation
        case projectSpecific
        case custom

        var title: String {
            switch self {
            case .defaultLocation:
                String(localized: "Default location")
            case .projectSpecific:
                String(localized: "Project specific")
            case .custom:
                String(localized: "Custom location")
            }
        }
    }

    let url: URL
    let name: String
    let sizeBytes: Int64
    let source: Source

    var id: String {
        url.path(percentEncoded: false)
    }
}
