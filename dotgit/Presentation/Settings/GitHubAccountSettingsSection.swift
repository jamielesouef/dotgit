import SwiftUI

struct GitHubAccountSettingsSection: View {
    // MARK: - Environment

    @Environment(\.settingsService) private var settings
    @Environment(\.accountsService) private var accounts

    // MARK: - State

    @State private var fallbackEnabled = AppPreferences.default.accountFallbackEnabled
    @State private var accessChecksEnabled = AppPreferences.default.accountAccessChecksEnabled

    // MARK: - View

    var body: some View {
        Section(String(localized: "GitHub accounts")) {
            Toggle(String(localized: "Retry a refused push with the other signed-in accounts"), isOn: $fallbackEnabled)

            Toggle(String(localized: "Check account access before syncing"), isOn: $accessChecksEnabled)

            Text(
                String(
                    localized: """
                    These only apply to repositories that push over HTTPS. An SSH remote uses your SSH \
                    key, which switching accounts does not change.
                    """
                )
            )
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        .onChange(of: settings.preferences.accountFallbackEnabled, initial: true) {
            fallbackEnabled = settings.preferences.accountFallbackEnabled
        }
        .onChange(of: fallbackEnabled) {
            accounts.setFallbackEnabled(fallbackEnabled)
        }
        .onChange(of: settings.preferences.accountAccessChecksEnabled, initial: true) {
            accessChecksEnabled = settings.preferences.accountAccessChecksEnabled
        }
        .onChange(of: accessChecksEnabled) {
            accounts.setAccessChecksEnabled(accessChecksEnabled)
        }
    }
}

#if DEBUG
    #Preview("Account settings") {
        Form {
            GitHubAccountSettingsSection()
        }
        .formStyle(.grouped)
        .environment(\.settingsService, PreviewGraph.populated.settings)
        .environment(\.accountsService, PreviewGraph.populated.accounts)
        .frame(width: 560, height: 220)
    }
#endif
