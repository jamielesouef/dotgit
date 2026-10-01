import Foundation

struct RepositoryLoadProgress: Equatable {
    let total: Int
    let completed: Int
    let reading: [String]

    static let opening = RepositoryLoadProgress(total: 0, completed: 0, reading: [])

    var fractionCompleted: Double? {
        guard total > 0 else {
            return nil
        }

        return Double(completed) / Double(total)
    }

    var title: String {
        guard total > 0 else {
            return String(localized: "Opening the shared workspace")
        }

        return String(localized: "Read \(completed) of \(total) repositories")
    }

    var detail: String? {
        guard reading.isEmpty == false else {
            return nil
        }

        return String(localized: "Reading \(reading.formatted(.list(type: .and)))")
    }

    // MARK: - Updating

    static func starting(total: Int) -> RepositoryLoadProgress {
        RepositoryLoadProgress(total: total, completed: 0, reading: [])
    }

    func startingToRead(_ name: String) -> RepositoryLoadProgress {
        RepositoryLoadProgress(total: total, completed: completed, reading: reading + [name])
    }

    func finishedReading(_ name: String) -> RepositoryLoadProgress {
        var remaining = reading

        if let index = remaining.firstIndex(of: name) {
            remaining.remove(at: index)
        }

        return RepositoryLoadProgress(total: total, completed: min(completed + 1, total), reading: remaining)
    }
}
