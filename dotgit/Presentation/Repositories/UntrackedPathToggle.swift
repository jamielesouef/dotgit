import SwiftUI

struct UntrackedPathToggle: View {
    // MARK: - State

    @State private var isOn = false

    // MARK: - Inputs

    let path: String
    let isSelected: Bool
    let onSelectionChange: (Bool) -> Void

    // MARK: - View

    var body: some View {
        Toggle(isOn: $isOn) {
            Text(path)
                .font(.caption)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .toggleStyle(.checkbox)
        .onChange(of: isSelected, initial: true) {
            isOn = isSelected
        }
        .onChange(of: isOn) {
            onSelectionChange(isOn)
        }
    }
}

#if DEBUG
    #Preview("Selected and not") {
        @Previewable @State var isSelected = true

        VStack(alignment: .leading, spacing: AppSpacing.xsmall) {
            UntrackedPathToggle(path: "Notes.md", isSelected: isSelected) { isSelected = $0 }
            UntrackedPathToggle(path: "Scratch.swift", isSelected: false) { _ in }
        }
        .padding()
    }

    #Preview("Long path") {
        UntrackedPathToggle(
            path: "Sources/Features/Onboarding/Screens/Account/AnExtremelyLongFileNameThatTruncatesInTheMiddle.swift",
            isSelected: false
        ) { _ in }
            .padding()
            .frame(width: 320)
    }
#endif
