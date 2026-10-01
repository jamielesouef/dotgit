import Foundation

struct DiscoveredRepository: Equatable, Identifiable, Hashable {
    let url: URL
    let name: String

    var id: String {
        url.path(percentEncoded: false)
    }

    init(url: URL) {
        self.url = url
        name = url.lastPathComponent
    }
}
