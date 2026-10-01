#if DEBUG
    import SwiftUI

    struct DebugMenuView: View {
        // MARK: - Environment

        @Environment(\.settingsService) private var settings

        // MARK: - State

        @State private var isConfirmingReset = false

        // MARK: - View

        var body: some View {
            Menu {
                Button(String(localized: "Reset app to fresh install"), role: .destructive) {
                    isConfirmingReset = true
                }
            } label: {
                Label(String(localized: "Debug"), systemImage: "ladybug")
                    .font(.caption)
            }
            .menuStyle(.borderlessButton)
            .padding(.horizontal, AppSpacing.regular)
            .padding(.vertical, AppSpacing.small)
            .confirmationDialog(
                String(localized: "Reset dotgit to a fresh install?"),
                isPresented: $isConfirmingReset,
                titleVisibility: .visible
            ) {
                Button(String(localized: "Reset and relaunch"), role: .destructive) {
                    settings.resetToFreshInstall()
                    AppRelauncher.relaunch()
                }

                Button(String(localized: "Cancel"), role: .cancel) {}
            } message: {
                Text(
                    String(
                        localized: """
                        This clears every tracked repository, all preferences and this Mac's settings, \
                        then relaunches dotgit. It never deletes your repository files.
                        """
                    )
                )
            }
        }
    }

    #Preview("Debug menu") {
        DebugMenuView()
            .environment(\.settingsService, PreviewGraph.populated.settings)
            .frame(width: 220)
    }
#endif
