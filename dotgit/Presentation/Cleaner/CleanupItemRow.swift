import SwiftUI

struct CleanupItemRow: View {
    // MARK: - State

    @State private var isChecked = false

    // MARK: - Inputs

    let item: CleanupItem
    let isSelected: Bool
    let onSelectionChange: (Bool) -> Void

    // MARK: - View

    var body: some View {
        HStack(alignment: .top, spacing: AppSpacing.medium) {
            Toggle(isOn: $isChecked) {
                EmptyView()
            }
            .toggleStyle(.checkbox)
            .labelsHidden()
            .disabled(item.isDeletable == false)

            VStack(alignment: .leading, spacing: AppSpacing.xsmall) {
                Text(item.title)
                    .font(.body.weight(.medium))
                    .lineLimit(1)

                Text(item.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)

                if item.isDeletable == false {
                    Text(String(localized: "dotgit will not remove this."))
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
            }

            Spacer(minLength: AppSpacing.small)

            Text(item.formattedSize)
                .font(.callout.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, AppSpacing.xsmall)
        .onChange(of: isSelected, initial: true) {
            isChecked = isSelected
        }
        .onChange(of: isChecked) {
            onSelectionChange(isChecked)
        }
    }
}

#if DEBUG
    #Preview("Removable and protected") {
        @Previewable @State var isRemovableSelected = true

        List {
            CleanupItemRow(
                item: CleanupItem(
                    title: "iOS 18.0 (22A3351)",
                    detail: "/Library/Developer/CoreSimulator/Images/R1.dmg",
                    sizeBytes: 7_100_000_000,
                    category: .simulatorRuntimes,
                    target: .simulatorRuntime("R1"),
                    isDeletable: true
                ),
                isSelected: isRemovableSelected,
                onSelectionChange: { isRemovableSelected = $0 }
            )
            CleanupItemRow(
                item: CleanupItem(
                    title: "iOS 17.5 bundled with Xcode",
                    detail: "/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Library/" +
                        "Developer/CoreSimulator/Profiles/Runtimes",
                    sizeBytes: 5_000_000_000,
                    category: .simulatorRuntimes,
                    target: .simulatorRuntime("R2"),
                    isDeletable: false
                ),
                isSelected: false,
                onSelectionChange: { _ in }
            )
        }
        .frame(width: 620, height: 200)
    }

    #Preview("Long title, zero size") {
        @Previewable @State var isSelected = false

        List {
            CleanupItemRow(
                item: CleanupItem(
                    title: "a-very-long-project-name-that-keeps-going-fhqzgkdlwbxmtnrpyavcsoeiuj",
                    detail: "/Users/jamie/Library/Developer/Xcode/DerivedData/" +
                        "a-very-long-project-name-that-keeps-going-fhqzgkdlwbxmtnrpyavcsoeiuj",
                    sizeBytes: 0,
                    category: .derivedData,
                    target: .derivedData(URL(filePath: "/tmp/derived")),
                    isDeletable: true
                ),
                isSelected: isSelected,
                onSelectionChange: { isSelected = $0 }
            )
        }
        .frame(width: 420, height: 120)
    }
#endif
