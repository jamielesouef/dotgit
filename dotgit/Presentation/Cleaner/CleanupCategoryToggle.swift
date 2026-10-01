import SwiftUI

struct CleanupCategoryToggle: View {
    // MARK: - State

    @State private var isOn = false

    // MARK: - Inputs

    let category: CleanupCategory
    let isEnabled: Bool
    let onEnabledChange: (Bool) -> Void

    // MARK: - View

    var body: some View {
        Toggle(category.title, isOn: $isOn)
            .toggleStyle(.checkbox)
            .onChange(of: isEnabled, initial: true) {
                isOn = isEnabled
            }
            .onChange(of: isOn) {
                onEnabledChange(isOn)
            }
    }
}

#if DEBUG
    #Preview("Both categories") {
        @Previewable @State var enabled: Set<CleanupCategory> = [.simulatorRuntimes]

        HStack(spacing: AppSpacing.regular) {
            ForEach(CleanupCategory.allCases) { category in
                CleanupCategoryToggle(category: category, isEnabled: enabled.contains(category)) { isEnabled in
                    if isEnabled {
                        enabled.insert(category)
                    } else {
                        enabled.remove(category)
                    }
                }
            }
        }
        .padding(AppSpacing.regular)
    }

    #Preview("Everything off") {
        CleanupCategoryToggle(category: .derivedData, isEnabled: false) { _ in }
            .padding(AppSpacing.regular)
    }
#endif
