import SwiftUI

struct BranchSyncToggle: View {
    // MARK: - State

    @State private var isOn = false

    // MARK: - Inputs

    let branch: String
    let isAllowed: Bool
    let onAllowedChange: (Bool) -> Void

    // MARK: - View

    var body: some View {
        Toggle(String(localized: "Allow syncing \(branch)"), isOn: $isOn)
            .onChange(of: isAllowed, initial: true) {
                isOn = isAllowed
            }
            .onChange(of: isOn) {
                onAllowedChange(isOn)
            }
    }
}

#if DEBUG
    #Preview("Allowed and not") {
        @Previewable @State var allowsMain = false

        Form {
            BranchSyncToggle(branch: "main", isAllowed: allowsMain) { allowsMain = $0 }
            BranchSyncToggle(branch: "master", isAllowed: true) { _ in }
        }
        .formStyle(.grouped)
    }

    #Preview("Long branch name") {
        Form {
            BranchSyncToggle(
                branch: "release/2026-09-a-very-long-branch-name-that-somebody-protected",
                isAllowed: false
            ) { _ in }
        }
        .formStyle(.grouped)
    }
#endif
