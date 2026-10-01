import Foundation

struct CleanupItem: Equatable, Identifiable, Hashable {
    enum Target: Equatable, Hashable {
        case simulatorRuntime(String)
        case derivedData(URL)
    }

    let title: String
    let detail: String
    let sizeBytes: Int64
    let category: CleanupCategory
    let target: Target
    let isDeletable: Bool

    var id: String {
        switch target {
        case let .simulatorRuntime(identifier):
            "runtime:\(identifier)"
        case let .derivedData(url):
            "derived:\(url.path(percentEncoded: false))"
        }
    }

    var formattedSize: String {
        ByteCountFormatStyle(style: .file).format(sizeBytes)
    }
}
