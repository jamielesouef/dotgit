#if DEBUG
    import AppKit
    import Foundation

    @MainActor
    enum AppRelauncher {
        static func relaunch() {
            Task {
                let configuration = NSWorkspace.OpenConfiguration()
                configuration.createsNewApplicationInstance = true

                _ = try? await NSWorkspace.shared.openApplication(
                    at: Bundle.main.bundleURL,
                    configuration: configuration
                )

                NSApplication.shared.terminate(nil)
            }
        }
    }
#endif
