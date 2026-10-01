import AppKit
import Foundation

struct WorkspaceProjectOpener: ProjectOpening {
    @MainActor
    func open(_ url: URL, withApplicationAt applicationURL: URL?) async -> Bool {
        guard let applicationURL else {
            return NSWorkspace.shared.open(url)
        }

        let configuration = NSWorkspace.OpenConfiguration()

        do {
            _ = try await NSWorkspace.shared.open(
                [url],
                withApplicationAt: applicationURL,
                configuration: configuration
            )
        } catch {
            AppLog.error("Could not open \(url.lastPathComponent): \(error.localizedDescription)")
            return false
        }

        return true
    }
}
