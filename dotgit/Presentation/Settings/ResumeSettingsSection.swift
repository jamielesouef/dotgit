import SwiftUI
import UniformTypeIdentifiers

struct ResumeSettingsSection: View {
    // MARK: - Environment

    @Environment(\.settingsService) private var settings
    @Environment(\.filePanel) private var filePanel

    // MARK: - State

    @State private var preselectsFastForward = AppPreferences.default.preselectsSafeFastForward
    @State private var offersToOpen = AppPreferences.default.offersToOpenProjectAfterResume

    // MARK: - View

    var body: some View {
        Section(String(localized: "Resume")) {
            Toggle(String(localized: "Preselect safe fast-forward updates"), isOn: $preselectsFastForward)

            Toggle(String(localized: "Offer to open a project once it is ready"), isOn: $offersToOpen)

            LabeledContent(String(localized: "Open projects with")) {
                HStack {
                    Text(applicationName)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    Button(String(localized: "Choose…"), action: chooseApplication)

                    if settings.localSettings.preferredOpenApplicationPath != nil {
                        Button(String(localized: "Clear")) {
                            settings.updateLocalSettings { $0.preferredOpenApplicationPath = nil }
                        }
                    }
                }
            }
        }
        .onChange(of: settings.preferences.preselectsSafeFastForward, initial: true) {
            preselectsFastForward = settings.preferences.preselectsSafeFastForward
        }
        .onChange(of: preselectsFastForward) {
            settings.updatePreferences { $0.preselectsSafeFastForward = preselectsFastForward }
        }
        .onChange(of: settings.preferences.offersToOpenProjectAfterResume, initial: true) {
            offersToOpen = settings.preferences.offersToOpenProjectAfterResume
        }
        .onChange(of: offersToOpen) {
            settings.updatePreferences { $0.offersToOpenProjectAfterResume = offersToOpen }
        }
    }

    private func chooseApplication() {
        guard let url = filePanel.chooseFile(
            message: String(localized: "Choose the application to open projects with"),
            contentTypes: [.application]
        ) else {
            return
        }

        settings.updateLocalSettings { $0.preferredOpenApplicationPath = url.path(percentEncoded: false) }
    }

    // MARK: - Helpers

    private var applicationName: String {
        guard let path = settings.localSettings.preferredOpenApplicationPath else {
            return String(localized: "The system default")
        }

        return URL(filePath: path).lastPathComponent
    }
}

#if DEBUG
    #Preview("Resume settings") {
        Form {
            ResumeSettingsSection()
        }
        .formStyle(.grouped)
        .environment(\.settingsService, PreviewGraph.populated.settings)
        .frame(width: 560, height: 240)
    }
#endif
