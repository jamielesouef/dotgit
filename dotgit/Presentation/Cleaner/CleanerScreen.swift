import SwiftUI

struct CleanerScreen: View {
    // MARK: - Environment

    @Environment(\.cleanerService) private var cleaner

    // MARK: - State

    @State private var isConfirmingRemoval = false

    // MARK: - View

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            categoryPicker
            Divider()
            content
            Divider()
            footer
        }
        .task {
            await cleaner.start()
        }
        .confirmationDialog(
            String(localized: "Remove \(cleaner.plan.items.count) item(s)?"),
            isPresented: $isConfirmingRemoval,
            titleVisibility: .visible
        ) {
            Button(String(localized: "Remove and free \(cleaner.plan.formattedTotal)"), role: .destructive) {
                Task {
                    await cleaner.removeSelected()
                }
            }

            Button(String(localized: "Cancel"), role: .cancel) {}
        } message: {
            Text(
                String(
                    localized: "This cannot be undone. dotgit never touches SDKs bundled inside Xcode or an Xcode installation."
                )
            )
        }
    }

    // MARK: - Categories

    private var categoryPicker: some View {
        HStack(spacing: AppSpacing.regular) {
            ForEach(CleanupCategory.allCases) { category in
                CleanupCategoryToggle(
                    category: category,
                    isEnabled: cleaner.categories.contains(category)
                ) { isEnabled in
                    Task {
                        await cleaner.applyCategory(category, isEnabled: isEnabled)
                    }
                }
            }

            Spacer()
        }
        .padding(AppSpacing.regular)
    }

    // MARK: - Load state

    @ViewBuilder
    private var content: some View {
        switch cleaner.loadState {
        case .loading:
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .empty:
            EmptyStateView(
                symbolName: "sparkles",
                title: String(localized: "Nothing to clean"),
                message: String(
                    localized: "No simulator runtimes or Derived Data were found in the places dotgit looks."
                )
            )
        case let .loaded(items):
            List {
                ForEach(items) { item in
                    CleanupItemRow(item: item, isSelected: cleaner.isSelected(item)) { isSelected in
                        cleaner.setSelected(isSelected, for: item)
                    }
                }
            }
        }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            VStack(alignment: .leading, spacing: 0) {
                Text(String(localized: "\(cleaner.plan.items.count) selected"))
                    .font(.callout)

                Text(String(localized: "About \(cleaner.plan.formattedTotal) would be recovered"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if cleaner.lastOutcomes.isEmpty == false {
                Button(String(localized: "Clear results")) {
                    cleaner.clearOutcomes()
                }
            }

            Button(String(localized: "Remove")) {
                isConfirmingRemoval = true
            }
            .buttonStyle(.borderedProminent)
            .disabled(cleaner.plan.isEmpty || cleaner.isRemoving)
        }
        .padding(AppSpacing.regular)
    }
}

#if DEBUG
    #Preview("Populated") {
        CleanerScreen()
            .environment(\.cleanerService, PreviewGraph.populated.cleaner)
            .frame(width: 720, height: 560)
    }

    #Preview("Empty") {
        CleanerScreen()
            .environment(
                \.cleanerService,
                CleanerService(
                    runtimeProvider: MockSimulatorRuntimeProvider(storedRuntimes: []),
                    derivedDataProvider: MockDerivedDataProvider(storedEntries: []),
                    repositories: PreviewGraph.empty.repositories,
                    settings: PreviewGraph.empty.settings
                )
            )
            .frame(width: 720, height: 560)
    }
#endif
