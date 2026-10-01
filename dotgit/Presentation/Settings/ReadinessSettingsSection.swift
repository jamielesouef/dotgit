import SwiftUI

struct ReadinessSettingsSection: View {
    // MARK: - Environment

    @Environment(\.repositoriesService) private var repositories

    // MARK: - State

    @State private var selection: String?

    // MARK: - View

    var body: some View {
        Section(String(localized: "Readiness checks")) {
            Text(
                String(
                    localized: "These travel in the manifest so another Mac knows what a project needs. Values are never copied, only names."
                )
            )
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)

            Picker(String(localized: "Repository"), selection: $selection) {
                Text(String(localized: "Choose a repository")).tag(String?.none)

                ForEach(repositories.repositories) { repository in
                    Text(repository.name).tag(String?.some(repository.id))
                }
            }

            if let selection, let repository = repositories.repository(identifier: selection) {
                editor(for: repository)
            }
        }
    }

    // MARK: - Editor

    @ViewBuilder
    private func editor(for repository: TrackedRepository) -> some View {
        LabeledContent(String(localized: "Setup instructions")) {
            MirroredTextField(
                placeholder: "README.md",
                value: repository.shared.setupInstructionsPath,
                format: ReadinessFieldUseCase.text(for:),
                parse: ReadinessFieldUseCase.optionalValue(from:)
            ) { path in
                update(repository) { $0.setupInstructionsPath = path }
            }
            .textFieldStyle(.roundedBorder)
        }

        LabeledContent(String(localized: "Required environment variables")) {
            MirroredTextField(
                placeholder: "API_HOST, API_TOKEN",
                value: repository.shared.requiredEnvironmentVariableNames,
                format: ReadinessFieldUseCase.text(for:),
                parse: ReadinessFieldUseCase.names(from:)
            ) { names in
                update(repository) { $0.requiredEnvironmentVariableNames = names }
            }
            .textFieldStyle(.roundedBorder)
        }

        LabeledContent(String(localized: "Expected configuration templates")) {
            MirroredTextField(
                placeholder: ".env.example",
                value: repository.shared.expectedConfigurationTemplates,
                format: ReadinessFieldUseCase.text(for:),
                parse: ReadinessFieldUseCase.names(from:)
            ) { names in
                update(repository) { $0.expectedConfigurationTemplates = names }
            }
            .textFieldStyle(.roundedBorder)
        }
    }

    // MARK: - Helpers

    private func update(_ repository: TrackedRepository, _ mutate: (inout WorkspaceRepository) -> Void) {
        var shared = repository.shared
        mutate(&shared)
        repositories.update(shared)
    }
}

#if DEBUG
    #Preview("Readiness settings") {
        Form {
            ReadinessSettingsSection()
        }
        .formStyle(.grouped)
        .environment(\.repositoriesService, PreviewGraph.populated.repositories)
        .frame(width: 620, height: 320)
    }
#endif
