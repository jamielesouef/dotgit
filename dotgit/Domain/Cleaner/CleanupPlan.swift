import Foundation

struct CleanupPlan: Equatable {
    let items: [CleanupItem]

    static let empty = CleanupPlan(items: [])

    var totalBytes: Int64 {
        items.reduce(0) { $0 + $1.sizeBytes }
    }

    var formattedTotal: String {
        ByteCountFormatStyle(style: .file).format(totalBytes)
    }

    var isEmpty: Bool {
        items.isEmpty
    }
}
