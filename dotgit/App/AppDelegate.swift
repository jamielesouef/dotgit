import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    // MARK: - NSApplicationDelegate

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        let settings = AppDependencies.shared.settings

        return settings.localSettings.keepsRunningInMenuBarOnClose == false
            || settings.localSettings.showsMenuBarItem == false
    }
}
