import SwiftUI

struct DiscoverySettingsSection: View {
    // MARK: - Environment

    @Environment(\.settingsService) private var settings

    // MARK: - State

    @State private var newFolderName = ""

    // MARK: - View

    var body: some View {
        Section(String(localized: "Discovery")) {
            Text(String(localized: "Folders with these names are skipped when scanning."))
                .font(.caption)
                .foregroundStyle(.secondary)

            ForEach(settings.preferences.ignoredFolderNames, id: \.self) { name in
                HStack {
                    Text(name)

                    Spacer()

                    Button(String(localized: "Remove"), systemImage: "minus.circle") {
                        settings.updatePreferences { preferences in
                            preferences.ignoredFolderNames.removeAll { $0 == name }
                        }
                    }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.borderless)
                }
            }

            HStack {
                TextField(String(localized: "Folder name"), text: $newFolderName)
                    .textFieldStyle(.roundedBorder)

                Button(String(localized: "Add"), action: addFolderName)
                    .disabled(trimmedName.isEmpty)
            }
        }
    }

    // MARK: - Helpers

    private var trimmedName: String {
        newFolderName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func addFolderName() {
        let name = trimmedName

        guard name.isEmpty == false else {
            return
        }

        settings.updatePreferences { preferences in
            guard preferences.ignoredFolderNames.contains(name) == false else {
                return
            }

            preferences.ignoredFolderNames.append(name)
        }

        newFolderName = ""
    }
}

#if DEBUG
    #Preview("Discovery settings") {
        Form {
            DiscoverySettingsSection()
        }
        .formStyle(.grouped)
        .environment(\.settingsService, PreviewGraph.populated.settings)
        .frame(width: 560, height: 420)
    }
#endif
