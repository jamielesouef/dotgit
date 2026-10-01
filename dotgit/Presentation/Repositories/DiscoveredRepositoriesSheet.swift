import SwiftUI

struct DiscoveredRepositoriesSheet: View {
    // MARK: - Constants

    private enum Constants {
        static let width: CGFloat = 520
        static let height: CGFloat = 420
    }

    // MARK: - State

    @State private var selected: Set<String> = []

    // MARK: - Inputs

    let discovered: [DiscoveredRepository]
    let add: ([DiscoveredRepository]) -> Void
    let cancel: () -> Void

    // MARK: - View

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.regular) {
            Text(String(localized: "Repositories found"))
                .font(.title2.weight(.semibold))

            Text(String(localized: "\(discovered.count) repository(s) found. Pick the ones to track."))
                .font(.callout)
                .foregroundStyle(.secondary)

            List(discovered, selection: $selected) { repository in
                VStack(alignment: .leading, spacing: AppSpacing.xsmall) {
                    Text(repository.name)
                        .font(.body)

                    Text(repository.url.path(percentEncoded: false))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                .tag(repository.id)
            }

            HStack {
                Button(String(localized: "Select all")) {
                    selected = Set(discovered.map(\.id))
                }

                Spacer()

                Button(String(localized: "Cancel"), action: cancel)
                    .keyboardShortcut(.cancelAction)

                Button(String(localized: "Add")) {
                    add(discovered.filter { selected.contains($0.id) })
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(selected.isEmpty)
            }
        }
        .padding(AppSpacing.large)
        .frame(width: Constants.width, height: Constants.height)
    }
}

#if DEBUG
    #Preview("Several found") {
        DiscoveredRepositoriesSheet(
            discovered: [
                DiscoveredRepository(url: URL(filePath: "/Users/preview/Developer/app")),
                DiscoveredRepository(
                    url: URL(filePath: "/Users/preview/Developer/clients/acme/a-long-nested-repository-name")
                )
            ],
            add: { _ in },
            cancel: {}
        )
    }

    #Preview("None found") {
        DiscoveredRepositoriesSheet(discovered: [], add: { _ in }, cancel: {})
    }
#endif
