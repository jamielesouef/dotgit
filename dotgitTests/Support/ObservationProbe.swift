import Observation
import Synchronization

final class ObservationProbe: Sendable {
    // MARK: - State

    private let changed = Mutex(false)

    var didChange: Bool {
        changed.withLock { $0 }
    }

    // MARK: - Watching

    func watch(_ read: () -> Void) {
        withObservationTracking(read) { [self] in
            changed.withLock { $0 = true }
        }
    }
}
